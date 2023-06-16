defmodule ExWasm.Parser do
  alias ExWasm.Section
  import ExWasm.Parser.{BasicTypes, Opcode}

  def parse(ctx) do
    %{version: 1, sections: sections} = ctx
    |> parse_bytes(4, &magic_bytes/2)
    |> parse_bytes(4, &version/2)
    |> parse_sections()

    sections
  end

  defp magic_bytes(ctx, <<0, "a", "s", "m">>) do
    {:ok, ctx}
  end
  defp magic_bytes(_ctx, m), do: {:error, "Wrong magic bytes. Got: #{inspect(m)}"}

  defp version(ctx, <<version::little-32>>) do
    {:ok, %{ctx | version: version}}
  end

  defp parse_sections(ctx) do
    case parse_bytes(ctx, 1, &section/2) do
      {:eof, new_ctx} -> new_ctx
      {:error, _error} = error -> error
      new_ctx when is_map(new_ctx) -> parse_sections(new_ctx)
    end
  end

  defp section(ctx, <<type::integer-size(8)>>) do
    size = parse_uint(ctx)
    section_type = section_atom(type)

    section = case section_type do
      :type -> vector(ctx, &func_type/1) |> Section.new_type_section()
      :import -> vector(ctx, &mimport/1) |> Section.new_import_section()
      :function -> vector(ctx, fn ctx -> {:ok, parse_uint(ctx)} end) |> Section.Function.new()
      :table -> vector(ctx, &tabletype/1) |> Section.new_table_section()
      :memory -> vector(ctx, &mem/1) |> Section.Memory.new()
      :global -> vector(ctx, &global/1) |> Section.Global.new()
      :export -> vector(ctx, &export/1) |> Section.Export.new()
      :start -> parse_uint(ctx) |> Section.Start.new()
      :code -> vector(ctx, &code/1) |> Section.Code.new()
      :data -> read_bytes(ctx, size) |> Section.Data.new()
      _ -> data = read_bytes(ctx, size)
        Section.new(section_type, data)
    end
    {:ok, %{ctx | sections: [section | ctx.sections]}}
  end

  defp section_atom(type) do
    case type do
      0 -> :custom
      1 -> :type
      2 -> :import
      3 -> :function
      4 -> :table
      5 -> :memory
      6 -> :global
      7 -> :export
      8 -> :start
      9 -> :element
      10 -> :code
      11 -> :data
      12 -> :data_count
    end
  end


  defp mimport(ctx) do
    module = name(ctx)
    name = name(ctx)
    {:ok, importdesc} = importdesc(ctx)
    {:ok, {{module, name}, importdesc}}
  end

  defp importdesc(ctx) do
    importdesc = case read_bytes(ctx, 1) do
      <<0>> -> {:typeindex, typeindex(ctx)}
      <<1>> -> {:table, tabletype(ctx)}
      <<2>> ->
        {:ok, limit} = limit(ctx)
        {:memory, limit}
      <<3>> -> {:global, globaltype(ctx)}
    end
    {:ok, importdesc}
  end

  defp reftype(ctx) do
    {:ok, reftype} = char(ctx)
    case reftype do
      <<0x6f>> -> {:ok, :externref}
      <<0x70>> -> {:ok, :funcref}
      other -> {:error, "expected reftype 0x6f or 0x70 got #{inspect(other, binaries: :as_binaries, base: :hex)}"}
    end
  end

  defp globaltype(ctx) do
    {:ok, valtype} = value_type(ctx)
    {:ok, mut} = muttype(ctx)
    {valtype, mut}
  end

  defp muttype(ctx) do
    with {:ok, t} <- char(ctx) do
      case t do
        <<0>> ->  {:ok, :const}
        <<1>> ->  {:ok, :var}
        other -> {:error, "expected muttype 0x00 or 0x01 got #{inspect(other, binaries: :as_binaries, base: :hex)}"}
      end
    end
  end

  defp limit(ctx) do
    {:ok, type} = char(ctx)
    min = parse_uint(ctx)
    case type do
      <<0>> -> {:ok, {min, :infinity}}
      <<1>> -> {:ok, {min, parse_uint(ctx)}}
      other -> {:error, "expected limit type 0x00 or 0x01 got #{inspect(other, binaries: :as_binaries, base: :hex)}"}
    end
  end

  defp tabletype(ctx) do
    {:ok, reftype} = reftype(ctx)
    {:ok, limit} = limit(ctx)
    {:ok, {reftype, limit}}
  end

  defp expr(ctx) do
    parse_opcodes(ctx)
  end

  defp global(ctx) do
    globaltype = globaltype(ctx)
    expr = expr(ctx)
    {:ok, {globaltype, expr}}
  end

  defp export(ctx) do
    name = name(ctx)
    exportdef = exportdef(ctx)
    {:ok, {name, exportdef}}
  end

  defp exportdef(ctx) do
    with {:ok, <<type>>} <- char(ctx) do
      idt = case type do
         0 ->:funcidx
         1 ->:tableidx
         2 ->:memidx
         3 ->:globalidx
      end
      idx = parse_uint(ctx)
      {idt, idx}
    end
  end

  defp mem(ctx) do
    limit(ctx)
  end

  defp code(ctx) do
    parse_uint(ctx)
    func = func(ctx)
    {:ok, func}
  end

  defp func(ctx) do
   locals = vector(ctx, &locale/1)
   expr = expr(ctx)
   {locals, expr}
  end

  defp locale(ctx) do
    parse_uint(ctx)
    {:ok, value_type} = value_type(ctx)
    {:ok, value_type}
  end
end
