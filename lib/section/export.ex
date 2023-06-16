defmodule ExWasm.Section.Export do
  defstruct exports: []

  def new(exports) do
    %__MODULE__{exports: exports}
  end
end
