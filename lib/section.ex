defmodule ExWasm.Section do
  alias ExWasm.Section.Table
  alias ExWasm.Section.Function
  alias ExWasm.Section.Import
  alias ExWasm.Section.Type
  defstruct type: :none, x: []

  def new(type, x) do
    %__MODULE__{type: type, x: x}
  end

  def new_type_section(function_types) do
    Type.new(function_types)
  end

  def new_import_section(imports) do
    Import.new(imports)
  end

  def new_function_section(index) do
    Function.new(index)
  end

  def new_table_section(table_types) do
    Table.new(table_types)
  end

  def new_export_section(exports) do
    Export.new(exports)
  end
end
