defmodule ExWasm.Section.Import do

  defstruct imports: []

  def new(imports) do
    %__MODULE__{imports: imports}
  end

  def functions(%__MODULE__{imports: imports}) do
    Enum.filter(imports, fn
      {_name, {:typeindex, _idx}} -> true
      _other -> false
    end)
  end

  def globals(%__MODULE__{imports: imports}) do
    Enum.filter(imports, fn
      {_name, {:global, _idx}} -> true
      _other -> false
    end)
  end
end
