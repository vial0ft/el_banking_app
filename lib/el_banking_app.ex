defmodule ElBankingApp.Api do
  use GenServer

  def init(state) do
    {:ok, state}
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def create_purse() do
    GenServer.start_link(Purse, %{})
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
