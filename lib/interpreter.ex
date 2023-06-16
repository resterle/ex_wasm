defmodule ExWasm.Interpreter do
  alias ExWasm.Section
  alias ExWasm.Interpreter.Embedding
  alias ExWasm.Interpreter

  defstruct [:embedding, :function_instance, :exports, :start_index, :globals, :memory]

  def new(sections, %Embedding{} = embedding) do
    section_map = Enum.reduce(sections, %{}, fn
      %Section{}, map -> map
      module, map -> Map.put(map, module.__struct__, module)
    end)

    Interpreter.Initializer.create_instance(section_map, embedding)
  end

  def execute(%__MODULE__{} = instance, name, %Interpreter.Embedding{} = embedding, params \\ []) do
    with {:exports, true} <- {:exports, exports?(instance, name)},
          %{type: :function, index: index} = export(instance, name),
          {:internal, {params_types, result_type}, {locals, code}} = function_by_index(instance, index),
          {:execution, {:ok, execution}} <- {:execution, Interpreter.Execution.new(code, instance.globals, locals, params_types, result_type)},
          {:execution, {:ok, execution}} <- {:execution, Interpreter.Execution.initialize(execution, embedding, params)},
          {:execution, {:ok, execution}} <- {:execution, Interpreter.Execution.execute(execution)},
          {:result, {:ok, result}} <- {:result, Interpreter.Execution.result(execution)} do
      {:ok, result, execution}
    else
      {:exports, false} -> {:error, "Function \"#{name}\" not exported by module"}
      {:execution, error} -> error
      _other -> {:error, "Unknown error"}
    end
  end

  def exports(%__MODULE__{exports: exports}), do: exports

  def exports?(%__MODULE__{} = instance, name) do
    exports(instance)
    |> Map.keys()
    |> Enum.member?(name)
  end


  defp export(%__MODULE__{} = instance, name) do
    exports(instance)
    |> Map.get(name)
  end

  defp function_by_index(%__MODULE__{function_instance: functions}, index), do: Enum.at(functions, index)
end
