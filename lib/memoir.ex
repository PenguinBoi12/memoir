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
  Memoir.cache({:user, 123}, ttl: :timer.minutes(5)) do
    expensive_user_lookup(123)
  end
  ```

  You can also interact with the cache directly:

  ```elixir
  Memoir.put({:user, 123}, "value", ttl: :timer.minutes(5))

  Memoir.get({:user, 123})

  Memoir.delete({:user, 123})

  Memoir.clear()
  ```

  ## Configuration

  You can configure Memoir in your config.exs:

  ```
  config :memoir,
    adapter: Memoir.Adapters.Cachex,
    adapter_opts: [ttl: 300_000]
  ```

  You can also configure a cache per module like so:

  ```elixir
  defmodule Greeter do
    use Memoir,
      name: :greeter_cache,
      adapter: Memoir.Adapters.MyAdapter,
      ttl: :timer.minutes(5)

    def greet(name) do
      cache({:greet, name}) do # This will use the configured cache
        "Hello, #{name}!"
      end
    end
  end
  ```
  """
  use Supervisor

  @doc """
  Starts the Memoir supervisor with the configured cache adapter.

  ## Parameters

    * `opts` - Keyword list of options passed to the supervisor (optional)

  """
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
  Provides a `use` macro to inject caching functions into your module with default options.

  When you `use Memoir, cache_opts`, it will define the following functions in your module:
    * `cache/3` macro for caching with blocks
    * `fetch/3` for cache-or-compute operations
    * `get/2` for retrieving cached values
    * `put/3` for storing values in cache
    * `delete/2` for removing cached values
    * `clear/1` for clearing all cached values
    * `build_options/1` for merging provided options with defaults

  ## Parameters

    * `cache_opts` - Default options that will be merged with options passed to cache functions

  ## Examples

  Here's how you would typically use Memoir in a module:

      defmodule MyService do
        use Memoir, name: :my_service, ttl: 60_000

        def expensive_computation(id) do
          cache({:computation, id}, ttl: :timer.minutes(5)) do
            # Expensive work here
            "result_for_" <> to_string(id)
          end
        end

        def get_user_data(user_id) do
          # Uses default ttl: 60_000 from use options
          cache({:user, user_id}) do
            # Database lookup or API call
            %{id: user_id, name: "User " <> to_string(user_id)}
          end
        end
      end

  """
  defmacro __using__(cache_opts) do
    quote do
      @doc """
      Cache the result of the given block.

      ## Parameters

        * `key` - The cache key (can be any term)
        * `opts` - Keyword list of options (optional)
        * `block` - The code block to execute if cache miss

      ## Options

        * `:expire_in` - TTL in milliseconds
        * `:force` - If true, forces cache refresh
        * `:name` - Cache namespace (default: :memoir)

      """
      defmacro cache(key, opts \\ [], do: block) do
        opts = build_options(opts)

        quote do
          Memoir.cache(
            unquote(key),
            unquote(opts)
          ) do
            unquote(block)
          end
        end
      end

      @doc """
      Fetch a value from cache or compute it using the provided function.
      """
      def fetch(key, opts \\ [], fun),
        do: Memoir.fetch(key, build_options(opts), fun)

      @doc """
      Get a value from the cache.
      """
      def get(key, opts \\ []),
        do: Memoir.get(key, build_options(opts))

      @doc """
      Put a value in the cache.
      """
      def put(key, value, opts \\ []),
        do: Memoir.put(key, value, build_options(opts))

      @doc """
      Delete a value from the cache.
      """
      def delete(key, opts \\ []),
        do: Memoir.delete(key, build_options(opts))

      @doc """
      Clear all values from the cache.
      """
      def clear(opts \\ []),
        do: Memoir.clear(build_options(opts))

      @doc """
      Build final options by merging provided options with module defaults.
      """
      def build_options(opts),
        do: Keyword.merge(opts, unquote(cache_opts))
    end
  end

  @doc """
  Main caching function that accepts a block.

  This macro provides a convenient way to cache the result of expensive computations.
  If the key exists in cache and hasn't expired, the cached value is returned.
  Otherwise, the block is executed and its result is cached.

  ## Parameters

    * `key` - The cache key (can be any term that can be hashed)
    * `opts` - Keyword list of caching options (optional)
    * `block` - The code block to execute on cache miss

  ## Options

    * `:expire_in` - Time-to-live in milliseconds
    * `:force` - If `true`, forces cache refresh by deleting existing entry first
    * `:name` - Cache namespace (default: `:memoir`)
    * `:adapter` - Override the configured adapter for this operation

  ## Examples

      iex> Memoir.cache(:my_key, ttl: 5000) do
      ...>   "expensive computation"
      ...> end
      "expensive computation"

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

  This is the core function that implements the cache-or-compute pattern.
  It first checks if the key exists in cache, and if not, executes the
  provided function and stores its result.

  ## Parameters

    * `key` - The cache key
    * `opts` - Keyword list of options (optional)
    * `fun` - Zero-arity function to execute on cache miss

  ## Options

    * `:force` - If `true`, deletes existing cache entry before lookup
    * `:ttl` - TTL in milliseconds for the cached value
    * `:name` - Cache namespace
    * `:adapter` - Adapter to use for this operation

  ## Examples

      iex> Memoir.fetch(:test_key, [], fn -> "computed value" end)
      "computed value"
  """
  def fetch(key, opts \\ [], fun) do
    if Keyword.get(opts, :force, false),
      do: delete(key, opts)

    case get(key, opts) do
      {:ok, value} ->
        value
      {:error, :not_found} ->
        value = fun.()
        put(key, value, opts)
        value
    end
  end

  @doc """
  Get a value from the cache.

  Retrieves a value associated with the given key from the cache.
  Returns `{:ok, value}` if the key exists and hasn't expired,
  or `{:error, :not_found}` otherwise.

  ## Parameters

    * `key` - The cache key to look up
    * `opts` - Keyword list of options (optional)

  ## Options

    * `:name` - Cache namespace (default: `:memoir`)
    * `:adapter` - Adapter to use for this operation

  ## Examples

      iex> Memoir.get(:example_key, adapter: MemoirTest.MockAdapter)
      {:ok, "example_value"}
  """
  def get(key, opts \\ []),
    do: build_cache_key(key, opts) |> get_adapter(opts).get()

  @doc """
  Put a value in the cache.

  Stores a value in the cache with the given key. The value will be
  available for subsequent `get/2` and `fetch/3` operations until
  it expires (if TTL is set) or is explicitly deleted.

  ## Parameters

    * `key` - The cache key
    * `value` - The value to store (can be any term)
    * `opts` - Keyword list of options (optional)

  ## Options

    * `:expire_in` or `:ttl` - Time-to-live in milliseconds
    * `:name` - Cache namespace (default: `:memoir`)
    * `:adapter` - Adapter to use for this operation

  ## Examples

      # Simple put/get
      iex> Memoir.put(:simple_key, "simple_value")
      :ok
  """
  def put(key, value, opts \\ []),
    do: build_cache_key(key, opts) |> get_adapter(opts).put(value, opts)

  @doc """
  Delete a value from the cache.

  Removes the cache entry associated with the given key.
  Returns `:ok` regardless of whether the key existed.

  ## Parameters

    * `key` - The cache key to delete
    * `opts` - Keyword list of options (optional)

  ## Options

    * `:name` - Cache namespace (default: `:memoir`)
    * `:adapter` - Adapter to use for this operation

  ## Examples

      # Delete existing key
      iex> Memoir.delete(:to_delete)
      :ok

  """
  def delete(key, opts \\ []),
    do: build_cache_key(key, opts) |> get_adapter(opts).delete()

  @doc """
  Clear all values from the cache.

  Removes all cached entries from the specified cache namespace.
  This operation cannot be undone.

  ## Parameters

    * `opts` - Keyword list of options (optional)

  ## Options

    * `:name` - Cache namespace to clear (default: `:memoir`)
    * `:adapter` - Adapter to use for this operation

  ## Examples

      iex> Memoir.clear(name: :temp_cache)
      :ok

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