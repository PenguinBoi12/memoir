defmodule Memoir.Adapters.Cachex do
  @moduledoc """
  A `Cachex`-based cache adapter with automatic `GenServer` management.

  This adapter provide a wrapper around [Cachex's](https://hex.pm/packages/cachex) operations
  (`get/2`, `put/4`, `delete/2`, `clear/1`), so it can be used as part of the `Memoir`
  caching framework.

  ## Usage

  The adapter is used automatically through the Memoir.Adapter behavior:

      # Get a value
      {:ok, value} = Memoir.Adapters.Cachex.get(:my_key)

      # Put a value
      :ok = Memoir.Adapters.Cachex.put(:my_key, "my_value")

      # Delete a key
      :ok = Memoir.Adapters.Cachex.delete(:my_key)

      # Clear all entries
      :ok = Memoir.Adapters.Cachex.clear()

  ## Cachex configuration

  - `:cache_name` - the name of Cachex's cache (default: `:memoir_cachex`)
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

  def terminate(_reason, _state) do
    :ok
  end
end