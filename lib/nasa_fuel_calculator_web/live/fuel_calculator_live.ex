defmodule NasaFuelCalculatorWeb.FuelCalculatorLive do
  use NasaFuelCalculatorWeb, :live_view

  alias NasaFuelCalculator.FlightPath
  alias NasaFuelCalculator.FlightPath.Step

  @impl true
  def mount(_params, _session, socket) do
    flight_path = FlightPath.new()

    {:ok,
     socket
     |> assign(:flight_path, flight_path)
     |> assign(:mass_input, "")
     |> assign_form(flight_path)
     |> assign(:total_fuel, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-300 py-8">
      <div class="container mx-auto px-4">
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-primary mb-2">NASA Fuel Calculator</h1>
        </div>

        <div class="grid gap-6">
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Spacecraft Mass</h2>
              <div class="form-control w-full max-w-xs">
                <label class="label">
                  <span class="label-text">Enter equipment mass (kg)</span>
                </label>
                <input
                  type="number"
                  name="mass"
                  class={"input input-bordered w-full max-w-xs #{if mass_error?(@form), do: "input-error"}"}
                  value={@mass_input}
                  phx-blur="update_mass"
                  phx-keyup="update_mass"
                  min="1"
                />
                <label :if={mass_error?(@form)} class="label">
                  <span class="label-text-alt text-error">{mass_error(@form)}</span>
                </label>
              </div>
            </div>
          </div>

          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Flight Path</h2>

              <div class="flex flex-wrap gap-2 mb-4">
                <div class="dropdown">
                  <div tabindex="0" role="button" class="btn btn-primary">
                    + Add Launch
                  </div>
                  <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
                    <li :for={planet <- FlightPath.planets()}>
                      <a phx-click="add_step" phx-value-action="launch" phx-value-planet={planet}>
                        {String.capitalize(planet)}
                      </a>
                    </li>
                  </ul>
                </div>

                <div class="dropdown">
                  <div tabindex="0" role="button" class="btn btn-secondary">
                    + Add Landing
                  </div>
                  <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
                    <li :for={planet <- FlightPath.planets()}>
                      <a phx-click="add_step" phx-value-action="land" phx-value-planet={planet}>
                        {String.capitalize(planet)}
                      </a>
                    </li>
                  </ul>
                </div>

                <button :if={@flight_path.steps != []} class="btn btn-outline btn-error" phx-click="clear_path">
                  Clear All
                </button>
              </div>

              <div :if={@flight_path.steps == []} class="alert">
                <span>No flight path defined. Add launch and landing steps above.</span>
              </div>

              <div :if={@flight_path.steps != []} class="flex flex-wrap gap-2 items-center">
                <div
                  :for={{step, index} <- Enum.with_index(@flight_path.steps)}
                  class="flex items-center gap-1"
                >
                  <div class={"badge badge-lg gap-2 #{step_badge_class(step)}"}>
                    {step_label(step)}
                    <button
                      class="btn btn-ghost btn-xs"
                      phx-click="remove_step"
                      phx-value-index={index}
                    >
                      ✕
                    </button>
                  </div>
                  <span :if={index < length(@flight_path.steps) - 1} class="text-base-content/50">→</span>
                </div>
              </div>

              <div :if={steps_error?(@form)} class="alert alert-error mt-4">
                <span>{steps_error(@form)}</span>
              </div>
            </div>
          </div>

          <div :if={@total_fuel} class="card bg-primary text-primary-content shadow-xl">
            <div class="card-body text-center">
              <h2 class="card-title justify-center text-2xl">Total Fuel Required</h2>
              <p class="text-5xl font-bold">{format_number(@total_fuel)} kg</p>
              <p class="text-primary-content/70">
                For a spacecraft of {format_number(@flight_path.mass)} kg
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("update_mass", %{"value" => value}, socket) do
    flight_path = socket.assigns.flight_path

    mass = parse_mass(value)
    flight_path = FlightPath.set_mass(flight_path, mass)

    {:noreply,
     socket
     |> assign(:flight_path, flight_path)
     |> assign(:mass_input, value)
     |> assign_form(flight_path)
     |> calculate_fuel()}
  end

  def handle_event("add_step", %{"action" => action, "planet" => planet}, socket) do
    action_atom = String.to_existing_atom(action)

    flight_path =
      socket.assigns.flight_path
      |> FlightPath.add_step(action_atom, planet)

    {:noreply,
     socket
     |> assign(:flight_path, flight_path)
     |> assign_form(flight_path)
     |> calculate_fuel()}
  end

  def handle_event("remove_step", %{"index" => index}, socket) do
    index = String.to_integer(index)

    flight_path =
      socket.assigns.flight_path
      |> FlightPath.remove_step(index)

    {:noreply,
     socket
     |> assign(:flight_path, flight_path)
     |> assign_form(flight_path)
     |> calculate_fuel()}
  end

  def handle_event("clear_path", _params, socket) do
    flight_path =
      socket.assigns.flight_path
      |> FlightPath.clear_steps()

    {:noreply,
     socket
     |> assign(:flight_path, flight_path)
     |> assign_form(flight_path)
     |> assign(:total_fuel, nil)}
  end

  defp parse_mass(value) do
    case Integer.parse(value) do
      {mass, ""} when mass > 0 -> mass
      _ -> nil
    end
  end

  defp assign_form(socket, flight_path) do
    changeset =
      flight_path
      |> FlightPath.changeset(%{})
      |> Map.put(:action, :validate)

    assign(socket, :form, to_form(changeset, as: "flight_path"))
  end

  defp calculate_fuel(socket) do
    flight_path = socket.assigns.flight_path

    case FlightPath.calculate_fuel(flight_path) do
      {:ok, fuel} -> assign(socket, :total_fuel, fuel)
      {:error, _changeset} -> assign(socket, :total_fuel, nil)
    end
  end

  defp mass_error?(form) do
    form.errors[:mass] != nil
  end

  defp mass_error(form) do
    case form.errors[:mass] do
      {msg, _opts} -> msg
      nil -> nil
    end
  end

  defp steps_error?(form) do
    form.errors[:steps] != nil
  end

  defp steps_error(form) do
    case form.errors[:steps] do
      {msg, _opts} -> msg
      nil -> nil
    end
  end

  defp step_badge_class(%Step{action: :launch}), do: "badge-primary"
  defp step_badge_class(%Step{action: :land}), do: "badge-secondary"

  defp step_label(%Step{action: action, planet: planet}) do
    action_str =
      if action == :launch do
        "Launch"
      else
        "Land"
      end
    "#{action_str} #{String.capitalize(planet)}"
  end

  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(number), do: number
end
