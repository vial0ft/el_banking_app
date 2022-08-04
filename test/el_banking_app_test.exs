defmodule ElBankingAppTest do
  use ExUnit.Case

  test "create" do
    assert ElBankingApp.Api.create_purse(:bob) != nil
  end

  test "different pids" do
    assert ElBankingApp.Api.create_purse(:bob) != ElBankingApp.Api.create_purse(:alice)
  end

  test "peek empty purse" do
    {:ok, pid} = ElBankingApp.Api.create_purse(:alex)

    assert %{} == ElBankingApp.Api.peek(pid)
  end

  test "peek empty purse with currency" do
    {:ok, pid} = ElBankingApp.Api.create_purse(:jo)

    assert %{:rub => 0.0} == ElBankingApp.Api.peek(pid, :rub)
  end

  test "deposit" do
    {:ok, pid} = ElBankingApp.Api.create_purse(:john)
    assert %{:rub => 100} == ElBankingApp.Api.deposit(pid, :rub, 100)
  end

  test "withdraw" do
    {:ok, pid} = ElBankingApp.Api.create_purse(:homer)
    ElBankingApp.Api.deposit(pid, :rub, 100)
    assert %{:rub => 50} == ElBankingApp.Api.withdraw(pid, :rub, 50)
  end
end
