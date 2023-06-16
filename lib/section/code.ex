defmodule ExWasm.Section.Code do

  defstruct code: []

  def new(code) do
    %__MODULE__{code: code}
  end
end
