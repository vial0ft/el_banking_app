defmodule ElBankingApp.Api do
  def create_purse(name) when is_bitstring(name) do
    case Process.whereis(String.to_atom(name)) do
      nil -> create_new_purse(name)
      _pid -> {:error, "#{name} already exist"}
    end
  end

  defp create_new_purse(name) do
    purse = %{
      id: name,
      start: {ElBankingApp.Purse, :start_link, [name]}
    }

    Supervisor.start_child(ElBankingApp.Supervisor, purse)
  end

  def get_purse(name) when is_atom(name) do
    case Process.whereis(name) do
      nil -> {:error, "#{name} not exist"}
      pid -> {:ok, pid}
    end
  end

  def deposit(purse, currency, amount) do
    GenServer.call(purse, {:deposit, currency, amount})
  end

  def withdraw(purse, currency, amount) do
    GenServer.call(purse, {:withdraw, currency, amount})
  end

  def peek(purse, currency) do
    GenServer.call(purse, {:peek, currency})
  end

  def peek(purse) do
    GenServer.call(purse, :peek)
  end

  def transfer(from_purse, to_purse, {currency, amount}) do
    case withdraw(from_purse, currency, amount) do
      {:error, why} ->
        {:error, "Transfer failed during withdraw for #{inspect(from_purse)}: #{why}"}

      _ ->
        case deposit(to_purse, currency, amount) do
          {:error, transfer_fail_reason} ->
            case deposit(from_purse, currency, amount) do
              {:error, why} ->
                {:error, "Transfer failed. Sorry we lost money :-(: #{why}"}

              _ ->
                {:error,
                 "Transfer failed with fallback. #{currency} #{amount} returned to #{inspect(from_purse)}: #{transfer_fail_reason}"}
            end

          _ ->
            {:ok, "#{inspect(from_purse)} => #{currency} #{amount} => #{inspect(to_purse)}"}
        end
    end
  end
end
