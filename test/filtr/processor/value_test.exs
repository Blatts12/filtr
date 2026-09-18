defmodule Filtr.Processor.ValueTest do
  use ExUnit.Case, async: true

  alias Filtr.Processor.Context
  alias Filtr.Processor.Value

  defp context(params, opts \\ []), do: Context.create_context(params, opts)

  describe "valid_value?/1" do
    test "returns false only for error tuples" do
      refute Value.valid_value?({:error, ["required"]})
      assert Value.valid_value?("John")
      assert Value.valid_value?(nil)
      assert Value.valid_value?({:ok, "John"})
    end
  end

  describe "to_proper/1" do
    test "unwraps an ok value" do
      assert Value.to_proper({:ok, "John"}) == "John"
    end

    test "unwraps a default value" do
      assert Value.to_proper({:ok, {:default, 0}}) == 0
    end

    test "deduplicates a list of errors" do
      assert Value.to_proper({:error, ["a", "b", "a"]}) == {:error, ["a", "b"]}
    end

    test "wraps a single error into a list" do
      assert Value.to_proper({:error, "required"}) == {:error, ["required"]}
    end

    test "passes any other value through" do
      assert Value.to_proper("John") == "John"
      assert Value.to_proper(nil) == nil
    end
  end

  describe "empty?/1" do
    test "treats nil, :__none__ and empty collections as empty" do
      assert Value.empty?(nil)
      assert Value.empty?(:__none__)
      assert Value.empty?("")
      assert Value.empty?([])
      assert Value.empty?(%{})
    end

    test "treats any other value as present" do
      refute Value.empty?("John")
      refute Value.empty?(0)
      refute Value.empty?(false)
      refute Value.empty?([nil])
    end
  end

  describe "fallback_none/2" do
    test "replaces :__none__ with the fallback" do
      assert Value.fallback_none(:__none__, "x") == "x"
    end

    test "keeps any other value, nil included" do
      assert Value.fallback_none("John", "x") == "John"
      assert Value.fallback_none(nil, "x") == nil
    end
  end

  describe "fallback_map/2" do
    test "keeps a map" do
      assert Value.fallback_map(%{a: 1}, nil) == %{a: 1}
    end

    test "replaces a non-map with the fallback" do
      assert Value.fallback_map("oops", nil) == nil
      assert Value.fallback_map([1, 2], %{}) == %{}
      assert Value.fallback_map(:__none__, %{}) == %{}
    end
  end

  describe "process_param/3" do
    test "casts and stores a valid param" do
      ctx = Value.process_param(:age, %{type: :integer}, context(%{"age" => "25"}))

      assert ctx.result == [age: 25]
      assert ctx.valid? == true
    end

    test "stores the default when the cast falls back" do
      schema = %{type: :integer, default: 0, validators: []}
      ctx = Value.process_param(:age, schema, context(%{"age" => "nope"}, error_mode: :fallback))

      assert ctx.result == [age: 0]
      assert ctx.valid? == true
    end

    test "stores the error and flips valid? in strict mode" do
      ctx = Value.process_param(:age, %{type: :integer}, context(%{"age" => "nope"}, error_mode: :strict))

      assert ctx.result == [age: {:error, ["invalid integer"]}]
      assert ctx.valid? == false
    end

    test "stores a validation error after a successful cast" do
      schema = %{type: :integer, validators: [min: 18]}
      ctx = Value.process_param(:age, schema, context(%{"age" => "10"}, error_mode: :strict))

      assert ctx.result == [age: {:error, ["must be at least 18"]}]
      assert ctx.valid? == false
    end
  end
end
