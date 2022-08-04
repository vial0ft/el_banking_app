defmodule ElBankingAppTest do
  use ExUnit.Case

  test "create" do
    assert ElBankingApp.Api.create_purse() != nil
  end

  test "different pids" do
    assert ElBankingApp.Api.create_purse() != ElBankingApp.Api.create_purse()
  end

  test "peek empty purse" do
    {:ok, pid} = ElBankingApp.Api.create_purse()

    assert %{} == ElBankingApp.Api.peek(pid)
  end

  test "peek empty purse with currency" do
    {:ok, pid} = ElBankingApp.Api.create_purse()

    assert %{:rub => 0.0} == ElBankingApp.Api.peek(pid, :rub)
  end

  test "deposit" do
    {:ok, pid} = ElBankingApp.Api.create_purse()
    assert %{:rub => 100} == ElBankingApp.Api.deposit(pid, :rub, 100)
  end

  test "withdraw" do
    {:ok, pid} = ElBankingApp.Api.create_purse()
    ElBankingApp.Api.deposit(pid, :rub, 100)
    assert %{:rub => 50} == ElBankingApp.Api.withdraw(pid, :rub, 50)
  end
end
