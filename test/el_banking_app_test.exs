defmodule ElBankingAppTest do
  use ExUnit.Case

  test "create purce" do
    assert ElBankingApp.Api.create_purse("test_bob") != nil
  end

  test "create two purce" do
    assert ElBankingApp.Api.create_purse("test_alice") !=
             ElBankingApp.Api.create_purse("test_bob")
  end

  test "deposit" do
    {:ok, john} = ElBankingApp.Api.create_purse("test_john")
    ElBankingApp.Api.deposit(john, "usd", 100)
    {:ok, peek} = ElBankingApp.Api.peek(john, "usd")
    assert peek == {"usd", 100}
  end

  test "withdraw" do
    {:ok, john} = ElBankingApp.Api.create_purse("test_john1")
    ElBankingApp.Api.deposit(john, "usd", 100)
    ElBankingApp.Api.withdraw(john, "usd", 50)
    {:ok, peek} = ElBankingApp.Api.peek(john, "usd")
    assert peek == {"usd", 50}
  end

  test "Transaction success", context do
    context =
      ["tr1", "tr2", "tr3"]
      |> Enum.map(fn tr_name ->
        {:ok, pid} = ElBankingApp.Api.create_purse(tr_name)
        ElBankingApp.Api.deposit(pid, "usd", 100)
        {tr_name, pid}
      end)
      |> Map.new()

    pid1 = context["tr1"]
    pid2 = context["tr2"]
    pid3 = context["tr3"]

    {:ok, {"usd", a1}} = ElBankingApp.Api.peek(pid1, "usd")
    {:ok, {"usd", a2}} = ElBankingApp.Api.peek(pid2, "usd")
    {:ok, {"usd", a3}} = ElBankingApp.Api.peek(pid3, "usd")

    {:ok, tr_id} = ElBankingApp.TransactionApi.new_transaction([pid1, pid2, pid3])
    ElBankingApp.TransactionApi.add_change(tr_id, pid1, {:withdraw, "usd", 10})
    ElBankingApp.TransactionApi.add_change(tr_id, pid2, {:withdraw, "usd", 20})
    ElBankingApp.TransactionApi.add_change(tr_id, pid3, {:deposit, "usd", 30})
    ElBankingApp.TransactionApi.commit(tr_id)

    {:ok, {"usd", a11}} = ElBankingApp.Api.peek(pid1, "usd")
    {:ok, {"usd", a21}} = ElBankingApp.Api.peek(pid2, "usd")
    {:ok, {"usd", a31}} = ElBankingApp.Api.peek(pid3, "usd")

    assert a1 + a2 + a3 == a11 + a21 + a31
  end

  defp invoke_local_or_imported_function(context) do
    [from_named_setup: true]
  end
end
