defmodule ExWasm.Section.Function do
  defstruct function_indexes: []

  def new(function_indexes) do
    %__MODULE__{function_indexes: function_indexes}
  end
end
