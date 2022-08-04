defmodule ElBankingApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    ElBankingApp.Supervisor.start_link(name: ElBankingApp.Supervisor)
  end
end
