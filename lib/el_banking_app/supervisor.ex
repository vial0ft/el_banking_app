defmodule ElBankingApp.Supervisor do
  use Supervisor

  @supervisor_name ElBankingApp.Supervisor
  @purse_registry :purses_registry
  @transaction_registry :transaction_registry

  def purse_registry, do: @purse_registry
  def transaction_registry, do: @transaction_registry

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: @supervisor_name)
  end

  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: purse_registry()},
      {DynamicSupervisor, strategy: :one_for_one, name: ElBankingApp.PursesSupervisor},
      {Registry, keys: :unique, name: transaction_registry()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
