defmodule ExWasm.Interpreter.Embedding do
  defstruct variables: %{}, functions: %{}

  def new(), do: %__MODULE__{}

  def put_variable(%__MODULE__{variables: variables} = embedding, module, name, type, value) do
    %__MODULE__{embedding | variables: Map.put(variables, {module, name}, {type, value})}
  end

  def get_variable(%__MODULE__{variables: variables}, module, name) do
    case Map.get(variables, {module, name}) do
      nil -> {:error, "Variable not imported"}
      variable -> {:ok, variable}
    end
  end

  def set_variable(%__MODULE__{variables: variables} = embedding, module, name, type, value) do
    with {current_type, _value} <- Map.get(variables, {module, name}),
         {:type_match, _current_type, true} <- {:type_match, current_type, match?(^current_type, type)} do
      %__MODULE__{embedding | variables: Map.replace(variables, {module, name}, {type, value})}
    else
      nil -> {:error, "Variable does not exists in embedding"}
      {:type_match, current_type, false} -> {:error, "New variable has wrong type. Expected #{current_type} got #{type}"}
    end
  end


  def put_function(%__MODULE__{functions: functions} = embedding, module, name, func) when is_function(func) do
    %__MODULE__{embedding | functions: Map.put(functions, {module, name}, func)}
  end
end
