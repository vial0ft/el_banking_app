defmodule ElBankingApp.TransactionManager do
  @table_name :transactions

  def new_transaction() do
    tr_id = DateTime.utc_now() |> DateTime.to_string()

    case :ets.insert_new(@table_name, {tr_id, {[], []}}) do
      false -> {:error, "Can't create transaction"}
      _ -> {:ok, tr_id}
    end
  end

  def add_action_for_transaction(tr_id, {_from, _to, {_action, _currency, _amount}} = tr_action) do
    case :ets.match_object(@table_name, {tr_id, {:_, :_}}) do
      [^tr_id, {actions_list, fb_actions}] ->
        case build_action(tr_action) do
          {:error, _} = error ->
            error

          add_action_to_tr ->
            :ets.insert(@table_name, {tr_id, {[add_action_to_tr | actions_list], fb_actions}})
            {:ok, tr_action}
        end

      _ ->
        {:error, "Not found transaction by id: #{tr_id}"}
    end
  end

  def do_transaction(tr_id) do
    case :ets.match_object(@table_name, {tr_id, {:_, :_}}) do
      [^tr_id, {actions_list, fb_actions}] ->
        case execute_transaction(actions_list, fb_actions, tr_id) do
          {:ok, _} = ok_result ->
            :ets.delete(@table_name, tr_id)
            ok_result

          {:error, _} = err ->
            err
        end

      _ ->
        {:error, "Not found transaction by id: #{tr_id}"}
    end
  end

  defp build_action({from, to, {action, currency, amount}}) do
    case negate_action(action) do
      {:error, _} = error -> error
      deny_action -> [{to, {deny_action, currency, amount}}, {from, {action, currency, amount}}]
    end
  end

  defp execute_transaction([], _, tr_id), do: {:ok, tr_id}

  defp execute_transaction([{purse, {action, currency, amount}} | rest], fallback_list, tr_id) do
    case GenServer.call(purse, {action, currency, amount}) do
      {:ok, _} ->
        execute_transaction(
          rest,
          [
            {purse, {negate_action(action), currency, amount}} | fallback_list
          ],
          tr_id
        )

      {:error, _} = error ->
        execute_fallbacks(fallback_list, error, tr_id)
    end
  end

  defp execute_fallbacks([], {:error, reason}, tr_id),
    do: {:error, "Transaction #{tr_id} was rejected with fallback, reason: #{reason}"}

  defp execute_fallbacks(
         [{purse, {fallback_action, currency, amount}} | rest],
         {:error, tr_reject_reason} = err,
         tr_id
       ) do
    case GenServer.call(purse, {fallback_action, currency, amount}) do
      {:ok, _} ->
        execute_fallbacks(rest, err, tr_id)

      {:error, why} ->
        {:error,
         "Can't do fallback because : #{why}. Reason of #{tr_id} transaction rejection : #{tr_reject_reason}"}
    end
  end

  defp negate_action(action) do
    case action do
      :deposit -> :withdraw
      :withdraw -> :deposit
      _ -> {:error, "Cant build fallback"}
    end
  end
end
