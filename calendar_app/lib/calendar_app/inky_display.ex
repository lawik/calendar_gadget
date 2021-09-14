defmodule CalendarApp.InkyDisplay do
  use GenServer

  alias CalendarApp.Calendar

  @fonts %{
    title: "priv/aqui.bdf",
    body: "priv/snap.bdf",
    small: "priv/nu.bdf"
  }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @impl true
  def init(opts) do
    type = :phat
    accent = :red
    {:ok, pid} = Inky.start_link(type, accent, %{name: Calendarapp.Inky, border: :accent, hal_mod: CalendarApp.InkyPreview})
    fonts = @fonts
            |> Enum.map(fn {usage, path} ->
              {:ok, font} = Chisel.Font.load(path)
              {usage, font}
            end)
            |> Map.new()
    Phoenix.PubSub.subscribe(CalendarApp.PubSub, "calendars")
    Phoenix.PubSub.subscribe(CalendarApp.PubSub, "inky-connected")

    spec = Inky.Display.spec_for(type, accent)
    state = %{pid: pid, spec: spec, fonts: fonts}
    paint_current(state)
    {:ok, state}
  end

  @impl true
  def handle_info({:updated, calendar_id}, state) do
    paint_current(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:connected, state) do
    paint_current(state)
    {:noreply, state}
  end

  def paint_current(state) do
    %{summary: title, dtstart: dtstart} = next_event = Calendar.list() |> Calendar.get_next_event()
    state.spec
    |> blank_buffer(:white)
    |> draw_rect(0, 0, state.spec.width-1, 20, state.spec.accent)
    |> draw_text(0, 4, format_dt(dtstart), :white, state.fonts.body, centered: state.spec.width)
    |> draw_text(0, 24, title, :black, state.fonts.title, centered: state.spec.width)
    |> cull(state.spec)
    |> push(state.pid)
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

  def blank_buffer(spec, color) do
    draw_rect(%{}, 0, 0, spec.width-1, spec.height-1, color)
  end

  def draw_rect(buffer, start_x, start_y, stop_x, stop_y, color) do
    scratch = for x <- start_x..stop_x,
                  y <- start_y..stop_y, into: %{} do
      {{x, y}, color}
    end
    Map.merge(buffer, scratch)
  end

  def draw_text(buffer, x, y, text, color, font, opts \\ []) do
    centering = Keyword.get(opts, :centered, 0)
    x = case centering do
      0 -> x
      width ->
        text_width = Chisel.Renderer.get_text_width(text, font)
        # Center with x offset
        x = round(((width - text_width) / 2) + x)
    end
    Process.put(:scratch, %{})
    put_pixel = fn x, y ->
      scratch = Process.get(:scratch)
      |> Map.put({x, y}, color)

      Process.put(:scratch, scratch)
    end

    Chisel.Renderer.draw_text(text, x, y, font, put_pixel)
    scratch = Process.get(:scratch)
    Map.merge(buffer, scratch)
  end

  def cull(buffer, spec) do
    buffer
    |> Enum.reject(fn {{x, y}, _} = pixel ->
      x >= spec.width or y >= spec.height
    end)
    |> Map.new()
  end

  def count(buffer, label \\ "count") do
    IO.inspect(Enum.count(buffer), label: label)
    buffer
  end

  def push(buffer, pid) do
    Inky.set_pixels(pid, buffer)
  end

  def format_dt(dt) do
    dt
    |> DateTime.to_iso8601()
    |> String.replace("T", " ")
    |> String.split("+")
    |> hd()
    |> String.replace(":00Z", "")
  end
end
