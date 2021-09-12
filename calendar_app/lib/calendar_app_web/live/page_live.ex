defmodule CalendarAppWeb.PageLive do
  use CalendarAppWeb, :live_view

  alias CalendarApp.Calendar

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CalendarApp.PubSub, "calendars")
    end
    calendars = Calendar.list()
    latest = Enum.map(calendars, &Calendar.get_next_event/1)
    {:ok, assign(socket, calendars: calendars, latest: latest)}
  end

  @impl true
  def handle_info({:updated, calendar_id}, socket) do
    IO.inspect(calendar_id, label: "updated")
    calendars = Calendar.list()
    latest = Enum.map(calendars, &Calendar.get_next_event/1)
    {:noreply, assign(socket, calendars: calendars, latest: latest)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <ul>
    <%= for event <- @latest do %>
      <%= if event do %>
      <li><%= event.summary %></li>
      <% end %>
    <% end %>
    </ul>
    """
  end
end
