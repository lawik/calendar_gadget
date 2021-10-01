defmodule CalendarApp.InkyDisplay do
  use GenServer

  alias CalendarApp.Calendar
  require Logger

  @to_timezone "Europe/Stockholm"

  @use_hardware Mix.target() != :host
  @priv (if (@use_hardware) do
    "/fonts"
  else
    "priv"
  end)

  @fonts %{
    title: Path.join(@priv, "aqui.bdf"),
    body: Path.join(@priv, "snap.bdf"),
    small: Path.join(@priv, "nu.bdf")
  }


  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @impl true
  def init(opts) do
    type = :phat
    accent = :red
    {:ok, pid1} = Inky.start_link(type, accent, %{name: Calendarapp.InkyPreviewDevice, border: :accent, hal_mod: CalendarApp.InkyPreview})
    pids = if @use_hardware do
      {:ok, pid2} = Inky.start_link(type, accent, %{name: Calendarapp.InkyDevice, border: :accent})
      [pid1, pid2]
    else
      [pid1]
    end
    fonts = @fonts
            |> Enum.map(fn {usage, path} ->
              Logger.info("Loading font: #{path}")
              {:ok, font} = Chisel.Font.load(path)
              {usage, font}
            end)
            |> Map.new()
    Phoenix.PubSub.subscribe(CalendarApp.PubSub, "calendars")
    Phoenix.PubSub.subscribe(CalendarApp.PubSub, "inky-connected")

    spec = Inky.Display.spec_for(type, accent)
    state = %{pids: pids, spec: spec, fonts: fonts, last_event: nil}
    paint_current(state)
    {:ok, state}
  end

  @impl true
  def handle_info({:updated, calendar_id}, state) do
    state = paint_current(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:connected, state) do
    state = paint_current(state)
    {:noreply, state}
  end

  def paint_current(state) do
    case Calendar.list() |> Calendar.get_next_events(2) do
      nil -> nil
      [] -> nil
      [next_event | events] ->
        %{summary: title, dtstart: dtstart, location: location} = next_event
        {after_title, after_start} = case events do
          [%{summary: s, dtstart: st}] -> {s, format_t(st)}
          _ -> {"", ""}
        end
        state.spec
        |> blank_buffer(:white)
        |> draw_rect(0, 0, state.spec.width-1, 20, state.spec.accent)
        |> draw_text(0, 4, format_dt(dtstart), :white, state.fonts.body, centered: state.spec.width)
        |> draw_text(0, 40, location, :black, state.fonts.body, centered: state.spec.width)
        |> draw_rect(8, state.spec.height-34, state.spec.width-8, state.spec.height-34, :black)
        |> draw_text(0, state.spec.height-32, after_title, :black, state.fonts.body, centered: state.spec.width)
        |> draw_text(0, state.spec.height-16, after_start, :black, state.fonts.body, centered: state.spec.width)
        |> draw_text(0, 24, title, :black, state.fonts.title, centered: state.spec.width)
        |> cull(state.spec)
        |> push(state.pids)

        %{state | last_event: next_event}
    end
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

  def push(buffer, pids) do
    Enum.each(pids, fn pid ->
      Inky.set_pixels(pid, buffer)
    end)
  end

  def format_dt(dt) do
    dt
    |> DateTime.shift_zone(@to_timezone)
    |> elem(1)
    |> DateTime.to_iso8601()
    |> String.replace("T", " ")
    |> String.split("+")
    |> hd()
    |> String.replace(":00Z", "")
    |> String.replace("00:00", "00")
  end

  def format_t(dt) do
    dt
    |> DateTime.shift_zone(@to_timezone)
    |> elem(1)
    |> DateTime.to_time()
    |> Time.to_iso8601()
    |> String.replace("00:00", "00")
  end
end
