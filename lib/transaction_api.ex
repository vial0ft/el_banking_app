defmodule ElBankingApp.TransactionApi do
  require Logger

  @registry ElBankingApp.Supervisor.transaction_registry()

  @spec new_transaction(list_of_pids :: list()) :: {:error, String} | {:ok, integer}
  def new_transaction(list_of_pids) when length(list_of_pids) > 0 do
    tr_id = :erlang.unique_integer([:positive])
    set_of_pids = Enum.uniq(list_of_pids)

    with {:ok, pid} <- Registry.register(@registry, tr_id, set_of_pids),
         {:ok, tr_id} <- send_all_with_fallback({tr_id, {:transaction_init, tr_id}}, set_of_pids) do
      {:ok, tr_id, pid}
    else
      err -> err
    end
  end

  def add_change(tr_id, pid, action) do
    with {:ok, pids} <- get_pids(tr_id),
         true <- Enum.member?(pids, pid),
         result <- GenServer.call(pid, {:transaction_add, {tr_id, action}}) do
      result
    else
      {:error, _} = err -> err
      :error -> {:error, "#{inspect(pid)} isn't part of transaction #{tr_id}"}
      err -> err
    end
  end

  def commit(tr_id) do
    with {:ok, pids} <- get_pids(tr_id),
    {:ok, _} <- send_all_with_fallback({tr_id, {:transaction_commit, tr_id}}, pids),
    {:ok, _} <- send_all_with_fallback({tr_id, {:transaction_close, tr_id}}, pids) do
      {:ok, tr_id}
    end
  end

  def close(tr_id) do
    case get_pids(tr_id) do
      {:error, _} = err -> err
      {:ok, pids} -> send_all_with_fallback({tr_id, {:transaction_close, tr_id}}, pids)
    end
  end

  @spec reject(any, any) :: {:error, any} | {:ok, {:transaction_rollback, any, any}}
  def reject(tr_id, reason) do
    Logger.info("reject #{reason} by #{tr_id}}")
    result =
      case get_pids(tr_id) do
        {:error, _} = err -> err
        {:ok, pids} ->
          Logger.info("#{inspect(pids)}")
          send_fallback({tr_id, reason}, pids)
      end

    Registry.unregister(@registry, tr_id)
    result
  end

  defp get_pids(tr_id) do
    case Registry.lookup(@registry, tr_id) do
      [] -> {:error, "Transation #{tr_id} isn't exist"}
      [{_pid, []}] -> {:error, "There are no any pid in transaction #{tr_id}"}
      [{_pid, tr_pids}] -> {:ok, tr_pids}
    end
  end

  defp send_all_with_fallback({tr_id, _}, []), do: {:ok, tr_id}

  defp send_all_with_fallback({tr_id, msg} = id_msg, [pid | rest]) do
    Logger.info("send #{inspect(msg)} by #{tr_id} for  #{inspect(pid)}")
    case GenServer.call(pid, msg) do
      {:error, reason} -> reject(tr_id, reason)
      _ -> send_all_with_fallback(id_msg, rest)
    end
  end

  defp send_fallback({tr_id, reason}, []), do: {:ok, {:transaction_rollback, tr_id, reason}}

  defp send_fallback(tr_id_reason, [pid | rest]) do
    case GenServer.call(pid, {:transaction_rollback, tr_id_reason}) do
      {:error, _} = fallback_error -> fallback_error
      _ -> send_fallback(tr_id_reason, rest)
    end
  end
end
