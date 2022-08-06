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

  def transfer(from_purse, to_purse, {currency, amount}) do
    withdraw(from_purse, currency, amount)
    |> handle_chain_error(
      fn _ -> deposit(to_purse, currency, amount) end,
      fn _err -> deposit(from_purse, currency, amount) end
    )
  end

  defp handle_chain_error(either, do_next, do_on_error) do
    case either do
      {:error, _why} = err ->
        if do_on_error != nil do
          do_on_error.(err)
        else
          err
        end

      ok_like ->
        do_next.(ok_like)
    end
  end
end
