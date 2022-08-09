defmodule ElBankingApp.Purse do
  use GenServer
  require Logger

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(name) do
    GenServer.start_link(__MODULE__, name)
  end

  def init(name) do
    case :dets.open_file('/tmp/purse/#{name}', type: :set) do
      {:ok, ref} -> {:ok, {ref, {:transaction_state, nil, {%{}, []}}}}
      _ -> {:error, "Can't open purse with name #{name}"}
    end
  end

  def handle_call(
        {:transaction_init, other_tr_id},
        _from,
        {_, {:transaction_state, _tr_id, _tr_state}} = state
      ) do
    {:reply, {:error, "#{other_tr_id} can't start during other transaction"}, state}
  end

  def handle_call(
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

  def handle_call({:deposit, _currency, _amount} = action, _from, {name, _} = state) do
    {:reply, handle_change_actions(action, name), state}
  end

  def handle_call({:withdraw, _currency, _amount} = action, _from, {name, _} = state) do
    {:reply, handle_change_actions(action, name), state}
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
    {:reply, {:ok, tr_id}, {name, {:transaction_state, tr_id, {Map.new(state), state}}}}
  end

  def handle_call(
        {:transaction_add, {tr_id, action}},
        _from,
        {name, {:transaction_state, tr_id, {tr_state, fallback_state}}}
      ) do
    case do_with_state(tr_state, action) do
      {:ok, new_tr_state} ->
        {:reply, {:ok, action},
         {name, {:transaction_state, tr_id, {new_tr_state, fallback_state}}}}

      {:error, _} = err ->
        {:reply, err, {name, {:transaction_state, nil, {%{}, []}}}}
    end
  end

  def handle_call(
        {:transaction_add, {other_tr_id, _}},
        _from,
        {_, {:transaction_state, _tr_id, _tr_state}} = state
      ) do
    {:reply, {:error, "#{other_tr_id} wrong transaction id"}, state}
  end

  def handle_call(
        {:transaction_fallback, {tr_id}},
        _from,
        {name, {:transaction_state, tr_id, {_tr_state, fallback_state}}}
      ) do
    clean_state(name)
    upsert(name, fallback_state)
    {:reply, {:ok, {:fallback, tr_id}}, {name, {:transaction_state, nil, {%{}, []}}}}
  end

  def handle_call(
        {:transaction_commit, {tr_id}},
        _from,
        {name, {:transaction_state, tr_id, {tr_state, fallback_state}}}
      ) do
    case clean_state(name) do
      {:error, _} = err ->
        {:reply, {:error, err}, {name, {:transaction_state, nil, {%{}, []}}}}

      _ ->
        case upsert(name, Map.to_list(tr_state)) do
          {:ok, _} ->
            {:reply, {:ok}, {name, {:transaction_state, nil, {%{}, []}}}}

          _ ->
            case upsert(name, fallback_state) do
              {:ok, _} ->
                {:reply, {:error, "Can't commit transaction. Fallback"},
                 {name, {:transaction_state, nil, {%{}, []}}}}

              _ ->
                {:reply, {:error, "Can't fallback with previous state"},
                 {name, {:transaction_state, nil, {%{}, []}}}}
            end
        end
    end
  end

  def handle_info(msg, state) do
    Logger.info(msg)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info("The server terminated because: #{reason}")
  end

  defp handle_change_actions(action, name) do
    new_state_result =
      Map.new(:dets.match_object(name, {:_, :_}))
      |> do_with_state(action)

    case new_state_result do
      {:error, _} = err ->
        err

      {:ok, new_state} ->
        case clean_state(name) do
          {:error, _} = err ->
            err

          {:ok, _} ->
            case upsert(name, Map.to_list(new_state)) do
              {:error, _} = err -> err
              {:ok, _} -> {:ok, action}
            end
        end
    end
  end

  defp do_with_state(state, {:deposit, currency, amount}) do
    case state do
      %{^currency => current} -> {:ok, %{state | currency => current + amount}}
      _ -> {:ok, Map.put_new(state, currency, amount)}
    end
  end

  defp do_with_state(state, {:withdraw, currency, amount}) do
    case state do
      %{^currency => current} when current < amount -> {:error, "Not enough for withdraw"}
      %{^currency => current} -> {:ok, %{state | currency => current - amount}}
      _ -> {:error, "No currency #{currency}"}
    end
  end

  defp clean_state(name) do
    case :dets.delete_all_objects(name) do
      :ok -> {:ok, "cleaned"}
      {:error, _} = err -> err
    end
  end

  defp upsert(name, new_value) do
    case :dets.insert(name, new_value) do
      {:error, _} = err -> err
      _ -> {:ok, new_value}
    end
  end
end
