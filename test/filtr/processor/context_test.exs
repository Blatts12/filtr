defmodule Filtr.Processor.ContextTest do
  use ExUnit.Case, async: true

  alias Filtr.DefaultPlugin
  alias Filtr.Processor.Context

  defp context(params \\ %{}, opts \\ []), do: Context.create_context(params, opts)

  describe "create_context/2" do
    test "starts with an empty result and a valid flag" do
      ctx = context(%{"a" => 1})

      assert ctx.result == []
      assert ctx.params == %{"a" => 1}
      assert ctx.valid? == true
    end

    test "defaults the plugin map and the error mode" do
      ctx = context()

      assert ctx.plugin_map[:string] == DefaultPlugin
      assert ctx.error_mode == Filtr.Helpers.default_error_mode()
    end

    test "takes the plugin map and the error mode from opts" do
      ctx = context(%{}, plugin_map: %{custom: SomePlugin}, error_mode: :strict)

      assert ctx.plugin_map == %{custom: SomePlugin}
      assert ctx.error_mode == :strict
    end

    test "keeps the raw opts" do
      ctx = context(%{}, error_mode: :raise, extra: :thing)

      assert ctx.opts == [error_mode: :raise, extra: :thing]
    end
  end

  describe "get_param/2" do
    test "reads an atom key" do
      assert Context.get_param(context(%{name: "John"}), :name) == "John"
    end

    test "falls back to the string key" do
      assert Context.get_param(context(%{"name" => "John"}), :name) == "John"
    end

    test "prefers the atom key over the string key" do
      assert Context.get_param(context(%{:name => "atom", "name" => "string"}), :name) == "atom"
    end

    test "returns :__none__ for a missing key" do
      assert Context.get_param(context(%{}), :name) == :__none__
    end

    test "returns :__none__ when params are nil" do
      assert Context.get_param(context(nil), :name) == :__none__
    end

    test "returns an explicit nil value" do
      assert Context.get_param(context(%{"name" => nil}), :name) == nil
    end
  end

  describe "put_result/3" do
    test "prepends the key and keeps the context valid" do
      ctx = Context.put_result(context(), :name, "John")

      assert ctx.result == [name: "John"]
      assert ctx.valid? == true
    end

    test "flips valid? on an error value" do
      ctx = Context.put_result(context(), :name, {:error, ["required"]})

      assert ctx.valid? == false
    end

    test "keeps valid? false once it has been flipped" do
      ctx =
        context()
        |> Context.put_result(:a, {:error, ["required"]})
        |> Context.put_result(:b, "ok")

      assert ctx.valid? == false
    end
  end

  describe "put_nested_result/3" do
    test "stores the nested result as a map" do
      nested = %{result: [name: "John", age: 25], valid?: true}
      ctx = Context.put_nested_result(context(), :user, nested)

      assert ctx.result == [user: %{name: "John", age: 25}]
      assert ctx.valid? == true
    end

    test "propagates an invalid nested context" do
      nested = %{result: [name: {:error, ["required"]}], valid?: false}
      ctx = Context.put_nested_result(context(), :user, nested)

      assert ctx.valid? == false
    end
  end

  describe "to_result/1" do
    test "turns the result list into a map with _valid?" do
      result =
        context()
        |> Context.put_result(:name, "John")
        |> Context.put_result(:age, 25)
        |> Context.to_result()

      assert result == %{name: "John", age: 25, _valid?: true}
    end

    test "carries the invalid flag" do
      result =
        context()
        |> Context.put_result(:name, {:error, ["required"]})
        |> Context.to_result()

      assert result._valid? == false
    end
  end

  describe "plugin_for_type/2 and plugin_for_type!/2" do
    test "returns the plugin handling the type" do
      assert Context.plugin_for_type(context(), :string) == DefaultPlugin
    end

    test "returns nil for an unknown type" do
      assert Context.plugin_for_type(context(), :unknown) == nil
    end

    test "returns nil for a non-atom type" do
      assert Context.plugin_for_type(context(), {:list, :string}) == nil
    end

    test "raises for an unknown type in the bang version" do
      assert_raise RuntimeError, ~r/missing plugin for type :unknown/, fn ->
        Context.plugin_for_type!(context(), :unknown)
      end
    end
  end
end
