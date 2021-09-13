defmodule CalendarApp.InkyDisplay do
  use GenServer

  alias CalendarApp.Calendar

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @impl true
  def init(opts) do
    {:ok, pid} = Inky.start_link(:phat, :red, %{name: Calendarapp.Inky, border: :accent, hal_mod: CalendarApp.InkyPreview})
    Phoenix.PubSub.subscribe(CalendarApp.PubSub, "calendars")

    paint_default(pid)
    {:ok, %{pid: pid}}
  end

  @impl true
  def handle_info({:updated, calendar_id}, state) do
    calendars = Calendar.list()
    next_event = Calendar.get_next_event(calendars)

    paint_default(state.pid)
    {:noreply, state}
  end

  def paint_default(pid) do
    painter = fn x, y, w, h, _pixels_so_far ->
      wh = w / 2
      hh = h / 2

      case {x >= wh, y >= hh} do
        {true, true} -> :red
        {false, true} -> if(rem(x, 2) == 0, do: :black, else: :white)
        {true, false} -> :black
        {false, false} -> :white
      end
    end

    Inky.set_pixels(pid, painter, border: :white)
  end
end
