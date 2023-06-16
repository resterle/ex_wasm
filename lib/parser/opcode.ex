defmodule ExWasm.Parser.Opcode do
  import ExWasm.Parser.BasicTypes

  def parse_opcodes(ctx) do
    opcodes({ctx, [], 0})
  end

  defp opcodes({ctx, _opcodes, _b} = ictx) do
    {:ok, <<opcode>>} = char(ctx)
    opcode(ictx, opcode)
  end

  defp opcode({ctx, opcodes, b}, 0x00) do
    opcodes({ctx, [:noreach | opcodes], b+1})
  end

  defp opcode({ctx, opcodes, b}, 0x01) do
    opcodes({ctx, [:nop | opcodes], b+1})
  end

  # BLOCK
  defp opcode({ctx, opcodes, b}, 0x02) do
    type = blocktype(ctx)
    opcodes({ctx, [{:block, type} | opcodes], b+1})
  end

  # LOOP
  defp opcode({ctx, opcodes, b}, 0x03) do
    opcodes({ctx, [{:loop, blocktype(ctx)} | opcodes], b+1})
  end

  # IF
  defp opcode({ctx, opcodes, b}, 0x04) do
    opcodes({ctx, [{:if, blocktype(ctx)} | opcodes], b+1})
  end

  # ELSE
  defp opcode({ctx, opcodes, b}, 0x05) do
    opcodes({ctx, [:else | opcodes], b+1})
  end

  # END
  defp opcode({_ctx, opcodes, 0}, 0x0B), do: opcodes |> Enum.reverse()

  defp opcode({ctx, opcodes, b}, 0x0B) do
    opcodes({ctx, [:end | opcodes], b-1})
  end

  # BR
  defp opcode({ctx, opcodes, b}, 0x0c) do
    opcodes({ctx, [{:br_l, labelindex(ctx)} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x0d) do
    opcodes({ctx, [{:br_if_l, labelindex(ctx)} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x0e) do
    iv = vector(ctx, &labelindex/1)
    opcodes({ctx, [{:br_table, iv} | opcodes], b})
  end

  # RETURN
  defp opcode({ctx, opcodes, b}, 0x0f) do
    opcodes({ctx, [:return | opcodes], b})
  end

  #CALL
  defp opcode({ctx, opcodes, b}, 0x10) do
    opcodes({ctx, [{:call, functionindex(ctx)} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x11) do
    typeindex = typeindex(ctx)
    tableindex = tableindex(ctx)
    opcodes({ctx, [{:call_indirect, typeindex, tableindex} | opcodes], b})
  end

  # Parametric instructions
  defp opcode({ctx, opcodes, b}, 0x1a) do
    opcodes({ctx, [:drop | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x1b) do
    opcodes({ctx, [:select | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x1c) do
    opcodes({ctx, [{:select, value_type(read_bytes(ctx, 1))} | opcodes], b})
  end

  # Variable instructions
  defp opcode({ctx, opcodes, b}, 0x20) do
    opcodes({ctx, [{:local_get, localindex(ctx)} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x21) do
    opcodes({ctx, [{:local_set, localindex(ctx)} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x22) do
    opcodes({ctx, [{:local_tee, localindex(ctx)} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x23) do
    opcodes({ctx, [{:global_get, globalindex(ctx)} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x24) do
    opcodes({ctx, [{:global_set, globalindex(ctx)} | opcodes], b})
  end

  # Const
  defp opcode({ctx, opcodes, b}, 0x41) do
    v = parse_uint(ctx)
    opcodes({ctx, [{:const, :i32, v} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x42) do
    v = parse_uint(ctx)
    opcodes({ctx, [{:const, :i64, v} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x43) do
    throw({:not_implemented, "const f32"})
    opcodes({ctx, [{:const, :f32} | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x44) do
    throw({:not_implemented, "const f64"})
    opcodes({ctx, [{:const, :f64} | opcodes], b})
  end

  # Memory
  [
    {0x28, :load_i32},
    {0x29, :load_i64},
    {0x2a, :load_f32},
    {0x2b, :load_f64},
    {0x2c, :load_i32_8s},
    {0x2d, :load_i32_8u},
    {0x2e, :load_i32_16s},
    {0x2f, :load_i32_16u},
    {0x30, :load_i64_8s},
    {0x31, :load_i64_8u},
    {0x32, :load_i64_16s},
    {0x33, :load_i64_16u},
    {0x34, :load_i64_32s},
    {0x35, :load_i64_32u},
    {0x36, :store_i32},
    {0x37, :store_i64},
    {0x38, :store_f32},
    {0x39, :store_f64},
    {0x3A, :store_i32_8},
    {0x3B, :store_i32_16},
    {0x3C, :store_i64_8},
    {0x3D, :store_i64_16},
    {0x3E, :store_i64_32}
  ]
  |> Enum.map(fn {opcode, m} ->
      defp opcode({ctx, opcodes, b}, unquote(opcode)) do
        instruction = meminstruction(unquote(m), ctx)
        opcodes({ctx, [instruction | opcodes], b})
      end
  end)

  defp opcode({ctx, opcodes, b}, 0x3f) do
    <<0>> = read_bytes(ctx, 1)
    opcodes({ctx, [:memory_size | opcodes], b})
  end

  defp opcode({ctx, opcodes, b}, 0x40) do
    opcodes({ctx, [:memory_grow | opcodes], b})
  end

  # IDO
  [
    {0x45, :i32_eqz},
    {0x46, :i32_eq},
    {0x47, :i32_ne},
    {0x48, :i32_lt_s},
    {0x49, :i32_lt_u},
    {0x4A, :i32_gt_s},
    {0x4B, :i32_gt_u},
    {0x4C, :i32_le_s},
    {0x4D, :i32_le_u},
    {0x4E, :i32_ge_s},
    {0x4F, :i32_ge_u},
    {0x50, :i64_eqz},
    {0x51, :i64_eq},
    {0x52, :i64_ne},
    {0x53, :i64_lt_s},
    {0x54, :i64_lt_u},
    {0x55, :i64_gt_s},
    {0x56, :i64_gt_u},
    {0x57, :i64_le_s},
    {0x58, :i64_le_u},
    {0x59, :i64_ge_s},
    {0x5A, :i64_ge_u},
    {0x5B, :f32_eq},
    {0x5C, :f32_ne},
    {0x5D, :f32_lt},
    {0x5E, :f32_gt},
    {0x5F, :f32_le},
    {0x60, :f32_ge},
    {0x61, :f64_eq},
    {0x62, :f64_ne},
    {0x63, :f64_lt},
    {0x64, :f64_gt},
    {0x65, :f64_le},
    {0x66, :f64_ge},
    {0x67, :i32_clz},
    {0x68, :i32_ctz},
    {0x69, :i32_popcnt},
    {0x6A, :i32_add},
    {0x6B, :i32_sub},
    {0x6C, :i32_mul},
    {0x6D, :i32_div_s},
    {0x6E, :i32_div_u},
    {0x6F, :i32_rem_s},
    {0x70, :i32_rem_u},
    {0x71, :i32_and},
    {0x72, :i32_or},
    {0x73, :i32_xor},
    {0x74, :i32_shl},
    {0x75, :i32_shr_s},
    {0x76, :i32_shr_u},
    {0x77, :i32_rotl},
    {0x78, :i32_rotr}
  ]
  |> Enum.map(fn {opcode, m} ->
      defp opcode({ctx, opcodes, b}, unquote(opcode)) do
        opcodes({ctx, [unquote(m) | opcodes], b})
      end
  end)

  defp opcode({_ctx, c, _a}, any) do
    Enum.reverse(c) |> IO.inspect(label: "PARSED", base: :hex, limit: :infinity)
    throw("NOT IMPLEMENTED #{inspect(any, binaries: :as_binaries, base: :hex)}")
  end

  defp blocktype(ctx) do
    t = with {:ok, type} <- char(ctx) do
      case type do
        <<0x40>> -> :empty
        _other ->
          with {:unknown, _} <- value_type(type) do
            :ok = push_bytes(ctx, type)
            index = parse_uint(ctx)
            {:type_index, index}
          else
            {:ok, value_type} -> {:value_type, value_type}
          end
      end
    end
    t
  end

  defp meminstruction(type, ctx), do: {type, memarg(ctx)}

  defp memarg(ctx) do
    align = parse_uint(ctx)
    offset = parse_uint(ctx)
    {align, offset}
  end
end
