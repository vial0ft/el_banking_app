defmodule ElBankingApp.Purse do
  use GenServer
  require Logger

  @tr_timeout 1000 * 60

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: process_name(name))
  end

  defp process_name(name), do: {:via, Registry, {ElBankingApp.Supervisor.purse_registry(), name}}

  def init(name) do
    case :dets.open_file('/tmp/purse_#{name}', type: :set) do
      {:ok, ref} -> {:ok, {ref, {:tx_state, nil, {%{}, []}}}}
      _ -> {:error, "Can't open purse with name #{name}"}
    end
  end

  # def handle_call({action, _, _}, _from, {_, {:tx_state, tr_id, _tr_state}} = state)
  #     when not is_nil(tr_id) do
  #   {:reply, {:error, "#{action} blocked during transaction"}, state}
  # end

  # def handle_call({_, _, amount}, _from, state) when not is_number(amount) or amount <= 0 do
  #   {:reply, {:error, "amount must be positive number"}, state}
  # end

  # def handle_call({:deposit, _currency, _amount} = action, _from, {name, _} = state) do
  #   {:reply, handle_change_actions(action, name), state}
  # end

  # def handle_call({:withdraw, _currency, _amount} = action, _from, {name, _} = state) do
  #   {:reply, handle_change_actions(action, name), state}
  # end

  def handle_call({:peek, currency}, _from, {name, _} = state) do
    result =
      case :dets.match_object(name, {currency, :_}) do
        [{^currency, value} | _] -> value
        _ -> 0
      end

    {:reply, {:ok, {currency, result}}, state}
  end

  def handle_call(:peek, _from, {name, _} = state) do
    {:reply, {:ok, :dets.match_object(name, {:_, :_})}, state}
  end

  # Transaction handlers

  # tx_init

  def handle_call({:tx_init, tr_id}, _from, {name, {:tx_state, nil, _tr_state}}) do
    Process.send_after(self(), {:tx_timeout, tr_id}, @tr_timeout)
    state = :dets.match_object(name, {:_, :_})
    {:reply, {:ok, tr_id}, {name, {:tx_state, tr_id, {Map.new(state), state}}}}
  end

  def handle_call(
        {:tx_init, tr_id},
        _from,
        {_, {:tx_state, tr_id, _tr_state}} = state
      ) do
    {:reply, {:error, "already started"}, state}
  end

  def handle_call(
        {:tx_init, other_tr_id},
        _from,
        {_, {:tx_state, tr_id, _tr_state}} = state
      )
      when other_tr_id != tr_id do
    {:reply, {:error, "#{other_tr_id} can't start during other transaction"}, state}
  end

  # tx_add

  def handle_call(
        {:tx_add, {other_tr_id, _}},
        _from,
        {_, {:tx_state, tr_id, _tr_state}} = state
      )
      when other_tr_id != tr_id do
    {:reply, {:error, "#{other_tr_id} wrong transaction id"}, state}
  end

  def handle_call(
        {:tx_add, {tr_id, action}},
        _from,
        {name, {:tx_state, tr_id, {tr_state, fallback_state}}} = state
      ) do
    {result, new_state} =
      case do_with_state(tr_state, action) do
        {:ok, new_tr_state} ->
          {{:ok, action}, {name, {:tx_state, tr_id, {new_tr_state, fallback_state}}}}

        {:error, _why} = err ->
          {err, state}
      end

    {:reply, result, new_state}
  end

  # tx_fallback

  def handle_call(
        {:tx_rollback, {tr_id, reason}},
        _from,
        {name, {:tx_state, tr_id, {_tr_state, fallback_state}}}
      ) do
    clean_state(name)
    upsert(name, fallback_state)
    {:reply, {:ok, {:rollback, tr_id, reason}}, default_state(name)}
  end

  def handle_call(
        {:tx_rollback, {other_tr_id, _}},
        _from,
        {_, {:tx_state, tr_id, _}} = state
      )
      when other_tr_id != tr_id do
    {:reply, {:error, "#{other_tr_id} wrong transaction id"}, state}
  end

  # tx_commit

  def handle_call(
        {:tx_commit, tr_id},
        _from,
        {name, {:tx_state, tr_id, {tr_state, fallback_state}}} = state
      ) do
    {result, new_state} =
      with {:ok, _cleaned} <- clean_state(name),
           list <- Map.to_list(tr_state),
           {:ok, _applied_tr_state} <- upsert(name, list) do
        {{:ok}, {name, {:tx_state, tr_id, {%{}, fallback_state}}}}
      else
        {:error, _why} = err -> {err, state}
      end

    Logger.info("commit result: #{inspect(result)} - #{inspect(new_state)}")
    {:reply, result, new_state}
  end

  def handle_call(
        {:tx_commit, other_tr_id},
        _from,
        {_, {:tx_state, tr_id, _}} = state
      )
      when other_tr_id != tr_id do
    {:reply, {:error, "#{other_tr_id} can't commit during other transaction"}, state}
  end

  # tx_close

  def handle_call(
        {:tx_close, tr_id},
        _from,
        {name, {:tx_state, tr_id, _}}
      ) do
    {:reply, {:ok, {:closed, tr_id}}, default_state(name)}
  end

  def handle_call(
        {:tx_close, {other_tr_id, _}},
        _from,
        {_, {:tx_state, tr_id, _}} = state
      )
      when other_tr_id != tr_id do
    {:reply, {:error, "#{other_tr_id} wrong transaction id"}, state}
  end

  # tx_timeout

  def handle_call({:tx_timeout, _tr_id}, _from, {_, {:tx_state, nil, _}} = state) do
    Logger.info("Timeout outside transaction. Do nothing")
    {:noreply, state}
  end
  def handle_call({:tx_timeout, other_tr_id}, _from, {_, {:tx_state, tr_id, _}} = state) when other_tr_id != tr_id do
    Logger.info("Timeout for other transaction. Do nothing")
    {:noreply, state}
  end
  def handle_call({:tx_timeout, tr_id}, _from, {name, {:tx_state, tr_id, _}}) do
    Logger.info("Transaction timeout. Do rollback")
    {:noreply, default_state(name)}
  end

  def handle_call(msg, _from, state) do
    Logger.info("#{inspect(msg)} - #{inspect(state)} - do nothing")
    {:reply, :ok, state}
  end

  def handle_info(msg, state) do
    Logger.info(msg)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info("The server terminated because: #{reason}")
  end

  # defp handle_change_actions(action, name) do
  #   new_state_result =
  #     Map.new(:dets.match_object(name, {:_, :_}))
  #     |> do_with_state(action)

  #   with {:ok, new_state} <- new_state_result,
  #        {:ok, _} <- clean_state(name),
  #        {:ok, _} <- upsert(name, Map.to_list(new_state)) do
  #     {:ok, action}
  #   else
  #     err -> err
  #   end
  # end

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

  defp default_state(name) do
    {name, {:tx_state, nil, {%{}, []}}}
  end
end
