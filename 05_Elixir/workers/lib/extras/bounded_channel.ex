defmodule Extras.BoundedChannel do
  use GenServer

  def create(capacity) when capacity > 0 do
    {:ok, pid} = GenServer.start_link(__MODULE__, capacity)
    pid
  end

  def write(pid, item) do
    GenServer.call(pid, {:write, item}, :infinity)
  end

  def read(pid) do
    GenServer.call(pid, :read, :infinity)
  end

  def complete(pid) do
    GenServer.call(pid, :complete)
  end

  def init(capacity) do
    {:ok,
     %{
       capacity: capacity,
       queue: :queue.new(),
       closed: false,
       blocked_writer: nil,
       waiting_readers: :queue.new()
     }}
  end

  def handle_call({:write, item}, from, state) do
    cond do
      # Prevent writing when closed
      state.closed ->
        {:reply, {:error, :closed}, state}

      # If a reader is waiting, bypass queue and deliver directly
      not :queue.is_empty(state.waiting_readers) ->
        {{:value, reader}, readers} = :queue.out(state.waiting_readers)
        GenServer.reply(reader, {:ok, item})
        {:reply, :ok, %{state | waiting_readers: readers}}

      # If buffer has space -> enqueue
      :queue.len(state.queue) < state.capacity ->
        {:reply, :ok, %{state | queue: :queue.in(item, state.queue)}}

      # Buffer full -> block writer
      true ->
        {:noreply, %{state | blocked_writer: {from, item}}}
    end
  end

  def handle_call(:read, from, state) do
    cond do
      # If queue has items -> consume one
      not :queue.is_empty(state.queue) ->
        # Reader takes one item
        {{:value, item}, queue} = :queue.out(state.queue)

        # A slot is now free, so check whether writer was blocked
        state =
          if state.blocked_writer do
            {writer, blocked_item} = state.blocked_writer

            # Writer succeeds now
            GenServer.reply(writer, :ok)

            # Use newly freed slot
            %{state | queue: :queue.in(blocked_item, queue), blocked_writer: nil}
          else
            %{state | queue: queue}
          end

        {:reply, {:ok, item}, state}

      # If empty and closed -> signal completion
      state.closed ->
        {:reply, :closed, state}

      # Otherwise block reader
      true ->
        waiting_readers = :queue.in(from, state.waiting_readers)
        {:noreply, %{state | waiting_readers: waiting_readers}}
    end
  end

  def handle_call(:complete, _from, state) do
    # Once closed:
    # - no more writes allowed
    # - wake all waiting readers

    # Notify all blocked readers that no more data is coming
    state.waiting_readers
    |> :queue.to_list()
    |> Enum.each(fn reader ->
      GenServer.reply(reader, :closed)
    end)

    {:reply, :ok, %{state | closed: true, waiting_readers: :queue.new()}}
  end
end
