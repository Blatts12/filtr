defmodule Filtr.Processor.ErrorTest do
  use ExUnit.Case, async: true

  alias Filtr.Processor.Context
  alias Filtr.Processor.Error

  defp context(opts \\ [error_mode: :strict]), do: Context.create_context(%{}, opts)

  describe "missing_plugin_error/2" do
    test "names the type and the label" do
      assert Error.missing_plugin_error(:unknown, "cast") == "missing cast for :unknown"
      assert Error.missing_plugin_error({:foo, :bar}, "validator") == "missing validator for {:foo, :bar}"
    end
  end

  describe "effective_error_mode/2" do
    test "prefers the mode on the key schema" do
      assert Error.effective_error_mode(%{error_mode: :raise}, context()) == :raise
    end

    test "falls back to the context mode" do
      assert Error.effective_error_mode(%{type: :string}, context()) == :strict
    end
  end

  describe "handle_error/4 in :strict mode" do
    test "returns the errors as a list" do
      assert Error.handle_error(["required"], :name, %{type: :string}, context()) == {:error, ["required"]}
    end

    test "wraps a single error" do
      assert Error.handle_error("required", :name, %{type: :string}, context()) == {:error, ["required"]}
    end
  end

  describe "handle_error/4 in :fallback mode" do
    test "returns the default value" do
      schema = %{type: :integer, default: 0}
      ctx = context(error_mode: :fallback)

      assert Error.handle_error(["boom"], :age, schema, ctx) == {:ok, {:default, 0}}
    end

    test "returns nil without a default" do
      ctx = context(error_mode: :fallback)

      assert Error.handle_error(["boom"], :age, %{type: :integer}, ctx) == {:ok, {:default, nil}}
    end
  end

  describe "handle_error/4 in :raise mode" do
    test "raises with the key and the error" do
      ctx = context(error_mode: :raise)

      assert_raise RuntimeError, "Invalid value for age: invalid integer", fn ->
        Error.handle_error(["invalid integer"], :age, %{type: :integer}, ctx)
      end
    end

    test "joins multiple errors" do
      ctx = context(error_mode: :raise)

      assert_raise RuntimeError, "Invalid value for age: too small,\ntoo odd", fn ->
        Error.handle_error(["too small", "too odd"], :age, %{type: :integer}, ctx)
      end
    end

    test "inspects a non-binary error term" do
      ctx = context(error_mode: :raise)

      assert_raise RuntimeError, ~r/Invalid value for age: \{:too_small, 3\}/, fn ->
        Error.handle_error([{:too_small, 3}], :age, %{type: :integer}, ctx)
      end
    end
  end

  describe "not_handled/4" do
    test "returns a missing-plugin error in strict mode" do
      assert Error.not_handled(:data, %{type: :unknown}, context(), "cast") ==
               {:error, ["missing cast for :unknown"]}
    end

    test "returns the default in fallback mode" do
      schema = %{type: :unknown, default: "fallback"}

      assert Error.not_handled(:data, schema, context(error_mode: :fallback), "cast") ==
               {:ok, {:default, "fallback"}}
    end

    test "raises in raise mode" do
      assert_raise RuntimeError, ~r/missing validation for :unknown/, fn ->
        Error.not_handled(:data, %{type: :unknown}, context(error_mode: :raise), "validation")
      end
    end

    test "honors the error mode on the key schema" do
      schema = %{type: :unknown, error_mode: :strict}
      ctx = context(error_mode: :fallback)

      assert Error.not_handled(:data, schema, ctx, "cast") == {:error, ["missing cast for :unknown"]}
    end
  end

  describe "error modes through Filtr.run/3" do
    test "fallback returns the default on a cast error" do
      schema = %{age: %{type: :integer, default: 0, validators: []}}

      assert Filtr.run(schema, %{"age" => "invalid"}, error_mode: :fallback).age == 0
    end

    test "fallback returns nil on a cast error without a default" do
      schema = %{age: %{type: :integer}}

      assert Filtr.run(schema, %{"age" => "invalid"}, error_mode: :fallback).age == nil
    end

    test "fallback returns the default for a missing required field" do
      schema = %{name: %{type: :string, required: true, default: "Guest", validators: []}}

      assert Filtr.run(schema, %{}, error_mode: :fallback).name == "Guest"
    end

    test "fallback returns nil for a missing required field without a default" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert Filtr.run(schema, %{}, error_mode: :fallback).name == nil
    end

    test "fallback returns the default on a validation failure" do
      schema = %{age: %{type: :integer, default: 18, validators: [min: 18]}}

      assert Filtr.run(schema, %{"age" => "10"}, error_mode: :fallback).age == 18
    end

    test "strict returns an error tuple on a cast error" do
      schema = %{age: %{type: :integer}}

      assert {:error, ["invalid integer"]} = Filtr.run(schema, %{"age" => "invalid"}, error_mode: :strict).age
    end

    test "strict returns an error for a missing required field" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert {:error, ["required"]} = Filtr.run(schema, %{}, error_mode: :strict).name
    end

    test "strict returns the value when everything passes" do
      schema = %{name: %{type: :string}}

      assert Filtr.run(schema, %{"name" => "John"}, error_mode: :strict).name == "John"
    end

    test "raise blows up on a cast error" do
      schema = %{age: %{type: :integer}}

      assert_raise RuntimeError, ~r/Invalid value for age/, fn ->
        Filtr.run(schema, %{"age" => "invalid"}, error_mode: :raise)
      end
    end

    test "raise blows up on a missing required field" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert_raise RuntimeError, ~r/Invalid value for name: required/, fn ->
        Filtr.run(schema, %{}, error_mode: :raise)
      end
    end

    test "raise blows up on a validation failure" do
      schema = %{age: %{type: :integer, validators: [min: 18]}}

      assert_raise RuntimeError, ~r/Invalid value for age/, fn ->
        Filtr.run(schema, %{"age" => "10"}, error_mode: :raise)
      end
    end

    test "raise inspects a non-binary error term from a custom validator" do
      schema = %{v: %{type: :integer, validators: [custom: fn _ -> {:error, {:too_small, 3}} end]}}

      assert_raise RuntimeError, ~r/Invalid value for v: \{:too_small, 3\}/, fn ->
        Filtr.run(schema, %{"v" => "1"}, error_mode: :raise)
      end
    end

    test "uses the configured default mode when run_opts say nothing" do
      schema = %{age: %{type: :integer, validators: [min: 18]}}

      assert is_nil(Filtr.run(schema, %{"age" => "10"}).age)
    end
  end

  describe "per-field error modes through Filtr.run/3" do
    test "a field mode wins over the run mode" do
      schema = %{name: %{type: :string, required: true, validators: [], error_mode: :fallback}}

      assert Filtr.run(schema, %{}, error_mode: :strict).name == nil
    end

    test "the run mode applies when the field says nothing" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert {:error, ["required"]} = Filtr.run(schema, %{}, error_mode: :strict).name
    end

    test "a strict field returns an error while a fallback field returns its default" do
      schema = %{
        email: %{type: :string, required: true, validators: [], error_mode: :strict},
        optional_field: %{type: :string, default: "default", validators: [], error_mode: :fallback}
      }

      result = Filtr.run(schema, %{})

      assert {:error, ["required"]} = result.email
      assert result.optional_field == "default"
    end

    test "a fallback field ignores the global strict mode" do
      schema = %{
        critical: %{type: :integer, required: true, validators: []},
        optional: %{type: :integer, default: 0, validators: [], error_mode: :fallback}
      }

      result = Filtr.run(schema, %{"critical" => "10", "optional" => "invalid"}, error_mode: :strict)

      assert result.critical == 10
      assert result.optional == 0
    end

    test "a raise field overrides the global strict mode" do
      schema = %{
        critical: %{type: :integer, required: true, validators: [], error_mode: :raise},
        optional: %{type: :string, default: "default", validators: []}
      }

      assert_raise RuntimeError, ~r/Invalid value for critical: required/, fn ->
        Filtr.run(schema, %{"optional" => "value"}, error_mode: :strict)
      end
    end

    test "field modes apply to validation errors" do
      schema = %{
        strict_field: %{type: :integer, validators: [min: 18], error_mode: :strict},
        fallback_field: %{type: :integer, default: 18, validators: [min: 18], error_mode: :fallback}
      }

      result = Filtr.run(schema, %{"strict_field" => "10", "fallback_field" => "10"})

      assert {:error, ["must be at least 18"]} = result.strict_field
      assert result.fallback_field == 18
    end

    test "field modes apply to cast errors" do
      schema = %{
        strict_field: %{type: :integer, error_mode: :strict},
        fallback_field: %{type: :integer, default: 0, validators: [], error_mode: :fallback}
      }

      result = Filtr.run(schema, %{"strict_field" => "not_an_int", "fallback_field" => "not_an_int"})

      assert {:error, ["invalid integer"]} = result.strict_field
      assert result.fallback_field == 0
    end

    test "field modes apply inside nested schemas" do
      schema = %{
        user: %{
          type: %{
            name: %{type: :string, required: true, validators: [], error_mode: :strict},
            age: %{type: :integer, default: 0, validators: [], error_mode: :fallback}
          }
        }
      }

      result = Filtr.run(schema, %{"user" => %{"age" => "invalid"}}, error_mode: :fallback)

      assert {:error, ["required"]} = result.user.name
      assert result.user.age == 0
    end

    test "every field can carry the same custom mode" do
      schema = %{
        field1: %{type: :string, required: true, validators: [], error_mode: :strict},
        field2: %{type: :string, required: true, validators: [], error_mode: :strict},
        field3: %{type: :string, required: true, validators: [], error_mode: :strict}
      }

      result = Filtr.run(schema, %{}, error_mode: :fallback)

      assert {:error, ["required"]} = result.field1
      assert {:error, ["required"]} = result.field2
      assert {:error, ["required"]} = result.field3
    end

    test "a raise field wins even when other fields already failed" do
      schema = %{
        email: %{type: :string, required: true, validators: [pattern: ~r/@/], error_mode: :strict},
        age: %{type: :integer, default: 18, validators: [min: 18], error_mode: :fallback},
        id: %{type: :integer, required: true, validators: [], error_mode: :raise}
      }

      assert_raise RuntimeError, ~r/Invalid value for id: required/, fn ->
        Filtr.run(schema, %{"email" => "invalid", "age" => "10"})
      end
    end
  end
end
