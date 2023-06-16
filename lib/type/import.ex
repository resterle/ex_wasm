defmodule ExWasm.Type.Import do

  defstruct module: "", name: "", desc: {}

  def new(module, name, desc) do
    %__MODULE__{module: module, name: name, desc: desc}
  end

end
