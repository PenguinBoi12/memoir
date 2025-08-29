defmodule MemoirTest do
  use ExUnit.Case

  defmodule MockAdapter do
    use Agent

    def start_link(_opts),
      do: Agent.start_link(fn -> %{} end, name: __MODULE__)

    def get(key),
      do: Agent.get(__MODULE__, &Map.fetch(&1, key) |> handle_fetch())

    def put(key, value, _opts \\ []),
      do: Agent.update(__MODULE__, &Map.put(&1, key, value))

    def delete(key),
      do: Agent.update(__MODULE__, &Map.delete(&1, key))

    def clear(),
      do: Agent.update(__MODULE__, fn _ -> %{} end)

    defp handle_fetch({:ok, val}), do: {:ok, val}
    defp handle_fetch(:error), do: {:error, :not_found}
  end

  setup_all do
    Application.put_env(:memoir, :adapter, MockAdapter)
    {:ok, _} = Memoir.start_link()
    :ok
  end

  describe "Memoir cache operations" do
    test "put and get a value" do
      assert :ok = Memoir.put(:foo, "bar")
      assert {:ok, "bar"} = Memoir.get(:foo)
    end

    test "fetch computes value on cache miss" do
      key = :compute_test
      Memoir.delete(key)

      result = Memoir.fetch(key, [], fn -> "computed" end)
      assert result == "computed"

      assert Memoir.fetch(key, [], fn -> "new_value" end) == "computed"
    end

    test "delete removes a key" do
      Memoir.put(:to_delete, 123)
      assert {:ok, 123} = Memoir.get(:to_delete)
      :ok = Memoir.delete(:to_delete)
      assert {:error, :not_found} = Memoir.get(:to_delete)
    end

    test "clear removes all keys" do
      Memoir.put(:a, 1)
      Memoir.put(:b, 2)
      Memoir.clear()

      assert {:error, :not_found} = Memoir.get(:a)
      assert {:error, :not_found} = Memoir.get(:b)
    end

    test "cache macro stores and returns block result" do
      require Memoir

      result = Memoir.cache(:macro_test) do
        "hello world"
      end

      assert result == "hello world"
      assert {:ok, "hello world"} = Memoir.get(:macro_test)
    end

    test "fetch with force option refreshes value" do
      Memoir.put(:force_test, "old")
      result = Memoir.fetch(:force_test, [force: true], fn -> "new" end)

      assert result == "new"
      assert {:ok, "new"} = Memoir.get(:force_test)
    end
  end

  describe "adapter override" do
    defmodule UniqueMockAdapter do
      def get(_key), do: {:ok, :unique_value}
      def put(_key, _value, _opts), do: :unique_put_response
      def delete(_key), do: :unique_delete_response  
      def clear(), do: :unique_clear_response
    end

    test "uses provided adapter for get/2" do
      assert {:ok, :unique_value} = Memoir.get(:test, adapter: UniqueMockAdapter)
    end

    test "uses provided adapter for put/3" do
      assert :unique_put_response = Memoir.put(:test, "val", adapter: UniqueMockAdapter)
    end
  end
end
