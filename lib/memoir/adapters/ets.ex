defmodule Memoir.Adapters.ETS do
  @moduledoc """
  ETS (Erlang Term Storage) cache adapter for Memoir with automatic GenServer management and TTL support.

  This adapter provides a high-performance, in-memory caching solution using ETS tables.
  ETS tables offer excellent read performance and are suitable for applications that need
  fast cache access within a single node. It is the default adapter used by Memoir.

  ## Features

  - Automatic ETS table creation and management
  - High-performance in-memory storage
  - TTL (time-to-live) support with automatic expiration
  - Periodic cleanup of expired entries
  - Automatic cleanup on process termination
  - Thread-safe operations via GenServer

  ## Usage

  The adapter is used automatically through the Memoir.Adapter behavior:

      # Get a value
      {:ok, value} = Memoir.Adapters.ETS.get(:my_key)

      # Put a value with default TTL
      :ok = Memoir.Adapters.ETS.put(:my_key, "my_value")

      # Put a value with custom TTL (in milliseconds)
      :ok = Memoir.Adapters.ETS.put(:my_key, "my_value", ttl: 60_000)

      # Put a value that never expires
      :ok = Memoir.Adapters.ETS.put(:my_key, "my_value", ttl: :infinity)

      # Delete a key
      :ok = Memoir.Adapters.ETS.delete(:my_key)

      # Clear all entries
      :ok = Memoir.Adapters.ETS.clear()

  ## Configuration

  - `ttl`: Default TTL in milliseconds (default: 3600000 = 1 hour)
  - `cleanup_interval`: How often to run cleanup in milliseconds (default: 5000 = 5 seconds)

  ## ETS Table Configuration

  The ETS table is created with the following options:
  - `:set` - Only one entry per key (no duplicates)
  - `:protected` - Owner process can read/write, other processes can read
  - `:named_table` - Table can be referenced by module name

  ## TTL Implementation

  Values are stored as `{value, expiration_timestamp}` tuples. The cleanup process
  runs periodically to remove expired entries, and entries are also checked for
  expiration during read operations.
  """
  use Memoir.Adapter

  @default_ttl :timer.hours(1)
  @default_cleanup_interval :timer.seconds(5)

  def init(opts) do
    table = :ets.new(__MODULE__, [:set, :protected, :named_table])

    ttl = Keyword.get(opts, :ttl, @default_ttl)
    cleanup_interval = Keyword.get(opts, :cleanup_interval, @default_cleanup_interval)

    schedule_cleanup(cleanup_interval)

    {:ok, %{
      table: table,
      default_ttl: ttl,
      cleanup_interval: cleanup_interval
    }}
  end

  def handle_call({:get, key}, _from, %{table: table} = state) do
    case :ets.lookup(table, key) do
      [{^key, {value, expiration}}] ->
        if expired?(expiration) do
          :ets.delete(table, key)
          {:reply, {:error, :not_found}, state}
        else
          {:reply, {:ok, value}, state}
        end
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:put, key, value, opts}, _from, %{table: table, default_ttl: default_ttl} = state) do
    ttl = Keyword.get(opts, :ttl, default_ttl)

    expiration = case ttl do
      :infinity -> :infinity
      ttl_ms when is_integer(ttl_ms) and ttl_ms > 0 ->
        System.monotonic_time(:millisecond) + ttl_ms
      _ ->
        System.monotonic_time(:millisecond) + default_ttl
    end

    :ets.insert(table, {key, {value, expiration}})
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

  def handle_info(:cleanup, %{table: table, cleanup_interval: cleanup_interval} = state) do
    cleanup_expired_entries(table)
    schedule_cleanup(cleanup_interval)
    {:noreply, state}
  end

  def terminate(_reason, %{table: table}) do
    :ets.delete(table)
    :ok
  end

  defp schedule_cleanup(interval),
    do: Process.send_after(self(), :cleanup, interval)

  defp cleanup_expired_entries(table) do
    now = System.monotonic_time(:millisecond)

    match_spec = [
      {{:"$1", {:"$2", :"$3"}},
       [{:andalso, {:is_integer, :"$3"}, {:<, :"$3", {:const, now}}}],
       [:"$1"]}
    ]

    expired_keys = :ets.select(table, match_spec)

    Enum.each expired_keys, fn key ->
      :ets.delete(table, key)
    end

    length(expired_keys)
  end

  defp expired?(:infinity),
    do: false

  defp expired?(expiration) when is_integer(expiration),
    do: System.monotonic_time(:millisecond) > expiration
end