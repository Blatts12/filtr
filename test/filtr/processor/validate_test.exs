defmodule Filtr.Processor.ValidateTest do
  use ExUnit.Case, async: true

  alias Filtr.Processor.Context
  alias Filtr.Processor.Validate

  defp context(opts \\ [error_mode: :strict]), do: Context.create_context(%{}, opts)

  describe "validate/4 with a missing value" do
    test "reports required for :__none__ on a required field" do
      schema = %{type: :string, required: true, validators: []}

      assert Validate.validate(:name, schema, :__none__, context()) == {:error, ["required"]}
    end

    test "reports required for nil on a required field" do
      schema = %{type: :string, required: true, validators: []}

      assert Validate.validate(:name, schema, nil, context()) == {:error, ["required"]}
    end

    test "returns the default for a missing optional field" do
      schema = %{type: :integer, default: 1, validators: []}

      assert Validate.validate(:page, schema, :__none__, context()) == {:ok, 1}
    end

    test "returns nil for a missing optional field without a default" do
      assert Validate.validate(:page, %{type: :integer}, :__none__, context()) == {:ok, nil}
    end

    test "skips validators for a missing value" do
      schema = %{type: :string, validators: [min: 3]}

      assert Validate.validate(:name, schema, nil, context()) == {:ok, nil}
    end
  end

  describe "validate/4 with a present value" do
    test "returns the value when there is nothing to check" do
      assert Validate.validate(:name, %{type: :string}, "John", context()) == {:ok, "John"}
    end

    test "runs the plugin validators" do
      schema = %{type: :integer, validators: [min: 18]}

      assert Validate.validate(:age, schema, 25, context()) == {:ok, 25}
      assert Validate.validate(:age, schema, 10, context()) == {:error, ["must be at least 18"]}
    end

    test "collects the errors of every failing validator" do
      schema = %{type: :integer, validators: [min: 18, max: 10]}

      assert {:error, errors} = Validate.validate(:age, schema, 15, context())
      assert length(errors) == 2
    end

    test "reports required for a present but empty value" do
      schema = %{type: :string, required: true, validators: []}

      assert Validate.validate(:name, schema, "", context()) == {:error, ["required"]}
    end

    test "reports a missing plugin when the type has no plugin" do
      schema = %{type: fn v -> {:ok, v} end, validators: [min: 2]}

      assert {:error, [error]} = Validate.validate(:name, schema, "ab", context())
      assert error =~ "missing plugin"
    end

    test "reports a missing validator when the plugin does not handle it" do
      schema = %{type: :integer, validators: [bogus: true]}

      assert {:error, [error]} = Validate.validate(:v, schema, 5, context())
      assert error =~ "missing validator for :integer"
    end

    test "keeps the real errors alongside a missing-validator error" do
      schema = %{type: :integer, validators: [min: 100, bogus: true]}

      assert {:error, errors} = Validate.validate(:v, schema, 5, context())
      assert "must be at least 100" in errors
      assert Enum.any?(errors, &(&1 =~ "missing validator"))
    end

    test "honors the error mode of the key schema" do
      schema = %{type: :integer, validators: [min: 18], default: 18, error_mode: :fallback}

      assert Validate.validate(:age, schema, 10, context()) == {:ok, {:default, 18}}
    end
  end

  describe "validate/4 with custom validators" do
    test "accepts true, :ok and {:ok, value}" do
      for result <- [true, :ok, {:ok, "john"}] do
        schema = %{type: :string, validators: [custom: fn _value -> result end]}

        assert Validate.validate(:name, schema, "john", context()) == {:ok, "john"}
      end
    end

    test "turns false and :error into a generic message" do
      for result <- [false, :error] do
        schema = %{type: :string, validators: [custom: fn _value -> result end]}

        assert Validate.validate(:name, schema, "john", context()) == {:error, ["invalid value"]}
      end
    end

    test "keeps a single custom error message" do
      schema = %{type: :string, validators: [custom: fn _value -> {:error, "too short"} end]}

      assert Validate.validate(:name, schema, "john", context()) == {:error, ["too short"]}
    end

    test "keeps a list of custom error messages" do
      schema = %{type: :string, validators: [custom: fn _value -> {:error, ["a", "b"]} end]}

      assert {:error, errors} = Validate.validate(:name, schema, "john", context())
      assert Enum.sort(errors) == ["a", "b"]
    end

    test "calls a one-arity validator with the value" do
      schema = %{type: :string, validators: [custom: fn value -> value == "john" end]}

      assert Validate.validate(:name, schema, "john", context()) == {:ok, "john"}
    end

    test "calls a two-arity validator with the value and the type" do
      schema = %{type: :string, validators: [custom: fn _value, type -> type == :string end]}

      assert Validate.validate(:name, schema, "john", context()) == {:ok, "john"}
    end

    test "calls a three-arity validator with the value, the type and the context" do
      validator = fn _value, _type, ctx -> ctx.error_mode == :strict end
      schema = %{type: :string, validators: [custom: validator]}

      assert Validate.validate(:name, schema, "john", context()) == {:ok, "john"}
    end
  end

  describe "validation through Filtr.run/3" do
    test "runs several validators on one field" do
      schema = %{username: %{type: :string, validators: [min: 3, max: 20]}}

      assert Filtr.run(schema, %{"username" => "john_doe"}).username == "john_doe"
    end

    test "does not treat :default and :required as validators" do
      schema = %{name: %{type: :string, required: true, default: "test", validators: [min: 2]}}

      assert Filtr.run(schema, %{"name" => "John"}).name == "John"
    end

    test "deduplicates repeated errors" do
      too_short = fn _value -> {:error, "too short"} end
      bad_format = fn _value -> {:error, "invalid format"} end

      schema = %{
        name: %{
          type: :string,
          validators: [custom: too_short, custom: too_short, custom: bad_format]
        }
      }

      assert {:error, ["invalid format", "too short"]} =
               Filtr.run(schema, %{"name" => "ab"}, error_mode: :strict).name
    end

    test "treats an explicit nil as missing for an optional field" do
      schema = %{name: %{type: :string, validators: [min: 3]}}
      result = Filtr.run(schema, %{"name" => nil}, error_mode: :strict)

      assert result._valid? == true
      assert result.name == nil
    end

    test "reports required for an explicit nil on a required field" do
      schema = %{name: %{type: :string, required: true, validators: [min: 3]}}
      result = Filtr.run(schema, %{"name" => nil}, error_mode: :strict)

      assert result._valid? == false
      assert {:error, ["required"]} = result.name
    end

    test "skips validators for a nil element inside a list" do
      schema = %{tags: %{type: {:list, :string}, validators: [min: 2]}}
      result = Filtr.run(schema, %{"tags" => ["ok", nil]}, error_mode: :strict)

      assert result.tags == ["ok", nil]
    end
  end
end
