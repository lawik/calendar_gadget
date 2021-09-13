defmodule CalendarApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      CalendarApp.Repo,
      # Start the Telemetry supervisor
      CalendarAppWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CalendarApp.PubSub},
      # Start the Endpoint (http/https)
      CalendarAppWeb.Endpoint,
      # Start a worker by calling: CalendarApp.Worker.start_link(arg)
      # {CalendarApp.Worker, arg}
      CalendarApp.InkyDisplay,
      CalendarApp.Refresher
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CalendarApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CalendarAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
