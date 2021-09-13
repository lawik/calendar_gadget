defmodule CalendarApp.InkyPreview do
  @behaviour Inky.HAL

  defmodule State do
    @moduledoc false

    @state_fields [:display]
    @enforce_keys @state_fields
    defstruct @state_fields
  end

  @impl Inky.HAL
  def init(args) do
    display = Map.fetch!(args, :display)
    %State{display: display}

  end

  @impl Inky.HAL
  def handle_update(pixels, border, push_policy, %State{display: display} = state) do
    Phoenix.PubSub.broadcast!(CalendarApp.PubSub, "inky-preview", {:put_pixels, %{pixels: pixels, border: border, display: display, push_policy: push_policy}})
    :ok
  end
end
