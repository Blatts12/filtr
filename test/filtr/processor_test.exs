defmodule Filtr.ProcessorTest do
  use ExUnit.Case, async: true

  alias Filtr.Processor

  describe "run/3 with flat schemas" do
    test "processes a single field" do
      assert Processor.run(%{name: %{type: :string}}, %{"name" => "John"}).name == "John"
    end

    test "processes several fields and casts each one" do
      schema = %{name: %{type: :string}, age: %{type: :integer}}
      result = Processor.run(schema, %{name: "John", age: "25"})

      assert result.name == "John"
      assert result.age == 25
    end

    test "returns nil for a param that is not there" do
      assert Processor.run(%{name: %{type: :string}}, %{}).name == nil
    end

    test "applies a static default for a missing param" do
      schema = %{page: %{type: :integer, default: 1, validators: []}}

      assert Processor.run(schema, %{}).page == 1
    end

    test "applies a function default for a missing param" do
      schema = %{timestamp: %{type: :integer, default: fn -> 12_345 end, validators: []}}

      assert Processor.run(schema, %{}).timestamp == 12_345
    end

    test "applies the default when the param is explicitly nil" do
      schema = %{page: %{type: :integer, default: 1}}

      assert Processor.run(schema, %{"page" => nil}).page == 1
    end

    test "keeps the param when it is provided" do
      schema = %{page: %{type: :integer, default: 1, validators: []}}

      assert Processor.run(schema, %{"page" => "2"}).page == 2
    end

    test "keeps a required field that has a value" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert Processor.run(schema, %{"name" => "John"}).name == "John"
    end
  end

  describe "run/3 with nested map schemas" do
    test "processes a nested schema" do
      schema = %{user: %{type: %{name: %{type: :string}}}}

      assert Processor.run(schema, %{"user" => %{"name" => "John"}}).user.name == "John"
    end

    test "passes the run opts down to the nested schema" do
      schema = %{user: %{type: %{name: %{type: :string, required: true, validators: []}}}}
      result = Processor.run(schema, %{"user" => %{}}, error_mode: :strict)

      assert {:error, ["required"]} = result.user.name
    end

    test "lets a nested field override the run opts" do
      schema = %{
        user: %{type: %{name: %{type: :string, required: true, validators: [], error_mode: :fallback}}}
      }

      assert Processor.run(schema, %{"user" => %{}}, error_mode: :strict).user.name == nil
    end

    test "fills the nested schema with nils when the param is a scalar" do
      schema = %{user: %{type: %{name: %{type: :string}}}}

      assert Processor.run(schema, %{"user" => "oops"}).user == %{name: nil}
    end

    test "reports required for a missing nested map" do
      schema = %{user: %{type: %{name: %{type: :string}}, required: true}}
      result = Processor.run(schema, %{}, error_mode: :strict)

      assert result._valid? == false
      assert {:error, ["required"]} = result.user
    end

    test "applies the default for a missing nested map" do
      schema = %{user: %{type: %{name: %{type: :string}}, default: %{name: "Guest"}}}

      assert Processor.run(schema, %{}).user == %{name: "Guest"}
    end
  end

  describe "run/3 with list schemas" do
    test "processes a list of scalars" do
      schema = %{tags: %{type: {:list, :string}}}

      assert Processor.run(schema, %{"tags" => ["elixir", "phoenix"]}).tags == ["elixir", "phoenix"]
    end

    test "casts every item" do
      schema = %{scores: %{type: {:list, :integer}}}

      assert Processor.run(schema, %{"scores" => ["10", "20", "30"]}).scores == [10, 20, 30]
    end

    test "keeps an empty list" do
      schema = %{tags: %{type: {:list, :string}}}

      assert Processor.run(schema, %{"tags" => []}).tags == []
    end

    test "validates every item on its own" do
      schema = %{tags: %{type: {:list, :string}, validators: [min: 2]}}
      result = Processor.run(schema, %{"tags" => ["elixir", "a", "phoenix"]}, error_mode: :strict)

      assert ["elixir", {:error, _}, "phoenix"] = result.tags
      assert result._valid? == false
    end

    test "processes a list of nested map schemas" do
      schema = %{
        items: %{type: {:list, %{name: %{type: :string}, quantity: %{type: :integer}}}}
      }

      params = %{"items" => [%{"name" => "Product A", "quantity" => "5"}]}

      assert [%{name: "Product A", quantity: 5}] = Processor.run(schema, params).items
    end

    test "fills list items with nils when they are scalars instead of maps" do
      schema = %{items: %{type: {:list, %{a: %{type: :integer}}}}}

      assert Processor.run(schema, %{"items" => ["notamap"]}, error_mode: :strict).items == [%{a: nil}]
    end

    test "processes a list of lists" do
      schema = %{matrix: %{type: {:list, {:list, :integer}}}}

      assert Processor.run(schema, %{"matrix" => [["1", "2"], ["3"]]}).matrix == [[1, 2], [3]]
    end

    test "takes the values of a map of items" do
      schema = %{tags: %{type: {:list, :string}}}

      assert Processor.run(schema, %{"tags" => %{"0" => "a", "1" => "b"}}).tags == ["a", "b"]
    end

    test "orders a map of items by its index keys" do
      schema = %{tags: %{type: {:list, :integer}}}
      params = %{"tags" => Map.new(0..11, fn index -> {to_string(index), to_string(index)} end)}

      assert Processor.run(schema, params).tags == Enum.to_list(0..11)
    end

    test "orders a map of items with integer keys" do
      schema = %{tags: %{type: {:list, :string}}}

      assert Processor.run(schema, %{"tags" => %{2 => "c", 10 => "a", 3 => "b"}}).tags == ["c", "b", "a"]
    end

    test "falls back to key order for non index keys" do
      schema = %{tags: %{type: {:list, :string}}}

      assert Processor.run(schema, %{"tags" => %{"b" => "second", "a" => "first"}}).tags == ["first", "second"]
    end

    test "returns an empty list for a param that is neither a list nor a map" do
      schema = %{tags: %{type: {:list, :string}}}

      assert Processor.run(schema, %{"tags" => "elixir"}).tags == []
    end

    test "reports required for a missing list" do
      schema = %{tags: %{type: {:list, :string}, required: true}}
      result = Processor.run(schema, %{}, error_mode: :strict)

      assert result._valid? == false
      assert {:error, ["required"]} = result.tags
    end

    test "applies the default for a missing list" do
      schema = %{tags: %{type: {:list, :string}, default: ["x"]}}

      assert Processor.run(schema, %{}).tags == ["x"]
    end

    test "processes a list of nested maps that carry errors" do
      schema = %{items: %{type: {:list, %{a: %{type: :integer}}}}}
      result = Processor.run(schema, %{"items" => [%{"a" => "1"}, %{"a" => "x"}]}, error_mode: :strict)

      assert [%{a: 1}, %{a: {:error, ["invalid integer"]}}] = result.items
      assert result._valid? == false
    end
  end

  describe "_valid? flag" do
    test "is true when every field passes" do
      schema = %{
        name: %{type: :string, required: true, validators: []},
        age: %{type: :integer, validators: [min: 18]}
      }

      result = Processor.run(schema, %{"name" => "John", "age" => "25"}, error_mode: :strict)

      assert result._valid? == true
    end

    test "is false when a field carries an error" do
      schema = %{
        name: %{type: :string, required: true, validators: []},
        age: %{type: :integer, validators: [min: 18]}
      }

      result = Processor.run(schema, %{"age" => "10"}, error_mode: :strict)

      assert result._valid? == false
      assert {:error, ["required"]} = result.name
      assert {:error, _} = result.age
    end

    test "is false when a nested field carries an error" do
      schema = %{
        user: %{
          type: %{
            name: %{type: :string, required: true, validators: []},
            email: %{type: :string, required: true, validators: []}
          }
        }
      }

      result = Processor.run(schema, %{"user" => %{"name" => "John"}}, error_mode: :strict)

      assert result._valid? == false
      assert result.user.name == "John"
      assert {:error, ["required"]} = result.user.email
    end

    test "is false when a list item carries an error" do
      schema = %{tags: %{type: {:list, :string}, validators: [min: 3]}}
      result = Processor.run(schema, %{"tags" => ["valid", "no"]}, error_mode: :strict)

      assert result._valid? == false
      assert ["valid", {:error, _}] = result.tags
    end

    test "is true in fallback mode even when a field failed" do
      schema = %{name: %{type: :string, required: true, validators: []}}

      assert Processor.run(schema, %{}, error_mode: :fallback)._valid? == true
    end

    test "is true in raise mode when nothing raised" do
      schema = %{name: %{type: :string}}

      assert Processor.run(schema, %{"name" => "John"}, error_mode: :raise)._valid? == true
    end

    test "is false when only a strict field failed among mixed modes" do
      schema = %{
        strict_field: %{type: :string, required: true, validators: [], error_mode: :strict},
        fallback_field: %{type: :string, default: "default", validators: [], error_mode: :fallback}
      }

      result = Processor.run(schema, %{}, error_mode: :strict)

      assert result._valid? == false
      assert {:error, ["required"]} = result.strict_field
      assert result.fallback_field == "default"
    end
  end
end
