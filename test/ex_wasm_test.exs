defmodule ExWasmTest do
  use ExUnit.Case
  doctest ExWasm

  test "greets the world 2627" do
    ExWasm.parse()
    |> IO.inspect()
  end
end
