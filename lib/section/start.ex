defmodule ExWasm.Section.Start do

  defstruct [:start_index]

  def new(start_index) do
    %__MODULE__{start_index: start_index}
  end
end
