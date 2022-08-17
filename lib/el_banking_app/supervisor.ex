defmodule ElBankingApp.Supervisor do
  use Supervisor

  def purse_registry, do: :purses_registry
  def transaction_registry, do: :transaction_registry
  def purse_dyn_supervisor, do: :purse_dyn_supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: ElBankingApp.Supervisor)
  end

  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: purse_registry()},
      %{
        id: DynamicSupervisor,
        start:
          {DynamicSupervisor, :start_link,
           [[strategy: :one_for_one, name: purse_dyn_supervisor()]]}
      },
      {Registry, keys: :unique, name: transaction_registry()}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
