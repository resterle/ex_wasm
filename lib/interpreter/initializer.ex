defmodule ExWasm.Interpreter.Initializer do
  alias ExWasm.Section
  alias ExWasm.Interpreter

  def create_instance(section_map, %Interpreter.Embedding{} = embedding) do
    function_instance = function_instance(section_map)

    start_index = case get_section(section_map, Section.Start) do
      %Section.Start{start_index: index} -> index
    end

    %ExWasm.Interpreter{
      embedding: embedding,
      function_instance: function_instance,
      exports: exports(section_map, function_instance),
      start_index: start_index,
      globals: globals(section_map, embedding),
      memory: []}
  end

  defp function_instance(section_map) do
    with %Section.Type{} = types <- get_section(section_map, Section.Type) do
      imported = case get_section(section_map, Section.Import) do
        %Section.Import{} = import_section ->
          Section.Import.functions(import_section)
          |> Enum.map(fn {name, {:typeindex, index}} ->
            type = Section.Type.get_type(types, index)
            {:external, type, name}
          end)
        _other -> []
      end

      local = case get_section(section_map, Section.Code) do
        %Section.Code{code: code} ->
          %Section.Function{function_indexes: indexes} = get_section(section_map, Section.Function)
          Enum.zip(indexes, code)
          |> Enum.map(fn {index, func} ->
            type = Section.Type.get_type(types, index)
            {:internal, type, func}
          end)
        _other -> []
      end

      imported ++ local
    else
      _other -> []
    end
  end

  defp globals(section_map, embedding) do

    imported = with %Section.Import{} = imports <- get_section(section_map, Section.Import),
         globals <- Section.Import.globals(imports) do
      Enum.map(globals, fn {{module, name}, {:global, {type, var_type}}} ->
        {{type, var_type}, {:embedding, module, name}}
      end)
    else
      nil -> []
    end

    globals = case get_section(section_map, Section.Global) do
      %Section.Global{globals: globals} ->
        Enum.map(globals, fn
          {{type, var_type}, [{:const, type, value}]} -> {{type, var_type}, value}
          {{type, var_type}, [global_get: index]} ->
            {{^type, _var_type}, {:embedding, module, name}} = Enum.at(imported, index)
            {:ok, value} = Interpreter.Embedding.get_variable(embedding, module, name)
            {{type, var_type}, value}
          other -> other
        end)
      _other -> []
    end

    imported ++ globals
  end

  defp section_export_to_export({name, {index_type, index}}, function_instance) do
    type = index_type_to_export_type(index_type)
    case type do
      :function ->
        {:internal, {params, return}, _code} = Enum.at(function_instance, index)
        %{name: name, type: type, index: index, params: params, return: return}
      _other -> %{name: name, type: type, index: index}
    end
  end

  defp index_type_to_export_type(index_type) do
    case index_type do
      :funcidx -> :function
      :tableidx -> :table
      :memidx -> :memory
      :globalidx -> :global
    end
  end

  defp exports(section_map, function_instance) do
    case get_section(section_map, Section.Export) do
       %Section.Export{exports: exports} ->
        Enum.map(exports, &section_export_to_export(&1, function_instance))
        |> Enum.reduce(%{}, fn %{name: name} = elem, acc -> Map.put_new(acc, name, elem) end)
        _other -> []
    end
  end


  defp get_section(section_map, section_mod) do
    Map.get(section_map, section_mod)
  end

end
