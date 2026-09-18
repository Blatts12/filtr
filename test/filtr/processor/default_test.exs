defmodule Filtr.Processor.DefaultTest do
  use ExUnit.Case, async: true

  alias Filtr.Processor.Context
  alias Filtr.Processor.Default

  defp context, do: Context.create_context(%{"page" => "2"}, error_mode: :strict)

  describe "get_default/2" do
    test "returns nil when the schema has no default" do
      assert Default.get_default(%{type: :integer}, context()) == nil
    end

    test "returns nil for an :__none__ default" do
      assert Default.get_default(%{type: :integer, default: :__none__}, context()) == nil
    end

    test "returns a static default" do
      assert Default.get_default(%{type: :integer, default: 1}, context()) == 1
    end

    test "returns a nil default without calling anything" do
      assert Default.get_default(%{type: :integer, default: nil}, context()) == nil
    end

    test "calls a zero-arity default function" do
      assert Default.get_default(%{type: :integer, default: fn -> 12_345 end}, context()) == 12_345
    end

    test "calls a one-arity default function with the context" do
      default_fn = fn ctx -> ctx.error_mode end

      assert Default.get_default(%{type: :integer, default: default_fn}, context()) == :strict
    end

    test "keeps a function of another arity as the value itself" do
      default_fn = fn a, b -> a + b end

      assert Default.get_default(%{type: :integer, default: default_fn}, context()) == default_fn
    end
  end
end
