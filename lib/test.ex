IO.inspect("A")
defmodule Test do

  IO.inspect("B")

  for a <- 1..10 do
    IO.inspect(a)
    def unquote("test_#{a}" |> String.to_atom())() do
      unquote(a)
    end
  end
end
