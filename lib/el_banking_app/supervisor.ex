defmodule ElBankingApp.Supervisor do
  use Supervisor

  @name ElBankingApp.Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: @name)
  end

  def init(_init_arg) do
    children = []
    Supervisor.init(children, strategy: :one_for_one)
  end
end
