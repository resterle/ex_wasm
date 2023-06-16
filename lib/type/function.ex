defmodule ExWasm.Type.Function do

  defstruct params: [],  returns: []

  def new(params, returns) when is_list(params) and is_list(returns) do
    %__MODULE__{params: params, returns: returns}
  end

end
