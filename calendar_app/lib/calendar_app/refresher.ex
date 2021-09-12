defmodule CalendarApp.Refresher do
  use GenServer
  alias CalendarApp.Calendar

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, opts)
  end

  @interval 60 # seconds

  def init(opts) do
    state = %{
      opts: opts,
      interval: @interval
    }
    send(self(), :refresh)
    {:ok, state}
  end

  def schedule_next(state) do
    Process.send_after(self(), :refresh, state.interval * 1000)
  end

  def handle_info(:refresh, state) do
    Enum.each(Calendar.list(), fn calendar ->
      Calendar.update_calendar(calendar)
    end)
    schedule_next(state)
    {:noreply, state}
  end
end

