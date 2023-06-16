defmodule ExWasm.Section.Table do

  defstruct table_types: []

  def new(table_types) do
    %__MODULE__{table_types: table_types}
  end
end
