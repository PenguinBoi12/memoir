defmodule Memoir.Adapters.Cachex do
  @moduledoc """
  A `Cachex`-based cache adapter with automatic `GenServer` management.

  This adapter wraps [Cachex](https://hex.pm/packages/cachex) operations
  (`get/2`, `put/4`, `delete/2`, `clear/1`) in a `GenServer` process,
  so it can be used as part of the `Memoir` caching framework.

  ## Features
    * Starts and supervises a named `Cachex` cache instance.
    * Provides `:get`, `:put`, `:delete`, and `:clear` calls through `GenServer`.
    * Automatically handles already-started cache processes.

  ## Options
    * `:cache_name` — the name of the underlying Cachex cache (default: `:memoir_cachex`)
    * Any other options supported by `Cachex.start_link/2`.

  ## Example

      iex> GenServer.call(pid, {:put, :foo, "bar", []})
      :ok

      iex> GenServer.call(pid, {:get, :foo})
      {:ok, "bar"}

      iex> GenServer.call(pid, {:delete, :foo})
      :ok

      iex> GenServer.call(pid, {:get, :foo})
      {:error, :not_found}

      iex> GenServer.call(pid, :clear)
      :ok
  """
  use Memoir.Adapter

  def init(opts) do
    cache_name = Keyword.get(opts, :cache_name, :memoir_cachex)

    case Cachex.start_link(cache_name, opts) do
      {:ok, _pid} -> {:ok, %{cache_name: cache_name}}
      {:error, {:already_started, _}} -> {:ok, %{cache_name: cache_name}}
      error -> error
    end
  end

  def handle_call({:get, key}, _from, %{cache_name: cache_name} = state) do
    result = case Cachex.get(cache_name, key) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, value} -> {:ok, value}
      {:error, error} -> {:error, error}
    end

    {:reply, result, state}
  end

  def handle_call({:put, key, value, opts}, _from, %{cache_name: cache_name} = state) do
    expire = Keyword.get(opts, :ttl)

    Cachex.put(cache_name, key, value, expire: expire)
    {:reply, :ok, state}
  end

  def handle_call({:delete, key}, _from, %{cache_name: cache_name} = state) do
    Cachex.del(cache_name, key)
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, %{cache_name: cache_name} = state) do
    Cachex.clear(cache_name)
    {:reply, :ok, state}
  end
end