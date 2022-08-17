defmodule ElBankingApp.Api do
  import ElBankingApp.Supervisor, only: [purse_dyn_supervisor: 0, purse_registry: 0]

  alias ElBankingApp.TransactionApi

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

    DynamicSupervisor.start_child(purse_dyn_supervisor(), purse)
  end

  def get_purse(name) when is_bitstring(name) do
    case Registry.lookup(purse_registry(), name) do
      [] -> {:error, "#{name} isn't exist"}
      [{pid, _}] -> {:ok, pid}
    end
  end

  @spec deposit(atom | pid | {atom, any} | {:via, atom, any}, any, any) :: any
  def deposit(purse, currency, amount) do
    do_with_transaction(purse, {:deposit, currency, amount})

    # GenServer.call(purse, {:deposit, currency, amount})
  end

  def withdraw(purse, currency, amount) do
    do_with_transaction(purse, {:withdraw, currency, amount})
    # GenServer.call(purse, {:withdraw, currency, amount})
  end

  defp do_with_transaction(purse, action) do
    with {:ok, tr_id, _} <- TransactionApi.new_transaction([purse]),
         {:ok, _} <- TransactionApi.add_change(tr_id, purse, action),
         {:ok, _} <- TransactionApi.commit(tr_id) do
      {:ok, action}
    else
      err -> err
    end
  end

  def peek(purse, currency) do
    GenServer.call(purse, {:peek, currency})
  end

  def peek(purse) do
    GenServer.call(purse, :peek)
  end
end
