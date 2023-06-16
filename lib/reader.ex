defmodule ExWasm.Reader do
  use GenServer

  def start_link(file) do
    GenServer.start_link(__MODULE__, file)
  end

  def pop_bytes(pid, num) do
    GenServer.call(pid, {:pop_bytes, num})
  end

  def push_bytes(pid, bytes) do
    GenServer.call(pid, {:push_bytes, bytes})
  end

  @impl true
  def init(file) do
    {:ok, {file, <<>>}}
  end

  @impl true
  def handle_call({:pop_bytes, num}, _from, {file, <<>>} = state) do
    byte = IO.binread(file, num)
    {:reply, byte, state}
  end

  @impl true
  def handle_call({:pop_bytes, num}, _from, {file, buffer}) do
    buffer_size = byte_size(buffer)
    case num <= buffer_size do
      true ->
        <<read::binary-size(num), new_buffer::binary>> = buffer
        {:reply, read, {file, new_buffer}}
      false ->
        bytes = IO.binread(file, num-buffer_size)
        {:reply, buffer <> bytes, {file, <<>>}}
    end
  end

  @impl true
  def handle_call({:push_bytes, bytes}, _from, {file, buffer}) do
    {:reply, :ok, {file, bytes <> buffer}}
  end
end
