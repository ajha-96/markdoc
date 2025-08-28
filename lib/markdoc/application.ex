defmodule Markdoc.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MarkdocWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:markdoc, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Markdoc.PubSub},
      # Document Registry for process naming
      {Registry, keys: :unique, name: Markdoc.DocumentRegistry},
      # Document management supervisor
      {Markdoc.Documents.DocumentSupervisor, []},
      # Start to serve requests, typically the last entry
      MarkdocWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Markdoc.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MarkdocWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
