defmodule Purse do
  use GenServer
  require Logger

  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({_, _, amount}, _from, balance) when not is_number(amount) or amount <= 0 do
    {:reply, {:error, "amount must be positive number"}, balance}
  end

  def handle_call({:deposit, currency, amount}, _from, balance) do
    case balance do
      %{^currency => value} ->
        new_value = value + amount
        {:reply, %{currency => new_value}, %{balance | currency => new_value}}

      _ ->
        {:reply, %{currency => amount}, Map.put_new(balance, currency, amount)}
    end
  end

  def handle_call({:withdraw, currency, amount}, _from, balance) do
    case balance do
      %{^currency => value} when value < amount ->
        {:reply, {:error, "Not enough for withdraw"}, balance}

      %{^currency => value} ->
        new_value = value - amount
        {:reply, %{currency => new_value}, %{balance | currency => new_value}}

      _ ->
        {:reply, {:error, "No currency #{currency}"}, balance}
    end
  end

  def handle_call({:peek, currency}, _from, balance) do
    result =
      case balance do
        %{^currency => value} -> value
        _ -> 0
      end

    {:reply, %{currency => result}, balance}
  end

  def handle_call(:peek, _from, balance), do: {:reply, balance, balance}

  def handle_info(msg, state) do
    Logger.info(msg)
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.info("The server terminated because: #{reason}")
  end
end
