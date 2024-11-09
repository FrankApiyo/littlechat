defmodule Littlechat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LittlechatWeb.Telemetry,
      Littlechat.Repo,
      {DNSCluster, query: Application.get_env(:littlechat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Littlechat.PubSub},
      LittlechatWeb.Presence,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Littlechat.Finch},
      # Start a worker by calling: Littlechat.Worker.start_link(arg)
      # {Littlechat.Worker, arg},
      # Start to serve requests, typically the last entry
      LittlechatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Littlechat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LittlechatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
