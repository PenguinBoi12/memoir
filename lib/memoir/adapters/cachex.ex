defmodule Memoir.Adapters.Cachex do
  @moduledoc """
  Cachex-based cache adapter with automatic GenServer management.
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
      {:error, _} -> {:error, :not_found}
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