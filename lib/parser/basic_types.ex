defmodule ExWasm.Parser.BasicTypes do
  alias ExWasm.Reader

  def read_bytes(ctx, num) do
    Reader.pop_bytes(ctx[:reader], num)
  end

  def push_bytes(ctx, bytes) do
    Reader.push_bytes(ctx[:reader], bytes)
  end

  def parse_bytes(ctx, num, fun) do
    with bytes when is_binary(bytes) <- read_bytes(ctx, num),
         {:ok, ctx} <- fun.(ctx, bytes)
      do
        ctx
      else
        :eof -> {:eof, ctx}
        {:error, _error} = error -> IO.inspect(error)
    end
  end

  def name(ctx) do
    vector(ctx, &char/1) |> to_string()
  end

  def char(ctx) do
    case read_bytes(ctx, 1) do
      :eof -> {:error, :eof}
      other -> {:ok, other}
    end
  end

  def vector(ctx, fun) do
    count = parse_uint(ctx)
    vector_element(ctx, fun, count)
  end

  defp vector_element(ctx, fun, count, result \\ [])
  defp vector_element(_ctx, _fun, 0, result), do: result |> Enum.reverse()
  defp vector_element(ctx, fun, count, result) do
    {:ok, element} = fun.(ctx)
    vector_element(ctx, fun, count-1, [element | result])
  end

  def parse_uint(ctx) do
    {:ok, char} = char(ctx)
    parse_uint({ctx, <<>>}, char)
  end

  defp parse_uint({_ctx, binary}, <<0::1, n::7>>) do
    size = bit_size(binary)
    binary2 = <<n::integer-size(7), binary::bitstring>>
    size = size+7
    <<n::integer-size(size)>> = binary2
    n
  end

  defp parse_uint(_ctx, <<0::1, n::7>>) do
    n
  end

  defp parse_uint({inner, _binary} = ctx, <<1::1, _::7>>) do
    {:ok, char} = char(inner)
    parse_uint(ctx, char)
  end

  def func_type(ctx) do
    {:ok, char} = char(ctx)
    case char do
      <<0x60>> ->
        params =  result_type(ctx)
        return = case result_type(ctx) do
          [type] -> type
          _other -> nil
        end
        {:ok, {params, return}}
      other -> {:error, "expected 0x60 got #{inspect(other, binaries: :as_binaries, base: :hex)}"}
    end
  end

  def result_type(ctx) do
    vector(ctx, &value_type/1)
  end

  def value_type(ctx) do
    {:ok, char} = char(ctx)
    pvalue_type(char)
  end

  defp pvalue_type(byte) do
    case byte do
      <<0x6F>> -> {:ok, :externref}
      <<0x70>> -> {:ok, :funcref}
      <<0x7B>> -> {:ok, :vectype}
      <<0x7C>> -> {:ok, :f64}
      <<0x7D>> -> {:ok, :f32}
      <<0x7E>> -> {:ok, :i64}
      <<0x7F>> -> {:ok, :i32}
      other -> {:unknown, "unknown value type got #{inspect(other, binaries: :as_binaries, base: :hex)}"}
    end
  end

  def typeindex(ctx) do
    parse_uint(ctx)
  end

  def tableindex(ctx) do
    parse_uint(ctx)
  end

  def functionindex(ctx) do
    parse_uint(ctx)
  end

  def localindex(ctx) do
    parse_uint(ctx)
  end

  def globalindex(ctx) do
    parse_uint(ctx)
  end

  def labelindex(ctx) do
    parse_uint(ctx)
  end
end
