defmodule MemoirTest do
  use ExUnit.Case
  doctest Memoir

  test "greets the world" do
    assert Memoir.hello() == :world
  end
end
