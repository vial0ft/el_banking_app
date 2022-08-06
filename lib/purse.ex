defmodule ElBankingApp.Purse do
  use GenServer
  require Logger

  @spec start_link(any) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(name) do
    case :dets.open_file(name, [{:keypos, 1}, {:type, :set}, {:access, :protected}]) do
      {:ok, ref} -> GenServer.start_link(__MODULE__, ref)
      _ -> {:error, "Can't open purse with name #{name}"}
    end
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({_, _, amount}, _from, name) when not is_number(amount) or amount <= 0 do
    {:reply, {:error, "amount must be positive number"}, name}
  end

  def handle_call({:deposit, currency, amount}, _from, name) do
    case :dets.match_object(name, {currency, :_}) do
      [{^currency, value} | _] -> {:reply, upsert(name, {currency, value + amount}), name}
      _ -> {:reply, upsert(name, {currency, amount}), name}
    end
  end

  def handle_call({:withdraw, currency, amount}, _from, name) do
    case :dets.match_object(name, {currency, :_}) do
      [{^currency, value} | _] when value < amount ->
        {:reply, {:error, "Not enough for withdraw"}, name}

      [{^currency, value} | _] ->
        {:reply, upsert(name, {currency, value - amount}), name}

      _ ->
        {:reply, {:error, "No currency #{currency}"}, name}
    end
  end

  def handle_call({:peek, currency}, _from, name) do
    result =
      case :dets.match_object(name, {currency, :_}) do
        [{^currency, value} | _] -> value
        _ -> 0
      end

    {:reply, {currency, result}, name}
  end

  def handle_call(:peek, _from, name) do
    {:reply, :dets.match_object(name, {:_, :_}), name}
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
