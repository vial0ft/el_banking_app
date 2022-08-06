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
    handle_either(
      withdraw(from_purse, currency, amount),
      fn _ -> deposit(to_purse, currency, amount) end,
      fn err ->
        handle_either(
          deposit(from_purse, currency, amount),
          fn _ ->
            {:error,
             "Transfer failed with fallback. #{currency} #{amount} returned to #{from_purse}: #{err}"}
          end,
          fn _ -> {:error, "Transfer failed. Sorry we lost money :-(: #{err}"} end
        )
      end
    )
    |> handle_either(fn _ -> {:ok, "#{from_purse} => #{currency} #{amount} => #{to_purse}"} end)
  end

  defp handle_either(either, do_next, do_on_error \\ nil) do
    case either do
      {:error, _why} = err ->
        if do_on_error != nil do
          do_on_error.(err)
        else
          either
        end

      ok_like ->
        do_next.(ok_like)
    end
  end
end
