defmodule CalendarAppWeb.PageLive do
  use CalendarAppWeb, :live_view

  alias CalendarApp.Calendar

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(CalendarApp.PubSub, "calendars")
      Phoenix.PubSub.subscribe(CalendarApp.PubSub, "inky-preview")
      Phoenix.PubSub.broadcast(CalendarApp.PubSub, "inky-connected", :connected)
    end
    calendars = Calendar.list()
    next_event = Calendar.get_next_event(calendars)
    {:ok, assign(socket, calendars: calendars, next_event: next_event, inky_preview: nil)}
  end

  @impl true
  def handle_info({:updated, calendar_id}, socket) do
    calendars = Calendar.list()
    next_event = Calendar.get_next_event(calendars)
    {:noreply, assign(socket, calendars: calendars, next_event: next_event)}
  end

  @impl true
  def handle_info({:put_pixels, inky_state}, socket) do
    {:noreply, assign(socket, inky_preview: inky_state)}
  end

  @impl true
  def render(assigns) do
    ~H"""
      <%= if @next_event do %>
      <h2><%= @next_event.summary %></h2>
        <p>Start: <%= @next_event.dtstart |> format_dt() %></p>
      <% end %>

      <%= if @inky_preview do %>
      <h2>Preview</h2>
      <div style={style_preview(@inky_preview)}>
        <%= for {{x,y}, pixel} <- sort_colors(@inky_preview.pixels) do %>
          <div style={"position: absolute; top: #{y}px; left: #{x}px; width: 1px; height: 1px; background-color: #{pixel};"}></div>
        <% end %>
      </div>
      <% end %>
    """
  end

  def style_preview(%{display: display, border: border}) do
    bcolor = case border do
      :accent -> display.accent
      color -> color
    end
    "position: relative; width: #{display.width+2}px; height: #{display.height+2}px; border: 1px solid #{bcolor};"
  end

  def format_dt(dt) do
    dt
    |> DateTime.to_iso8601()
    |> String.replace("T", " ")
    |> String.split("+")
    |> hd()
  end

  def sort_colors(pixels) do
    pixels
    |> Enum.sort()
    |> Enum.map(fn {pos, color} ->
      code = case color do
        :red -> "#ff0000"
        :black -> "#000000"
        :white -> "#ffffff"
        :yellow -> "#ffff00"
      end
      {pos, code}
    end)
  end
end
