defmodule FiltrTest do
  use ExUnit.Case, async: true

  doctest Filtr

  describe "run/2 and run/3" do
    test "runs the schema against the params" do
      schema = %{name: %{type: :string}, age: %{type: :integer}}
      result = Filtr.run(schema, %{"name" => "John", "age" => "25"})

      assert result.name == "John"
      assert result.age == 25
      assert result._valid? == true
    end

    test "forwards the run opts to the processor" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert {:error, ["required"]} = Filtr.run(schema, %{}, error_mode: :strict).name
    end

    test "defaults the run opts to an empty list" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert Filtr.run(schema, %{}).name == nil
    end
  end

  describe "collect_errors/1" do
    test "delegates to Filtr.Errors.collect/1" do
      filtr_result = %{correct: true, one: {:error, "error"}}

      assert %{one: ["error"]} == Filtr.collect_errors(filtr_result)
      assert is_nil(Filtr.collect_errors(%{correct: true}))
    end
  end
end
