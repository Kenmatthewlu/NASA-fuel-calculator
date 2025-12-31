defmodule NasaFuelCalculator.FlightPath do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias NasaFuelCalculator.Fuel

  @planets ["earth", "moon", "mars"]
  @actions [:launch, :land]

  embedded_schema do
    field :mass, :integer
    embeds_many :steps, Step, on_replace: :delete
  end

  defmodule Step do
    use Ecto.Schema
    import Ecto.Changeset

    @planets ["earth", "moon", "mars"]
    @actions [:launch, :land]

    embedded_schema do
      field :action, Ecto.Enum, values: [:launch, :land]
      field :planet, :string
    end

    def changeset(step, attrs) do
      step
      |> cast(attrs, [:action, :planet])
      |> validate_required([:action, :planet])
      |> validate_inclusion(:action, @actions)
      |> validate_inclusion(:planet, @planets)
    end
  end

  def new do
    %__MODULE__{mass: nil, steps: []}
  end

  def changeset(flight_path, attrs \\ %{}) do
    flight_path
    |> cast(attrs, [:mass])
    |> cast_embed(:steps, with: &Step.changeset/2)
    |> validate_required([:mass])
    |> validate_mass_positive()
    |> validate_steps_present()
    |> validate_path_sequence()
  end

  def validate(flight_path, attrs) do
    changeset = changeset(flight_path, attrs)

    if changeset.valid? do
      {:ok, apply_changes(changeset)}
    else
      {:error, changeset}
    end
  end

  def add_step(%__MODULE__{steps: steps} = flight_path, action, planet)
      when action in @actions and planet in @planets do
    new_step = %Step{action: action, planet: planet}
    %{flight_path | steps: steps ++ [new_step]}
  end

  def remove_step(%__MODULE__{steps: steps} = flight_path, index) when is_integer(index) do
    %{flight_path | steps: List.delete_at(steps, index)}
  end

  def clear_steps(%__MODULE__{} = flight_path) do
    %{flight_path | steps: []}
  end

  def set_mass(%__MODULE__{} = flight_path, mass) when is_integer(mass) and mass > 0 do
    %{flight_path | mass: mass}
  end

  def set_mass(%__MODULE__{} = flight_path, _mass) do
    %{flight_path | mass: nil}
  end

  def calculate_fuel(%__MODULE__{mass: mass, steps: steps} = flight_path) do
    changeset = changeset(flight_path, %{})

    if changeset.valid? do
      path = Enum.map(steps, fn %Step{action: action, planet: planet} -> {action, planet} end)
      {:ok, Fuel.calculate_path(mass, path)}
    else
      {:error, changeset}
    end
  end

  def steps_to_path(%__MODULE__{steps: steps}) do
    Enum.map(steps, fn %Step{action: action, planet: planet} -> {action, planet} end)
  end

  def planets, do: @planets

  def actions, do: @actions

  # Private validation functions

  defp validate_mass_positive(changeset) do
    mass = get_field(changeset, :mass)

    cond do
      is_nil(mass) -> changeset
      mass <= 0 -> add_error(changeset, :mass, "must be a positive number")
      true -> changeset
    end
  end

  defp validate_steps_present(changeset) do
    steps = get_field(changeset, :steps, [])

    if Enum.empty?(steps) do
      add_error(changeset, :steps, "flight path cannot be empty")
    else
      changeset
    end
  end

  defp validate_path_sequence(changeset) do
    steps = get_field(changeset, :steps, [])

    if Enum.empty?(steps) do
      changeset
    else
      changeset
      |> validate_starts_with_launch(steps)
      |> validate_ends_with_land(steps)
      |> validate_alternating(steps)
      |> validate_launch_from_landing(steps)
    end
  end

  defp validate_starts_with_launch(changeset, [%Step{action: :launch} | _]), do: changeset

  defp validate_starts_with_launch(changeset, _steps) do
    add_error(changeset, :steps, "flight path must start with a launch")
  end

  defp validate_ends_with_land(changeset, steps) do
    case List.last(steps) do
      %Step{action: :land} -> changeset
      _ -> add_error(changeset, :steps, "flight path must end with a landing")
    end
  end

  defp validate_alternating(changeset, steps) do
    valid? =
      steps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn
        [%Step{action: :launch}, %Step{action: :land}] -> true
        [%Step{action: :land}, %Step{action: :launch}] -> true
        _ -> false
      end)

    if valid? do
      changeset
    else
      add_error(changeset, :steps, "actions must alternate between launch and land")
    end
  end

  defp validate_launch_from_landing(changeset, steps) do
    valid? =
      steps
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.all?(fn
        [%Step{action: :land, planet: land_planet}, %Step{action: :launch, planet: launch_planet}] ->
          land_planet == launch_planet
        _ ->
          true
      end)

    if valid? do
      changeset
    else
      add_error(changeset, :steps, "must launch from the planet where you last landed")
    end
  end
end
