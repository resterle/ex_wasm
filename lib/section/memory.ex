defmodule ExWasm.Section.Memory do

  defstruct memory: []

  def new(memory) do
    %__MODULE__{memory: memory}
  end
end
