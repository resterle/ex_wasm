defmodule ExWasm.Section.Global do

  defstruct globals: []

  def new(globals) do
    %__MODULE__{globals: globals}
  end
end
