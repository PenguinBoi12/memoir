defmodule Memoir.Adapter do
  @moduledoc """
  Behavior for cache adapters with automatic GenServer management.
  """
  @callback get(key :: term()) :: {:ok, term()} | {:error, :not_found}
  @callback put(key :: term(), value :: term(), opts :: keyword()) :: :ok
  @callback delete(key :: term()) :: :ok
  @callback clear() :: :ok

  defmacro __using__(_) do
    quote do
      @behaviour Memoir.Adapter
      use GenServer

      defp ensure_started do
        case GenServer.whereis(__MODULE__) do
          nil -> start_link([])
          pid when is_pid(pid) -> {:ok, pid}
        end
      end

      def get(key) do
        ensure_started()
        GenServer.call(__MODULE__, {:get, key})
      end

      def put(key, value, opts \\ []) do
        ensure_started()
        GenServer.call(__MODULE__, {:put, key, value, opts})
      end

      def delete(key) do
        ensure_started()
        GenServer.call(__MODULE__, {:delete, key})
      end

      def clear do
        ensure_started()
        GenServer.call(__MODULE__, :clear)
      end

      def start_link(opts \\ []),
        do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    end
  end
end