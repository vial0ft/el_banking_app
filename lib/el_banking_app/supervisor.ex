defmodule ElBankingApp.Supervisor do
  use Supervisor

  @name ElBankingApp.Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: @name)
  end

  def init(_init_arg) do
    children = [
      %{
        id: ElBankingApp.Api,
        start: {ElBankingApp.Api, :start_link, [{}]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
