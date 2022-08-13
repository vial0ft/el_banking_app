defmodule ElBankingApp.Api do
  @purse_registry :purses_registry

  def create_purse(name) when is_bitstring(name) do
    case create_new_purse(name) do
      {:ok, _pid} = p -> p
      {:error, {:already_started, pid}} -> {:ok, pid}
      err -> err
    end
  end

  defp create_new_purse(name) do
    purse = %{
      id: name,
      start: {ElBankingApp.Purse, :start_link, [name]}
    }

    DynamicSupervisor.start_child(ElBankingApp.PursesSupervisor, purse)
  end

  def get_purse(name) when is_bitstring(name) do
    case Registry.lookup(@purse_registry, name) do
      [] -> {:error, "#{name} isn't exist"}
      [{pid, _}] -> {:ok, pid}
    end
  end

  @spec deposit(atom | pid | {atom, any} | {:via, atom, any}, any, any) :: any
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
