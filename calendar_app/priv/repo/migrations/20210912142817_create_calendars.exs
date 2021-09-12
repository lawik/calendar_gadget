defmodule CalendarApp.Repo.Migrations.CreateCalendars do
  use Ecto.Migration

  def change do
    create table(:calendars) do
      add :name, :string
      add :url, :string
      add :data, :text

      timestamps()
    end
  end
end
