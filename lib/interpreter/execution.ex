defmodule ExWasm.Interpreter.Execution do
  alias ExWasm.Interpreter.Embedding

  defstruct [:code, :param_types, :result_type, :globals, :locals, :embedding, :stack, :pc, :initialized]

  def new(code, globals, local_types, param_types, result_type) do
    locals = Enum.map(local_types, fn type -> {nil, type} end)
    {:ok, %__MODULE__{code: code, param_types: param_types, result_type: result_type, globals: globals, locals: locals, stack: [], pc: 0, initialized: false}}
  end

  def initialize(%__MODULE__{locals: locals} = state, %Embedding{} = embedding, params \\ []) do
    with {:params, :ok} <- {:params, check_params(params, state.param_types)} do
      {:ok, %__MODULE__{state | locals: params ++ locals, embedding: embedding, stack: [], pc: 0, initialized: true}}
    else
      {:params, error} -> error
    end
  end

  def step(%__MODULE__{code: code, pc: pc} = state) do
    with {:pc_in_range, true} <- {:pc_in_range, state.pc < length(code)},
         opcode = Enum.at(code, pc),
         {:opcode, {:ok, next_state}} <- {:opcode, opcode(state, opcode)} do
      {:step, next_state}
    else
      {:pc_in_range, :false} -> {:result, state}
      {:opcode, error} -> error
      other -> {:error, other}
    end
  end

  def execute(%__MODULE__{} = state) do
    case step(state) do
      {:result, new_state} ->{:ok, new_state}
      {:step, new_state} -> execute(new_state)
      error -> error
    end
  end

  def result(%__MODULE__{result_type: nil}), do: {:ok, nil}
  def result(%__MODULE__{result_type: type, stack: stack}) do
    with {:value, [value|_rest]} <- {:value, stack},
         {:type_match, true} <- {:type_match, type_match?(type, value)} do
          {:ok, value}
    else
      {:value, _stack} -> {:error, "Malformed stack expecting at least one item to be used as result"}
      {:type_match, false} -> {:error, "Result has wrong type"}
    end
  end

  defp check_params(params, param_types) do
    with {:length, true} <- {:length, equal_length?(param_types, params)},
         {:types, true} <- {:types, types_match?(param_types, params)} do
      :ok
    else
      {:length, false} -> {:error, "Wrong parameter length"}
      {:types, false} -> {:error, "Wrong parameter types"}
    end

  end

  defp equal_length?(list0, list1), do: length(list0) == length(list1)

  defp types_match?(types, values) do
    Enum.zip(values, types)
    |> Enum.map(fn {value, expected_type} -> type_match?(expected_type, value) end)
    |> Enum.all?()
  end

  defp type_match?(type, {type, _value}) when is_atom(type), do: true
  defp type_match?(_type, _value), do: false

  defp push(%__MODULE__{stack: stack} = instance, type, value) do
    %__MODULE__{instance | stack: [{type, value} | stack]}
  end

  defp pop(%__MODULE__{stack: []}), do: {:error, "Stack is empty"}
  defp pop(%__MODULE__{stack: [{_type, _value} = item | stack]} = instance) do
    {:ok, {item, %__MODULE__{instance | stack: stack}}}
  end

  # variables
  defp get_global(%__MODULE__{globals: globals} = instance, index) do
    case Enum.at(globals, index) do
      nil -> {:error, "global with index #{index} not found"}
      {:embedding, module, name} -> Embedding.get_variable(instance.embedding, module, name)
      {{type, _vartype}, value} -> {:ok, {type, value}}
    end
  end

  defp set_global(%__MODULE__{globals: globals} = instance, index, type, value) do
    with {{^type, :var}, global} <- Enum.at(globals, index, {:error, "global with index #{index} not found"}) do
      case global do
        {:embedding, _module, _name} ->
          IO.puts("===========NOT IMPLEMNTED=================")
          instance |> ok()
        _old_value ->
          new_globals = List.replace_at(globals, index, {{type, :var}, value})
          %__MODULE__{instance | globals: new_globals}
          |> ok()
      end
     else
      {{_type, :const}, _value} -> {:error, "global at intex #{index} ist constant"}
      {{actual_type, :var}, _value} -> {:error, "global at intex #{index} has wrong type #{actual_type} expected #{type}"}
    end
  end

  defp get_var(%__MODULE__{} = instance, :global, index), do: get_global(instance, index)
  defp get_var(%__MODULE__{} = instance, :local, index) do
    case Enum.at(instance.locals, index) do
      nil -> {:error, "local var with index #{index} does not exist"}
      value -> {:ok, value}
    end
  end

  defp set_var(%__MODULE__{} = instance, :global, index, type, value), do: set_global(instance, index, type, value)
  defp set_var(%__MODULE__{locals: locals} = instance, :local, index, type, value) do
    with {_current_value, ^type} <- Enum.at(locals, index),
         {:type, true} <- {:type, type_match?(type, {type, value})} do
      new_locals = List.replace_at(locals, index, {type, value})
      {:ok, %__MODULE__{instance | locals: new_locals}}
    else
      nil -> {:error, "Local var with index #{index} does not exist"}
      {:type, false} -> {:error, "Wrong type"}
    end
  end

  # helpers

  defp ok(%__MODULE__{} = instance), do: {:ok, instance}

  defp increment_pc(%__MODULE__{} = instance), do: %__MODULE__{instance | pc: instance.pc+1}

  # opcodes

  for var_type <- [:local, :global]  do
    set_opcode = String.to_atom("#{var_type}_set")
    defp opcode(%__MODULE__{} = instance, {unquote(set_opcode), index}) do
      with {:ok, {{type, value}, instance}} <- pop(instance),
           {:ok, instance} <- set_var(instance, unquote(var_type), index, type, value) do
        increment_pc(instance)
        |> ok()
      end
    end

    get_opcode = String.to_atom("#{var_type}_get")
    defp opcode(%__MODULE__{} = instance, {unquote(get_opcode), index}) do
      with {:ok, {type, value}} <- get_var(instance, unquote(var_type), index) do
        push(instance, type, value)
        |> increment_pc()
        |> ok()
      else
        other -> {:error, other}
      end
    end
  end

  defp opcode(%__MODULE__{} = instance, {:local_tee, index}) do
    with {:ok, {{type, value}, instance}} <- pop(instance),
         {:ok, instance} <- set_var(instance, :local, index, type, value) do
      push(instance, type, value)
      |> increment_pc()
      |> ok()
    end
  end

  defp opcode(%__MODULE__{} = instance, :i32_add) do
    with {:ok, {{lhs_type, lhs_value}, instance}} <- pop(instance),
         {:ok, {{rhs_type, rhs_value}, instance}} <- pop(instance),
         {:type_match, true} <- {:type_match, lhs_type == rhs_type} do
      push(instance, lhs_type, lhs_value + rhs_value)
      |> increment_pc()
      |> ok()
    else
      {:type_match, false} -> {:error, "cannot add values with different types"}
      error -> error
    end
  end

  defp opcode(%__MODULE__{} = instance, :nop), do: ok(instance)

  defp opcode(%__MODULE__{}, any), do: {:error, "Opcode #{any} not implemented yet"}

end
