defmodule NasaFuelCalculator.Fuel do
  @moduledoc false

  @planets %{
    "earth" => 9.807,
    "moon" => 1.62,
    "mars" => 3.711
  }

  def calculate_path(mass, path) when mass > 0 and is_list(path) do
    path
    |> Enum.reverse()
    |> Enum.reduce({0, mass}, fn {action, planet}, {total_fuel, current_mass} ->
      gravity = Map.get(@planets, planet)

      fuel = case action do
        :launch -> calculate_launch(current_mass, gravity)
        :land -> calculate_land(current_mass, gravity)
      end

      {total_fuel + fuel, current_mass + fuel}
    end)
    |> elem(0)
  end

  def calculate_path(_mass, _path), do: 0

  defp calculate_launch(mass, gravity) when mass > 0 and gravity > 0 do
    calculate_recursive(mass, gravity, &launch_formula/2)
  end

  defp calculate_launch(_mass, _gravity), do: 0

  defp calculate_land(mass, gravity) when mass > 0 and gravity > 0 do
    calculate_recursive(mass, gravity, &land_formula/2)
  end

  defp calculate_land(_mass, _gravity), do: 0

  defp launch_formula(mass, gravity) do
    floor(mass * gravity * 0.042 - 33)
  end

  defp land_formula(mass, gravity) do
    floor(mass * gravity * 0.033 - 42)
  end

  defp calculate_recursive(mass, gravity, formula) do
    initial_fuel = formula.(mass, gravity)

    if initial_fuel <= 0 do
      0
    else
      initial_fuel + calculate_additional_fuel(initial_fuel, gravity, formula)
    end
  end

  defp calculate_additional_fuel(fuel_mass, gravity, formula) do
    additional = formula.(fuel_mass, gravity)

    if additional <= 0 do
      0
    else
      additional + calculate_additional_fuel(additional, gravity, formula)
    end
  end
end
