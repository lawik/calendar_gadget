defmodule CalendarApp.Calendar do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  require Logger

  schema "calendars" do
    field :data, :string
    field :name, :string
    field :url, :string

    timestamps()
  end

  @doc false
  def changeset(calendar, attrs) do
    calendar
    |> cast(attrs, [:name, :url, :data])
    |> validate_required([:name, :url, :data])
  end

  def list() do
    CalendarApp.Repo.all(from __MODULE__)
  end

  def load(id) do
    CalendarApp.Repo.get!(__MODULE__, id)
  end

  def add(name, url) do
    %__MODULE__{name: name, url: url, data: ""}
    |> CalendarApp.Repo.insert!()
  end

  def update(calendar) do
    CalendarApp.Repo.update!(calendar)
  end

  def update_calendar(%{data: original} = calendar) do
    %{data: new} = download(calendar)
    |> download()

    calendar
    |> Ecto.Changeset.change(%{data: new})
    |> CalendarApp.Repo.update!()

    if original != new do
      Logger.info("New data for #{calendar.name}")
      Phoenix.PubSub.broadcast!(CalendarApp.PubSub, "calendars", {:updated, calendar.id})
    end
  end

  def get_next_event(calendars) when is_list(calendars) do
    events = calendars
    |> Enum.map(&parse_to_events/1)
    |> List.flatten()
    |> expand_recurrence()
    |> reject_past_events()
    |> sort_by_start()

    case events do
      [event | _] -> event
      [] -> nil
      [event] -> event
    end
  end

  def get_next_event(calendar) do
    events = calendar
    |> parse_to_events()
    |> expand_recurrence()
    |> reject_past_events()
    |> sort_by_start()

    case events do
      [event | _] -> event
      [] -> nil
      [event] -> event
    end
  end

  def download(%{name: name, url: url} = calendar) do
    response = :get
    |> Finch.build(url)
    |> Finch.request(CalendarApp.Finch)

    case response do
      {:ok, %{status: 200, body: body}} ->
        Map.put(calendar, :data, body)
      error_response ->
        Logger.error("Could not download URL for #{name}: #{inspect(error_response)}")
        raise "Could not download URL for #{name}."
    end
  end

  def parse_to_events(%{data: data} = _calendar) do
    ICalendar.from_ics(data)
  end

  def expand_recurrence(events, weeks_from_now \\ 1) do
    now = DateTime.utc_now()
    end_date = now |> Date.add(weeks_from_now * 7)
    events
    |> Enum.filter(fn %{rrule: rule} ->
      not is_nil(rule)
    end)
    |> Enum.map(fn event ->
      ICalendar.Recurrence.get_recurrences(event, end_date)
    end)
    |> Enum.flat_map(fn event ->
      event
    end)
    |> Enum.concat(events)
  end

  def reject_past_events(events) do
    now = DateTime.utc_now()
    Enum.reject(events, fn %{dtend: dtend} ->
      DateTime.compare(now, dtend) == :gt
    end)
  end

  def sort_by_start(events) do
    Enum.sort_by(events, fn %{dtstart: dtstart} -> dtstart end, DateTime)
  end
end
