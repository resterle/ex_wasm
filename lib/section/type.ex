defmodule ExWasm.Section.Type do

  defstruct function_types: []

  def new(function_types) do
    %__MODULE__{function_types: function_types}
  end

  def get_type(%__MODULE__{function_types: types}, index) do
    Enum.at(types, index)
  end
end
