defmodule Memoir.Adapters.CachexTest do
  use ExUnit.Case, async: true

  import Cachex.Spec
  alias Memoir.Adapters.Cachex

  defp unique_cache, do: :"test_cache_#{:erlang.unique_integer()}"

  describe "init/1" do
    test "returns ok if cache already started" do
      cache_name = unique_cache()

      {:ok, _state} = Cachex.init(cache_name: cache_name)
      {:ok, state} = Cachex.init(cache_name: cache_name)

      assert state.cache_name == cache_name
    end

    test "returns error if error with cachex" do
      cache_name = unique_cache()

      error = Cachex.start_link(
        cache_name: cache_name,
        expiration: expiration(default: "5")
      )

      assert error == {:error, :invalid_expiration}
    end
  end

  describe "handle_call/2" do
    setup do
      cache_name = unique_cache()
      {:ok, pid} = GenServer.start_link(Cachex, cache_name: cache_name)
      {:ok, %{pid: pid, cache_name: cache_name}}
    end

    test "get returns {:ok, value} for existing key", %{pid: pid} do
      GenServer.call(pid, {:put, :foo, "bar", []})
      assert GenServer.call(pid, {:get, :foo}) == {:ok, "bar"}
    end

    test "get returns {:error, :not_found} for missing key", %{pid: pid} do
      assert GenServer.call(pid, {:get, :missing}) == {:error, :not_found}
    end

    test "get returns {:error, :not_found} when key deleted", %{pid: pid} do
      GenServer.call(pid, {:delete, :key})
      assert GenServer.call(pid, {:get, :key}) == {:error, :not_found}
    end

    test "clear removes all keys", %{pid: pid} do
      GenServer.call(pid, {:put, :a, 1, []})
      GenServer.call(pid, {:put, :b, 2, []})

      assert GenServer.call(pid, :clear) == :ok
      assert GenServer.call(pid, {:get, :a}) == {:error, :not_found}
      assert GenServer.call(pid, {:get, :b}) == {:error, :not_found}
    end

    test "get returns {:error, :not_found} when cache is in invalid state" do
      fake_cache_name = :"nonexistent_cache_#{:erlang.unique_integer()}"
      {:ok, pid} = GenServer.start_link(Cachex, [])

      :sys.replace_state(pid, fn _state -> %{cache_name: fake_cache_name} end)

      assert GenServer.call(pid, {:get, :foo}) == {:error, :no_cache}
    end
  end
end
