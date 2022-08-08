defmodule ElBankingApp.Purse do
  use GenServer
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, name)
  end

  def init(name) do
    case :dets.open_file('/tmp/purse/#{name}', type: :set) do
      {:ok, ref} -> {:ok, {ref, {:transaction_state, nil, {[], []}}}}
      _ -> {:error, "Can't open purse with name #{name}"}
    end
  end

  def hadle_call(
        {:transaction_init, other_tr_id},
        _from,
        {_, {:transaction_state, _tr_id, _tr_state}} = state
      ) do
    {:reply, {:error, "#{other_tr_id} can't start during other transaction"}, state}
  end

  def hadle_call(
        {:transaction_add, {other_tr_id, _}},
        _from,
        {_, {:transaction_state, _tr_id, _tr_state}} = state
      ) do
    {:reply, {:error, "#{other_tr_id} wrong transaction id"}, state}
  end

  def hadle_call(
        {:transaction_commit, other_tr_id},
        _from,
        {_, {:transaction_state, _tr_id, _tr_state}} = state
      ) do
    {:reply, {:error, "#{other_tr_id} can't commit during other transaction"}, state}
  end

  def handle_call({action, _, _}, _from, {_, {:transaction_state, tr_id, _tr_state}} = state)
      when not is_nil(tr_id) do
    {:reply, {:error, "#{action} blocked during transaction"}, state}
  end

  def handle_call({_, _, amount}, _from, state) when not is_number(amount) or amount <= 0 do
    {:reply, {:error, "amount must be positive number"}, state}
  end

  def handle_call({:deposit, currency, amount}, _from, {name, _} = state) do
    case :dets.match_object(name, {currency, :_}) do
      [{^currency, value} | _] -> {:reply, upsert(name, {currency, value + amount}), state}
      _ -> {:reply, upsert(name, {currency, amount}), state}
    end
  end

  def handle_call({:withdraw, currency, amount}, _from, {name, _} = state) do
    case :dets.match_object(name, {currency, :_}) do
      [{^currency, value} | _] when value < amount ->
        {:reply, {:error, "Not enough for withdraw"}, state}

      [{^currency, value} | _] ->
        {:reply, upsert(name, {currency, value - amount}), state}

      _ ->
        {:reply, {:error, "No currency #{currency}"}, state}
    end
  end

  def handle_call({:peek, currency}, _from, {name, _} = state) do
    result =
      case :dets.match_object(name, {currency, :_}) do
        [{^currency, value} | _] -> value
        _ -> 0
      end

    {:reply, {currency, result}, state}
  end

  def handle_call(:peek, _from, {name, _} = state) do
    {:reply, :dets.match_object(name, {:_, :_}), state}
  end

  # Transaction handlers
  def handle_call({:transaction_init, tr_id}, _from, {name, _}) do
    state = :dets.match_object(name, {:_, :_})
    {:reply, {:ok, tr_id}, {name, {:transaction_state, tr_id, {[], state}}}}
  end

  def handle_call(
        {:transaction_add, {tr_id, action}},
        _from,
        {name, {:transaction_state, tr_id, {tr_state, fallback_state}}}
      ) do
    {:reply, {:ok, action},
     {name, {:transaction_state, tr_id, {[action | tr_state], fallback_state}}}}
  end

  def handle_call(
        {:transaction_fallback, {tr_id}},
        _from,
        {name, {:transaction_state, tr_id, {_tr_state, fallback_state}}}
      ) do
    {:reply, {:ok, {:falback, tr_id, :dets.insert(name, fallback_state)}},
     {name, {:transaction_state, nil, {[], []}}}}
  end

  def handle_call(
        {:transaction_commit, {tr_id}},
        _from,
        {name, {:transaction_state, tr_id, {tr_state, fallback_state}}} = state
      ) do
    result =
      case apply_tr_actions(Enum.reverse(tr_state), state) do
        {:error, why} ->
          :dets.insert(name, fallback_state)
          {:fallback, tr_id, why}

        {:ok} ->
          {:ok, {tr_id}}
      end

    {:reply, result, {name, {:transaction_state, nil, {[], []}}}}
  end

  defp apply_tr_actions([], _state) do
    {:ok}
  end

  defp apply_tr_actions([action | rest], state) do
    case hadle_call(action, nil, state) do
      {:reply, {:error, why}, _st} -> {:error, why}
      _ok_like -> apply_tr_actions(rest, state)
    end
  end

  def handle_info(msg, state) do
    Logger.info(msg)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info("The server terminated because: #{reason}")
  end

  defp upsert(name, new_value) do
    case :dets.insert(name, new_value) do
      :ok -> new_value
      error -> error
    end
  end
end
