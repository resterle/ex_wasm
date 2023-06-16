defmodule ExWasm do
  @moduledoc """
  Documentation for `ExWasm`.
  """

  def load(file) do
    {:ok, file} = open_file(file)
    new_ctx(file)
    |> ExWasm.Parser.parse()
  end

  defp to_module() do

  end

  def new_ctx(file) do
    {:ok, reader} = ExWasm.Reader.start_link(file)
    %{reader: reader, version: 1, sections: []}
  end

  def open_file(path) when is_binary(path) do
    case File.open(path) do
      {:ok, _}  = res -> res
      {:error, error} ->
        {:error, error}
    end
  end

end
