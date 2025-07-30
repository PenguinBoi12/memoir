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

  defmacro __using__(cache_opts) do
    quote do
      defmacro cache(key, opts \\ [], do: block) do
        quote do
          __MODULE__.fetch(
            unquote(key),
            unquote(opts),
            fn -> unquote(block) end
          )
        end
      end

      # Generate cache functions that use the configured adapter and options
      def fetch(key, opts \\ [], fun),
        do: Memoir.fetch(key, build_options(opts), fun)

      def get(key),
        do: Memoir.get(key)

      def put(key, value, opts \\ []),
        do: Memoir.put(key, value, build_options(opts))

      def delete(key),
        do: Memoir.delete(key)

      def clear(),
        do: Memoir.clear()

      defp build_options(opts),
        do: Keyword.merge(opts, unquote(cache_opts))
    end
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
      Memoir.fetch(
        unquote(key),
        unquote(opts),
        fn -> unquote(block) end
      )
    end
  end

  @doc """
  Fetch from cache or execute the given function.
  """
  def fetch(key, opts \\ [], fun) do
    cache_key = build_cache_key(key, opts)
    adapter = get_adapter(opts)

    if Keyword.get(opts, :force, false),
      do: adapter.delete(cache_key)

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
  Get a value from the cache.
  """
  def get(key, opts \\ []),
    do: build_cache_key(key, opts) |> get_adapter(opts).get()

  @doc """
  Put a value in the cache.
  """
  def put(key, value, opts \\ []),
    do: build_cache_key(key, opts) |> get_adapter(opts).put(value, opts)

  @doc """
  Delete a value from the cache.
  """
  def delete(key, opts \\ []),
    do: build_cache_key(key, opts) |> get_adapter(opts).delete()

  @doc """
  Clear all values from the cache.
  """
  def clear(opts \\ []),
    do: get_adapter(opts).clear()

  defp build_cache_key(value, opts) do
    name = Keyword.get(opts, :name, :memoir)
    :erlang.phash2({name, value})
  end

  defp get_adapter(opts \\ [])

  defp get_adapter([adapter: adapter]),
    do: adapter

  defp get_adapter(_opts),
    do: Application.get_env(:memoir, :adapter, Memoir.Adapters.ETS)
end