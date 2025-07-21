defmodule Memoir.Adapters.ETS do
  @moduledoc """
  Cachex-based cache adapter with automatic GenServer management.
  """
  use Memoir.Adapter

  def init(_opts) do
    {:ok, %{}}
  end

  def handle_call({:get, _key}, _from, state) do
    {:reply, nil, state}
  end

  def handle_call({:put, _key, _value, _opts}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:delete, _key}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, state}
  end
end