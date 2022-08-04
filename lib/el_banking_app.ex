defmodule ElBankingApp.Api do

  def create_purse() do
    purse = %{
      id: make_ref(),
      start: {Purse, :start_link, [%{}]}
    }
    Supervisor.start_child(ElBankingApp.Supervisor, purse)
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
