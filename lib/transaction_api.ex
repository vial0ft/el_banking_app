defmodule ElBankingApp.TransactionApi do
  use GenServer
  require Logger

  @transaction_table :transactions

  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    :ets.new(@transaction_table, [:set, :protected, :named_table])
    {:ok, state}
  end

  @spec new_transaction(list_of_pids :: list()) :: {:error, String} | {:ok, integer}
  def new_transaction(list_of_pids) when length(list_of_pids) > 0 do
    tr_id = :erlang.unique_integer([:positive])
    set_of_pids = Enum.uniq(list_of_pids)

    case :ets.insert_new(@transaction_table, {tr_id, set_of_pids}) do
      false -> {:error, "Can't init transaction"}
      _ -> send_all_with_fallback({tr_id, {:transaction_init, tr_id}}, set_of_pids)
    end
  end

  def add_change(tr_id, pid, action) do
    case GenServer.call(pid, {:transaction_add, {tr_id, action}}) do
      {:error, why} -> reject(tr_id, why)
      {:ok, _} = ok_like -> ok_like
    end
  end

  def commit(tr_id) do
    case get_pids(tr_id) do
      {:error, _} = err -> err
      {:ok, pids} -> send_all_with_fallback({tr_id, {:transaction_commit, {tr_id}}}, pids)
    end
  end

  def reject(tr_id, reason) do
    result = case get_pids(tr_id) do
      {:error, _} = err -> err
      {:ok, pids} -> send_fallback({tr_id, reason}, pids)
    end
    :ets.delete_object(@transaction_table, tr_id)
    result
  end

  defp get_pids(tr_id) do
    case :ets.match_object(@transaction_table, tr_id) do
      [] -> {:error, "Transation #{tr_id} isn't exist"}
      [{^tr_id, []}] -> {:error, "There are no any pid in transaction #{tr_id}"}
      [{^tr_id, pids}] -> {:ok, pids}
    end
  end

  defp send_all_with_fallback({tr_id, _}, []), do: {:ok, tr_id}

  defp send_all_with_fallback({tr_id, msg} = id_msg, [pid | rest]) do
    case GenServer.call(pid, msg) do
      {:error, reason} -> reject(tr_id, reason)
      _ -> send_all_with_fallback(id_msg, rest)
    end
  end

  defp send_fallback({tr_id, reason}, []), do: {:ok, {:fallback, tr_id, reason}}

  defp send_fallback({tr_id, _} = id_reason, [pid | rest]) do
    case GenServer.call(pid, {:transaction_fallback, {tr_id}}) do
      {:error, _} = fallback_error -> fallback_error
      _ -> send_fallback(id_reason, rest)
    end
  end
end
