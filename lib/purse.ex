defmodule ElBankingApp.Purse do
  use GenServer
  require Logger

  def start_link(name) do
    GenServer.start_link(__MODULE__, name)
  end

  def init(name) do
    case :dets.open_file('/tmp/purse/#{name}', type: :set) do
      {:ok, ref} -> {:ok, {ref}}
      _ -> {:error, "Can't open purse with name #{name}"}
    end
  end

  def handle_call({_, _, amount}, _from, state) when not is_number(amount) or amount <= 0 do
    {:reply, {:error, "amount must be positive number"}, state}
  end

  def handle_call({:deposit, currency, amount}, _from, {name} = state) do
    case :dets.match_object(name, {currency, :_}) do
      [{^currency, value} | _] -> {:reply, upsert(name, {currency, value + amount}), state}
      _ -> {:reply, upsert(name, {currency, amount}), state}
    end
  end

  def handle_call({:withdraw, currency, amount}, _from, {name} = state) do
    case :dets.match_object(name, {currency, :_}) do
      [{^currency, value} | _] when value < amount ->
        {:reply, {:error, "Not enough for withdraw"}, state}

      [{^currency, value} | _] ->
        {:reply, upsert(name, {currency, value - amount}), state}

      _ ->
        {:reply, {:error, "No currency #{currency}"}, state}
    end
  end

  def handle_call({:peek, currency}, _from, {name} = state) do
    result =
      case :dets.match_object(name, {currency, :_}) do
        [{^currency, value} | _] -> value
        _ -> 0
      end

    {:reply, {currency, result}, state}
  end

  def handle_call(:peek, _from, {name} = state) do
    {:reply, :dets.match_object(name, {:_, :_}), state}
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
