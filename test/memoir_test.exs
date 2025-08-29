defmodule MemoirTest do
  use ExUnit.Case, async: false
  doctest Memoir

  defmodule MockAdapter do
    use Agent

    def start_link(_) do
      Agent.start_link(fn -> %{} end, name: __MODULE__)
    end

    def get(key) do
      Agent.get(__MODULE__, fn state ->
        case Map.get(state, key) do
          nil -> {:error, :not_found}
          value -> {:ok, value}
        end
      end)
    end

    def put(key, value, _opts) do
      Agent.update(__MODULE__, fn state ->
        Map.put(state, key, value)
      end)
    end

    def delete(key) do
      Agent.update(__MODULE__, fn state ->
        Map.delete(state, key)
      end)
    end

    def clear do
      Agent.update(__MODULE__, fn _state -> %{} end)
    end
  end

  setup do
    {:ok, _pid} = MockAdapter.start_link([])

    Application.put_env(:memoir, :adapter, MockAdapter)

    on_exit(fn ->
      if Process.whereis(MockAdapter) do
        Agent.stop(MockAdapter)
      end
      Application.delete_env(:memoir, :adapter)
    end)

    :ok
  end

  describe "cache/3 macro" do
    test "caches the result of expensive computation" do
      result1 = Memoir.cache(:test_key) do
        Process.sleep(10)
        "expensive_result"
      end

      start_time = System.monotonic_time(:millisecond)
      result2 = Memoir.cache(:test_key) do
        Process.sleep(100)  # This shouldn't execute
        "should_not_see_this"
      end
      end_time = System.monotonic_time(:millisecond)

      assert result1 == "expensive_result"
      assert result2 == "expensive_result"

      assert ((end_time - start_time) < 50)
    end

    test "supports different cache keys" do
      result1 = Memoir.cache(:key1) do
        "result1"
      end

      result2 = Memoir.cache(:key2) do
        "result2"
      end

      assert result1 == "result1"
      assert result2 == "result2"

      # Verify they're cached independently
      cached1 = Memoir.cache(:key1) do
        "should_not_execute"
      end

      cached2 = Memoir.cache(:key2) do
        "should_not_execute"
      end

      assert cached1 == "result1"
      assert cached2 == "result2"
    end

    test "supports complex cache keys" do
      user_id = 123
      role = :admin

      result1 = Memoir.cache({:user, user_id, role}) do
        "user_data_#{user_id}_#{role}"
      end

      result2 = Memoir.cache({:user, user_id, role}) do
        "should_not_execute"
      end

      assert result1 == "user_data_123_admin"
      assert result2 == "user_data_123_admin"
    end

    test "supports force option to bypass cache" do
      # Cache initial value
      Memoir.cache(:force_test) do
        "original"
      end

      # Force refresh should execute the block again
      result = Memoir.cache(:force_test, force: true) do
        "updated"
      end

      assert result == "updated"

      # Subsequent calls should return the new cached value
      cached = Memoir.cache(:force_test) do
        "should_not_execute"
      end

      assert cached == "updated"
    end
  end

  describe "fetch/3" do
    test "executes function when cache miss" do
      fun = fn -> "computed_value" end
      result = Memoir.fetch(:fetch_test, [], fun)
      assert result == "computed_value"
    end

    test "returns cached value when cache hit" do
      fun1 = fn -> "first_value" end
      fun2 = fn -> "second_value" end

      result1 = Memoir.fetch(:fetch_test2, [], fun1)
      result2 = Memoir.fetch(:fetch_test2, [], fun2)

      assert result1 == "first_value"
      assert result2 == "first_value"  # Should return cached, not execute fun2
    end

    test "supports force option" do
      fun1 = fn -> "first" end
      fun2 = fn -> "second" end

      Memoir.fetch(:force_fetch, [], fun1)
      result = Memoir.fetch(:force_fetch, [force: true], fun2)

      assert result == "second"
    end
  end

  describe "get/2" do
    test "returns cached value when present" do
      Memoir.put(:get_test, "test_value")
      assert {:ok, "test_value"} == Memoir.get(:get_test)
    end

    test "returns error when not found" do
      assert {:error, :not_found} == Memoir.get(:nonexistent_key)
    end
  end

  describe "put/3" do
    test "stores value in cache" do
      Memoir.put(:put_test, "stored_value")
      assert {:ok, "stored_value"} == Memoir.get(:put_test)
    end

    test "overwrites existing value" do
      Memoir.put(:overwrite_test, "original")
      Memoir.put(:overwrite_test, "updated")
      assert {:ok, "updated"} == Memoir.get(:overwrite_test)
    end
  end

  describe "delete/2" do
    test "removes value from cache" do
      Memoir.put(:delete_test, "to_be_deleted")
      assert {:ok, "to_be_deleted"} == Memoir.get(:delete_test)

      Memoir.delete(:delete_test)
      assert {:error, :not_found} == Memoir.get(:delete_test)
    end

    test "handles deleting non-existent key" do
      # Should not raise an error
      Memoir.delete(:nonexistent_delete_key)
      assert {:error, :not_found} == Memoir.get(:nonexistent_delete_key)
    end
  end

  describe "clear/1" do
    test "removes all values from cache" do
      Memoir.put(:clear_test1, "value1")
      Memoir.put(:clear_test2, "value2")

      assert {:ok, "value1"} == Memoir.get(:clear_test1)
      assert {:ok, "value2"} == Memoir.get(:clear_test2)

      Memoir.clear()

      assert {:error, :not_found} == Memoir.get(:clear_test1)
      assert {:error, :not_found} == Memoir.get(:clear_test2)
    end
  end

  describe "__using__ macro" do
    defmodule TestCacheModule do
      use Memoir, ttl: 1000, name: :test_cache
    end

    test "generates cache functions with default options" do
      require TestCacheModule

      result1 = TestCacheModule.cache(:module_test) do
        "module_result"
      end

      result2 = TestCacheModule.cache(:module_test) do
        "should_not_execute"
      end

      assert result1 == "module_result"
      assert result2 == "module_result"
    end

    test "module can interact with cache directly" do
      TestCacheModule.put(:direct_test, "direct_value")
      assert {:ok, "direct_value"} == TestCacheModule.get(:direct_test)

      TestCacheModule.delete(:direct_test)
      assert {:error, :not_found} == TestCacheModule.get(:direct_test)
    end
  end

  describe "cache key generation" do
    test "different names generate different cache keys" do
      # Cache with default name
      Memoir.cache(:same_key) do
        "default_name"
      end

      # Cache with custom name should be separate
      Memoir.cache(:same_key, name: :custom) do
        "custom_name"
      end

      # Verify they're stored separately
      default_result = Memoir.cache(:same_key) do
        "should_not_execute"
      end

      custom_result = Memoir.cache(:same_key, name: :custom) do
        "should_not_execute"
      end

      assert default_result == "default_name"
      assert custom_result == "custom_name"
    end
  end

  describe "error handling" do
    test "handles exceptions in cached block" do
      assert_raise RuntimeError, "test error", fn ->
        Memoir.cache(:error_test) do
          raise "test error"
        end
      end

      # Error should not be cached
      result = Memoir.cache(:error_test) do
        "successful_result"
      end

      assert result == "successful_result"
    end

    test "handles exceptions in fetch function" do
      error_fun = fn -> raise "fetch error" end
      success_fun = fn -> "success" end

      assert_raise RuntimeError, "fetch error", fn ->
        Memoir.fetch(:fetch_error_test, [], error_fun)
      end

      # Error should not be cached
      result = Memoir.fetch(:fetch_error_test, [], success_fun)
      assert result == "success"
    end
  end

  describe "integration tests" do
    test "realistic user lookup scenario" do
      # Simulate expensive user lookup
      expensive_user_lookup = fn id ->
        Process.sleep(10)  # Simulate database call
        %{id: id, name: "User #{id}", email: "user#{id}@example.com"}
      end

      # First lookup should be slow
      start_time = System.monotonic_time(:millisecond)
      user1 = Memoir.cache({:user, 123}, expire_in: :timer.minutes(5)) do
        expensive_user_lookup.(123)
      end
      first_time = System.monotonic_time(:millisecond) - start_time

      # Second lookup should be fast (cached)
      start_time = System.monotonic_time(:millisecond)
      user2 = Memoir.cache({:user, 123}, expire_in: :timer.minutes(5)) do
        expensive_user_lookup.(123)
      end
      second_time = System.monotonic_time(:millisecond) - start_time

      assert user1 == user2
      assert user1.id == 123
      assert user1.name == "User 123"
      assert first_time > 5  # Should take some time
      assert second_time < 5 # Should be fast (cached)
    end

    test "cache invalidation workflow" do
      # Cache a user
      user = Memoir.cache({:user, 456}) do
        %{id: 456, name: "Original Name"}
      end

      assert user.name == "Original Name"

      # Force refresh after update
      updated_user = Memoir.cache({:user, 456}, force: true) do
        %{id: 456, name: "Updated Name"}
      end

      assert updated_user.name == "Updated Name"

      # Verify the cache was updated
      cached_user = Memoir.cache({:user, 456}) do
        %{id: 456, name: "Should Not See This"}
      end

      assert cached_user.name == "Updated Name"
    end
  end
end