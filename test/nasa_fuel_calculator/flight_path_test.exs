defmodule NasaFuelCalculator.FlightPathTest do
  use ExUnit.Case, async: true

  alias NasaFuelCalculator.FlightPath
  alias NasaFuelCalculator.FlightPath.Step

  describe "new/0" do
    test "creates an empty flight path" do
      fp = FlightPath.new()
      assert fp.mass == nil
      assert fp.steps == []
    end
  end

  describe "changeset/2 - mass validation" do
    test "valid with positive mass" do
      fp = %FlightPath{mass: 28801, steps: [%Step{action: :launch, planet: "earth"}, %Step{action: :land, planet: "moon"}]}
      changeset = FlightPath.changeset(fp, %{})
      assert changeset.valid?
    end

    test "invalid without mass" do
      fp = %FlightPath{mass: nil, steps: [%Step{action: :launch, planet: "earth"}, %Step{action: :land, planet: "moon"}]}
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:mass]
    end

    test "invalid with zero mass" do
      fp = %FlightPath{mass: 0, steps: [%Step{action: :launch, planet: "earth"}, %Step{action: :land, planet: "moon"}]}
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
      assert {"must be a positive number", _} = changeset.errors[:mass]
    end

    test "invalid with negative mass" do
      fp = %FlightPath{mass: -100, steps: [%Step{action: :launch, planet: "earth"}, %Step{action: :land, planet: "moon"}]}
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
    end
  end

  describe "changeset/2 - steps validation" do
    test "invalid with empty steps" do
      fp = %FlightPath{mass: 28801, steps: []}
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
      assert {"flight path cannot be empty", _} = changeset.errors[:steps]
    end

    test "invalid when not starting with launch" do
      fp = %FlightPath{mass: 28801, steps: [%Step{action: :land, planet: "earth"}]}
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
      assert {"flight path must start with a launch", _} = changeset.errors[:steps]
    end

    test "invalid when not ending with land" do
      fp = %FlightPath{mass: 28801, steps: [%Step{action: :launch, planet: "earth"}]}
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
      assert {"flight path must end with a landing", _} = changeset.errors[:steps]
    end

    test "invalid with consecutive launches" do
      fp = %FlightPath{
        mass: 28801,
        steps: [
          %Step{action: :launch, planet: "earth"},
          %Step{action: :launch, planet: "moon"},
          %Step{action: :land, planet: "mars"}
        ]
      }
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
      assert {"actions must alternate between launch and land", _} = changeset.errors[:steps]
    end

    test "invalid with consecutive lands" do
      fp = %FlightPath{
        mass: 28801,
        steps: [
          %Step{action: :launch, planet: "earth"},
          %Step{action: :land, planet: "moon"},
          %Step{action: :land, planet: "mars"}
        ]
      }
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
    end

    test "invalid when launching from different planet than last landing" do
      fp = %FlightPath{
        mass: 28801,
        steps: [
          %Step{action: :launch, planet: "earth"},
          %Step{action: :land, planet: "moon"},
          %Step{action: :launch, planet: "mars"},
          %Step{action: :land, planet: "earth"}
        ]
      }
      changeset = FlightPath.changeset(fp, %{})
      refute changeset.valid?
      assert {"must launch from the planet where you last landed", _} = changeset.errors[:steps]
    end

    test "valid when launching from same planet as last landing" do
      fp = %FlightPath{
        mass: 28801,
        steps: [
          %Step{action: :launch, planet: "earth"},
          %Step{action: :land, planet: "moon"},
          %Step{action: :launch, planet: "moon"},
          %Step{action: :land, planet: "earth"}
        ]
      }
      changeset = FlightPath.changeset(fp, %{})
      assert changeset.valid?
    end
  end

  describe "add_step/3" do
    test "adds a step to the flight path" do
      fp = FlightPath.new()
      fp = FlightPath.add_step(fp, :launch, "earth")

      assert length(fp.steps) == 1
      assert hd(fp.steps).action == :launch
      assert hd(fp.steps).planet == "earth"
    end

    test "appends steps in order" do
      fp =
        FlightPath.new()
        |> FlightPath.add_step(:launch, "earth")
        |> FlightPath.add_step(:land, "moon")

      assert length(fp.steps) == 2
      assert Enum.at(fp.steps, 0).action == :launch
      assert Enum.at(fp.steps, 1).action == :land
    end
  end

  describe "remove_step/2" do
    test "removes step at given index" do
      fp =
        FlightPath.new()
        |> FlightPath.add_step(:launch, "earth")
        |> FlightPath.add_step(:land, "moon")
        |> FlightPath.add_step(:launch, "moon")
        |> FlightPath.remove_step(1)

      assert length(fp.steps) == 2
      assert Enum.at(fp.steps, 0).action == :launch
      assert Enum.at(fp.steps, 1).action == :launch
    end
  end

  describe "set_mass/2" do
    test "sets mass on flight path" do
      fp = FlightPath.new() |> FlightPath.set_mass(28801)
      assert fp.mass == 28801
    end

    test "sets nil for invalid mass" do
      fp = FlightPath.new() |> FlightPath.set_mass(-100)
      assert fp.mass == nil
    end
  end

  describe "calculate_fuel/1" do
    test "returns fuel for valid flight path" do
      fp =
        FlightPath.new()
        |> FlightPath.add_step(:launch, "earth")
        |> FlightPath.add_step(:land, "moon")
        |> FlightPath.add_step(:launch, "moon")
        |> FlightPath.add_step(:land, "earth")
        |> FlightPath.set_mass(28801)

      assert {:ok, 51898} = FlightPath.calculate_fuel(fp)
    end

    test "returns error changeset for invalid flight path" do
      fp = FlightPath.new() |> FlightPath.set_mass(28801)
      assert {:error, changeset} = FlightPath.calculate_fuel(fp)
      refute changeset.valid?
    end
  end

  describe "example scenarios with changeset" do
    test "Apollo 11 Mission: 51898 kg fuel" do
      fp =
        FlightPath.new()
        |> FlightPath.add_step(:launch, "earth")
        |> FlightPath.add_step(:land, "moon")
        |> FlightPath.add_step(:launch, "moon")
        |> FlightPath.add_step(:land, "earth")
        |> FlightPath.set_mass(28801)

      changeset = FlightPath.changeset(fp, %{})
      assert changeset.valid?
      assert {:ok, 51898} = FlightPath.calculate_fuel(fp)
    end

    test "Mars Mission: 33388 kg fuel" do
      fp =
        FlightPath.new()
        |> FlightPath.add_step(:launch, "earth")
        |> FlightPath.add_step(:land, "mars")
        |> FlightPath.add_step(:launch, "mars")
        |> FlightPath.add_step(:land, "earth")
        |> FlightPath.set_mass(14606)

      changeset = FlightPath.changeset(fp, %{})
      assert changeset.valid?
      assert {:ok, 33388} = FlightPath.calculate_fuel(fp)
    end

    test "Passenger Ship Mission: 212161 kg fuel" do
      fp =
        FlightPath.new()
        |> FlightPath.add_step(:launch, "earth")
        |> FlightPath.add_step(:land, "moon")
        |> FlightPath.add_step(:launch, "moon")
        |> FlightPath.add_step(:land, "mars")
        |> FlightPath.add_step(:launch, "mars")
        |> FlightPath.add_step(:land, "earth")
        |> FlightPath.set_mass(75432)

      changeset = FlightPath.changeset(fp, %{})
      assert changeset.valid?
      assert {:ok, 212161} = FlightPath.calculate_fuel(fp)
    end
  end
end
