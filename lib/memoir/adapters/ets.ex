defmodule Memoir.Adapters.ETS do
  @moduledoc """
  ETS (Erlang Term Storage) cache adapter for Memoir with automatic GenServer management.

  This adapter provides a high-performance, in-memory caching solution using ETS tables.
  ETS tables offer excellent read performance and are suitable for applications that need
  fast cache access within a single node. It is the default adapter used by Memoir.

  ## Usage

  The adapter is used automatically through the Memoir.Adapter behavior:

      # Get a value
      {:ok, value} = Memoir.Adapters.ETS.get(:my_key)

      # Put a value
      :ok = Memoir.Adapters.ETS.put(:my_key, "my_value")

      # Delete a key
      :ok = Memoir.Adapters.ETS.delete(:my_key)

      # Clear all entries
      :ok = Memoir.Adapters.ETS.clear()

  ## ETS Table Configuration

  The ETS table is created with the following options:
  - `:set` - Only one entry per key (no duplicates)
  - `:protected` - Owner process can read/write, other processes can read
  - `:named_table` - Table can be referenced by module name
  """
  use Memoir.Adapter

  def init(_opts) do
    table = :ets.new(__MODULE__, [:set, :protected, :named_table])
    {:ok, %{table: table}}
  end

  def handle_call({:get, key}, _from, %{table: table} = state) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> {:reply, {:ok, value}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:put, key, value, _opts}, _from, %{table: table} = state) do
    :ets.insert(table, {key, value})
    {:reply, :ok, state}
  end

  def handle_call({:delete, key}, _from, %{table: table} = state) do
    :ets.delete(table, key)
    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, %{table: table} = state) do
    :ets.delete_all_objects(table)
    {:reply, :ok, state}
  end

  def terminate(_reason, %{table: table}) do
    :ets.delete(table)
    :ok
  end
end