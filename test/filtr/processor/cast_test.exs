defmodule Filtr.Processor.CastTest do
  use ExUnit.Case, async: true

  alias Filtr.Processor.Cast
  alias Filtr.Processor.Context

  defp context(opts \\ [error_mode: :strict]), do: Context.create_context(%{}, opts)

  describe "cast/4 with opaque values and types" do
    test "passes :__none__ through untouched" do
      assert Cast.cast(:name, %{type: :string}, :__none__, context()) == {:ok, :__none__}
    end

    test "passes any value through for the :__none__ type" do
      assert Cast.cast(:data, %{type: :__none__}, %{"key" => "value"}, context()) == {:ok, %{"key" => "value"}}
    end

    test "passes any value through for a nil type" do
      assert Cast.cast(:data, %{type: nil}, "anything", context()) == {:ok, "anything"}
    end

    test "returns nil for a nil param without asking the plugin" do
      assert Cast.cast(:age, %{type: :integer}, nil, context()) == {:ok, nil}
    end
  end

  describe "cast/4 with plugin types" do
    test "casts through the plugin for the type" do
      assert Cast.cast(:age, %{type: :integer}, "25", context()) == {:ok, 25}
    end

    test "returns the plugin cast error" do
      assert Cast.cast(:age, %{type: :integer}, "nope", context()) == {:error, ["invalid integer"]}
    end

    test "reports a missing plugin for an unknown atom type" do
      assert Cast.cast(:data, %{type: :unknown}, "x", context()) ==
               {:error, ["missing plugin for type :unknown"]}
    end

    test "reports a missing plugin for a non-atom, non-function type" do
      assert {:error, [error]} = Cast.cast(:data, %{type: {:foo, :bar}}, "x", context())
      assert error =~ "missing plugin for type {:foo, :bar}"
    end

    test "reports :not_handled from a plugin as a missing cast" do
      plugin_map = %{weird: __MODULE__.NotHandledPlugin}
      ctx = context(error_mode: :strict, plugin_map: plugin_map)

      assert Cast.cast(:data, %{type: :weird}, "x", ctx) == {:error, ["missing cast for :weird"]}
    end

    test "honors the error mode while casting" do
      schema = %{type: :integer, default: 0}
      ctx = context(error_mode: :fallback)

      assert Cast.cast(:age, schema, "nope", ctx) == {:ok, {:default, 0}}
    end
  end

  describe "cast/4 with a cast function" do
    test "calls a one-arity function with the param" do
      cast_fn = fn value -> String.upcase(value) end

      assert Cast.cast(:name, %{type: cast_fn}, "john", context()) == {:ok, "JOHN"}
    end

    test "calls a two-arity function with the param and the context" do
      cast_fn = fn value, ctx -> {:ok, {value, ctx.error_mode}} end

      assert Cast.cast(:name, %{type: cast_fn}, "john", context()) == {:ok, {"john", :strict}}
    end

    test "calls a three-arity function with the param, the key schema and the context" do
      cast_fn = fn value, key_schema, ctx -> {:ok, {value, key_schema.label, ctx.error_mode}} end
      schema = %{type: cast_fn, label: "name"}

      assert Cast.cast(:name, schema, "john", context()) == {:ok, {"john", "name", :strict}}
    end

    test "accepts a plain return value" do
      cast_fn = fn value, _ctx -> String.upcase(value) end

      assert Cast.cast(:name, %{type: cast_fn}, "john", context()) == {:ok, "JOHN"}
    end

    test "wraps a single error" do
      cast_fn = fn _value, _ctx -> {:error, "custom error"} end

      assert Cast.cast(:name, %{type: cast_fn}, "john", context()) == {:error, ["custom error"]}
    end

    test "keeps a list of errors" do
      cast_fn = fn _value, _ctx -> {:error, ["error1", "error2"]} end

      assert Cast.cast(:name, %{type: cast_fn}, "john", context()) == {:error, ["error1", "error2"]}
    end

    test "reports :not_handled as a missing cast" do
      cast_fn = fn _value, _ctx -> :not_handled end

      assert {:error, [error]} = Cast.cast(:name, %{type: cast_fn}, "john", context())
      assert error =~ "missing cast for"
    end
  end

  describe "casting through Filtr.run/3" do
    test "casts with a custom function returning {:ok, value}" do
      schema = %{name: %{type: fn value, _opts -> {:ok, String.upcase(value)} end}}

      assert Filtr.run(schema, %{"name" => "john"}).name == "JOHN"
    end

    test "casts with a custom function returning a plain value" do
      schema = %{name: %{type: fn value, _opts -> String.upcase(value) end}}

      assert Filtr.run(schema, %{"name" => "john"}).name == "JOHN"
    end

    test "surfaces a custom cast error in strict mode" do
      schema = %{name: %{type: fn _value, _opts -> {:error, "custom error"} end}}

      assert {:error, ["custom error"]} = Filtr.run(schema, %{"name" => "john"}, error_mode: :strict).name
    end

    test "passes :__none__ and nil types through" do
      schema = %{opaque: %{type: :__none__}, untyped: %{type: nil}}
      result = Filtr.run(schema, %{"opaque" => %{"key" => "value"}, "untyped" => "anything"})

      assert result.opaque == %{"key" => "value"}
      assert result.untyped == "anything"
    end

    test "returns an error for an unsupported type in strict mode" do
      result = Filtr.run(%{data: %{type: :unsupported_type}}, %{"data" => "value"}, error_mode: :strict)

      assert {:error, [error]} = result.data
      assert error =~ "unsupported_type"
    end

    test "returns nil for an unsupported type in fallback mode" do
      result = Filtr.run(%{data: %{type: :unsupported_type}}, %{"data" => "value"}, error_mode: :fallback)

      assert result.data == nil
    end

    test "raises for an unsupported type in raise mode" do
      assert_raise RuntimeError, ~r/unsupported_type/, fn ->
        Filtr.run(%{data: %{type: :unsupported_type}}, %{"data" => "value"}, error_mode: :raise)
      end
    end

    test "returns a cast error for a float in an integer field" do
      result = Filtr.run(%{age: %{type: :integer}}, %{"age" => 25.5}, error_mode: :strict)

      assert result._valid? == false
      assert {:error, ["invalid integer"]} = result.age
    end

    test "returns a cast error for a map in an integer field" do
      result = Filtr.run(%{age: %{type: :integer}}, %{"age" => %{"x" => 1}}, error_mode: :strict)

      assert {:error, ["invalid integer"]} = result.age
    end

    test "casts an integer to a float" do
      result = Filtr.run(%{score: %{type: :float}}, %{"score" => 25}, error_mode: :strict)

      assert result.score == 25.0
      assert result._valid? == true
    end

    test "returns a cast error for a list in a float field" do
      result = Filtr.run(%{score: %{type: :float}}, %{"score" => [1, 2]}, error_mode: :strict)

      assert {:error, ["invalid float"]} = result.score
    end
  end

  defmodule NotHandledPlugin do
    @moduledoc false

    def types, do: [:weird]
    def cast(_value, _type, _context), do: :not_handled
  end
end
