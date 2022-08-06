defmodule ElBankingApp.Api do
  def create_purse(name) when is_atom(name) do
    case Process.whereis(name) do
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
end
