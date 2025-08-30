defmodule Memoir.Adapters.ETSTest do
  use ExUnit.Case, async: false
  alias Memoir.Adapters.ETS

  setup do
    safe_stop_server()
    :ok
  end

  describe "basic operations" do
    test "put and get a value" do
      assert :ok = ETS.put(:test_key, "test_value")
      assert {:ok, "test_value"} = ETS.get(:test_key)
    end

    test "get non-existent key returns not_found" do
      assert {:error, :not_found} = ETS.get(:non_existent)
    end

    test "put overwrites existing value" do
      assert :ok = ETS.put(:key, "value1")
      assert :ok = ETS.put(:key, "value2")
      assert {:ok, "value2"} = ETS.get(:key)
    end

    test "delete removes a key" do
      assert :ok = ETS.put(:key, "value")
      assert {:ok, "value"} = ETS.get(:key)
      assert :ok = ETS.delete(:key)
      assert {:error, :not_found} = ETS.get(:key)
    end

    test "delete non-existent key succeeds" do
      assert :ok = ETS.delete(:non_existent)
    end

    test "clear removes all entries" do
      assert :ok = ETS.put(:key1, "value1")
      assert :ok = ETS.put(:key2, "value2")
      assert :ok = ETS.clear()
      assert {:error, :not_found} = ETS.get(:key1)
      assert {:error, :not_found} = ETS.get(:key2)
    end
  end

  describe "TTL functionality" do
    test "entries expire after TTL" do
      assert :ok = ETS.put(:short_ttl, "value", ttl: 50)
      assert {:ok, "value"} = ETS.get(:short_ttl)
      
      Process.sleep(100)
      
      assert {:error, :not_found} = ETS.get(:short_ttl)
    end

    test "entries with infinity TTL never expire" do
      assert :ok = ETS.put(:infinite, "value", ttl: :infinity)
      assert {:ok, "value"} = ETS.get(:infinite)
      
      Process.sleep(50)
      assert {:ok, "value"} = ETS.get(:infinite)
    end

    test "custom TTL overrides default" do
      safe_stop_server()

      {:ok, _pid} = ETS.start_link(ttl: 1000)
      
      assert :ok = ETS.put(:default_ttl, "value1")
      assert :ok = ETS.put(:custom_ttl, "value2", ttl: 2000)

      assert {:ok, "value1"} = ETS.get(:default_ttl)
      assert {:ok, "value2"} = ETS.get(:custom_ttl)
    end

    test "zero or negative TTL uses default TTL" do
      assert :ok = ETS.put(:zero_ttl, "value", ttl: 0)
      assert :ok = ETS.put(:negative_ttl, "value", ttl: -100)
      
      assert {:ok, "value"} = ETS.get(:zero_ttl)
      assert {:ok, "value"} = ETS.get(:negative_ttl)
    end
  end

  describe "automatic cleanup" do
    test "periodic cleanup removes expired entries" do
      safe_stop_server()

      {:ok, _pid} = ETS.start_link(cleanup_interval: 100)
      
      assert :ok = ETS.put(:expires_soon, "value1", ttl: 50)
      assert :ok = ETS.put(:expires_later, "value2", ttl: 300)
      assert :ok = ETS.put(:never_expires, "value3", ttl: :infinity)

      assert {:ok, "value1"} = ETS.get(:expires_soon)
      assert {:ok, "value2"} = ETS.get(:expires_later)
      assert {:ok, "value3"} = ETS.get(:never_expires)
      
      Process.sleep(200)
      
      assert {:error, :not_found} = ETS.get(:expires_soon)
      assert {:ok, "value2"} = ETS.get(:expires_later)
      assert {:ok, "value3"} = ETS.get(:never_expires)
    end
  end

  describe "GenServer management" do
    test "automatically starts when not running" do
      safe_stop_server()
      
      assert :ok = ETS.put(:auto_start, "value")
      assert is_pid(Process.whereis(ETS))
    end

    test "multiple operations work with same server instance" do
      pid1 = ensure_server_running()
      assert :ok = ETS.put(:key1, "value1")
      
      pid2 = ensure_server_running()
      assert :ok = ETS.put(:key2, "value2")
      
      assert pid1 == pid2
      
      assert {:ok, "value1"} = ETS.get(:key1)
      assert {:ok, "value2"} = ETS.get(:key2)
    end

    test "server can be restarted" do
      assert :ok = ETS.put(:before_restart, "value")
      assert {:ok, "value"} = ETS.get(:before_restart)

      safe_stop_server()      

      assert {:error, :not_found} = ETS.get(:before_restart)
      
      assert :ok = ETS.put(:after_restart, "new_value")
      assert {:ok, "new_value"} = ETS.get(:after_restart)
    end
  end

  describe "data types" do
    test "stores various Elixir terms" do
      test_data = [
        {:atom, :test_atom},
        {:string, "test_string"},
        {:integer, 42},
        {:float, 3.14},
        {:list, [1, 2, 3]},
        {:tuple, {:ok, "result"}},
        {:map, %{key: "value"}},
        {:struct, %Date{year: 2023, month: 12, day: 25}}
      ]
      
      for {key, value} <- test_data do
        assert :ok = ETS.put(key, value)
        assert {:ok, ^value} = ETS.get(key)
      end
    end
  end

  describe "concurrent access" do
    test "handles concurrent operations" do
      tasks = for i <- 1..10 do
        Task.async(fn ->
          key = "concurrent_#{i}"
          value = "value_#{i}"
          
          assert :ok = ETS.put(key, value)
          assert {:ok, ^value} = ETS.get(key)
          assert :ok = ETS.delete(key)
          assert {:error, :not_found} = ETS.get(key)
        end)
      end
      
      Enum.each(tasks, &Task.await/1)
    end
  end

  describe "edge cases" do
    test "handles nil values" do
      assert :ok = ETS.put(:nil_key, nil)
      assert {:ok, nil} = ETS.get(:nil_key)
    end

    test "handles empty string" do
      assert :ok = ETS.put(:empty, "")
      assert {:ok, ""} = ETS.get(:empty)
    end

    test "handles large values" do
      large_value = String.duplicate("a", 10_000)
      assert :ok = ETS.put(:large, large_value)
      assert {:ok, ^large_value} = ETS.get(:large)
    end

    test "TTL works with complex keys" do
      complex_key = {:compound, "key", 123}
      assert :ok = ETS.put(complex_key, "value", ttl: 50)
      assert {:ok, "value"} = ETS.get(complex_key)
      
      Process.sleep(100)
      assert {:error, :not_found} = ETS.get(complex_key)
    end
  end

  describe "error handling" do
    test "handles invalid TTL gracefully" do
      assert :ok = ETS.put(:invalid_ttl, "value", ttl: "invalid")
      assert {:ok, "value"} = ETS.get(:invalid_ttl)
    end

    test "operations work after server crash and restart" do
      assert :ok = ETS.put(:before_crash, "value")
      
      safe_stop_server()

      assert :ok = ETS.put(:after_crash, "new_value")
      assert {:ok, "new_value"} = ETS.get(:after_crash)

      assert {:error, :not_found} = ETS.get(:before_crash)
    end
  end

  defp ensure_server_running do
    case Process.whereis(ETS) do
      nil ->
        {:ok, pid} = ETS.start_link()
        pid
      pid when is_pid(pid) ->
        pid
    end
  end

  defp safe_stop_server do
    case Process.whereis(ETS) do
      nil -> :ok
      pid when is_pid(pid) -> 
        GenServer.stop(ETS, :normal)
        Process.sleep(10)
    end
  end
end