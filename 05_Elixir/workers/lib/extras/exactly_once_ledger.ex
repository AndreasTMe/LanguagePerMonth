defmodule Extras.ExactlyOnceLedger do
  @table :data

  # Create named ETS table
  def start do
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ok
  end

  def try_add(id) when is_integer(id) do
    :ets.insert_new(@table, {id})
  end
end
