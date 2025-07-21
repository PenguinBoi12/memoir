defmodule Memoir do
  @moduledoc """
  Memoir is a lightweight, Rails-inspired caching library for Elixir with a pluggable backend architecture.

  It provides a simple API for caching expensive computations using a familiar `do` block syntax. Memoir is designed
  to be backend-agnostic, supporting custom storage adapters such as ETS, Redis, or any custom module that implements
  the expected adapter behaviour.

  ## Features

    * Declarative caching via the `cache/3` macro
    * Pluggable backend adapters (ETS by default)
    * Functions to manually `get/1`, `put/3`, `delete/1`, and `clear/0` cache entries
    * Automatically supervised cache process

  ## Usage

  Memoir is typically used to cache expensive function calls:

  ```elixir
  Memoir.cache({:user, 123}, expire_in: :timer.minutes(5)) do
    expensive_user_lookup(123)
  end
  ```

  You can also interact with the cache directly:
  ```elixir
  Memoir.put(:some_key, "value", ttl: 60_000)
  Memoir.get(:some_key)
  Memoir.delete(:some_key)
  Memoir.clear()
  ```

  ## Configuration

  You can configure Memoir in your config.exs:
  ```
  config :memoir,
    adapter: Memoir.Adapters.ETS,
    adapter_opts: [ttl: 300_000]
  ```
  """
  use Supervisor

  def start_link(opts \\ []),
    do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_opts) do
    adapter = get_adapter()
    adapter_opts = Application.get_env(:memoir, :adapter_opts, [])

    children = [
      {adapter, [adapter_opts]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Main caching function that accepts a block.

  ## Examples

  ```elixir
  cache({:user, 123}, expire_in: :timer.minutes(5)) do
    expensive_user_lookup(123)
  end
  ```
  """
  defmacro cache(key, opts \\ [], do: block) do
    quote do
      Memoir.fetch(unquote(key), unquote(opts), fn -> unquote(block) end)
    end
  end

  @doc """
  Fetch from cache or execute the given function.
  """
  def fetch(key, opts \\ [], fun) do
    cache_key = build_cache_key(key)
    adapter = get_adapter()

    case adapter.get(cache_key) do
      {:ok, value} ->
        value
      {:error, :not_found} ->
        value = fun.()
        adapter.put(cache_key, value, opts)
        value
    end
  end

  @doc """

  """
  def get(key),
    do: build_cache_key(key) |> get_adapter().get()

  @doc """

  """
  def put(key, value, opts \\ []),
    do: build_cache_key(key) |> get_adapter().put(value, opts)

  @doc """

  """
  def delete(key),
    do: build_cache_key(key) |> get_adapter().delete()

  @doc """

  """
  def clear(),
    do: get_adapter().clear()

  defp build_cache_key(value),
    do: :erlang.phash2(value)

  defp get_adapter,
    do: Application.get_env(:memoir, :adapter, Memoir.Adapters.ETS)
end
