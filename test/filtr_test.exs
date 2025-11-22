defmodule FiltrTest do
  use ExUnit.Case, async: false

  describe "run/2 and run/3 basic behavior" do
    test "processes single field schema" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}

      result = Filtr.run(schema, params)
      assert result.name == "John"
    end

    test "processes multiple fields in schema" do
      schema = %{
        name: [type: :string],
        age: [type: :integer]
      }

      params = %{name: "John", age: "25"}

      result = Filtr.run(schema, params)
      assert result.name == "John"
      assert result.age == 25
    end

    test "handles missing params as nil" do
      schema = %{name: [type: :string]}
      params = %{}

      result = Filtr.run(schema, params)
      assert result.name == nil
    end
  end

  describe "nested schemas" do
    test "processes nested map schema" do
      schema = %{
        user: %{
          name: [type: :string]
        }
      }

      params = %{
        "user" => %{
          "name" => "John"
        }
      }

      result = Filtr.run(schema, params)
      assert result.user.name == "John"
    end

    test "passes run_opts to nested schemas" do
      schema = %{
        user: %{
          name: [type: :string, validators: [required: true]]
        }
      }

      params = %{"user" => %{}}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.user.name
    end

    test "allows nested schema to override run_opts" do
      schema = %{
        user: %{
          name: [type: :string, validators: [required: true], error_mode: :fallback]
        }
      }

      params = %{"user" => %{}}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result.user.name == nil
    end
  end

  describe "list handling" do
    test "processes list of simple types" do
      schema = %{tags: [type: {:list, :string}]}
      params = %{"tags" => ["elixir", "phoenix"]}

      result = Filtr.run(schema, params)
      assert result.tags == ["elixir", "phoenix"]
    end

    test "processes list with type casting" do
      schema = %{scores: [type: {:list, :integer}]}
      params = %{"scores" => ["10", "20", "30"]}

      result = Filtr.run(schema, params)
      assert result.scores == [10, 20, 30]
    end

    test "handles empty list" do
      schema = %{tags: [type: {:list, :string}]}
      params = %{"tags" => []}

      result = Filtr.run(schema, params)
      assert result.tags == []
    end

    test "processes each list item with validators" do
      schema = %{tags: [type: {:list, :string}, validators: [min: 2]]}
      params = %{"tags" => ["elixir", "a", "phoenix"]}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert ["elixir", {:error, _}, "phoenix"] = result.tags
    end

    test "processes list of nested map schemas" do
      schema = %{
        items: [
          type: {
            :list,
            %{
              name: [type: :string],
              quantity: [type: :integer]
            }
          }
        ]
      }

      params = %{
        "items" => [
          %{
            "name" => "Product A",
            "quantity" => "5"
          }
        ]
      }

      result = Filtr.run(schema, params)
      assert [item] = result.items
      assert item.name == "Product A"
      assert item.quantity == 5
    end
  end

  describe "error mode: fallback" do
    test "returns default value on cast error" do
      schema = %{age: [type: :integer, validators: [default: 0]]}
      params = %{"age" => "invalid"}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert result.age == 0
    end

    test "returns nil on cast error without default" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "invalid"}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert result.age == nil
    end

    test "handles required field missing with default" do
      schema = %{name: [type: :string, validators: [required: true, default: "Guest"]]}
      params = %{}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert result.name == "Guest"
    end

    test "handles required field missing without default" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert result.name == nil
    end

    test "handles validation failure with default" do
      schema = %{age: [type: :integer, validators: [min: 18, default: 18]]}
      params = %{"age" => "10"}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert result.age == 18
    end
  end

  describe "error mode: strict" do
    test "returns error tuple on cast error" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "invalid"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, _} = result.age
    end

    test "returns error on required field missing" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.name
    end

    test "returns valid value on success" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result.name == "John"
    end

    test "returns validation errors" do
      schema = %{age: [type: :integer, validators: [min: 18]]}
      params = %{"age" => "10"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, _} = result.age
    end

    test "uses default error mode from config when not specified" do
      original_mode = Application.get_env(:filtr, :error_mode)

      Application.put_env(:filtr, :error_mode, :strict)
      schema = %{age: [type: :integer, validators: [min: 18]]}
      params = %{"age" => "10"}

      result = Filtr.run(schema, params)
      assert {:error, _} = result.age

      Application.put_env(:filtr, :error_mode, original_mode)
    end
  end

  describe "error mode: raise" do
    test "raises on cast error" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "invalid"}

      assert_raise RuntimeError, ~r/Invalid value for age/, fn ->
        Filtr.run(schema, params, error_mode: :raise)
      end
    end

    test "raises on required field missing" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{}

      assert_raise RuntimeError, ~r/Invalid value for name: required/, fn ->
        Filtr.run(schema, params, error_mode: :raise)
      end
    end

    test "returns valid value on success" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}

      result = Filtr.run(schema, params, error_mode: :raise)
      assert result.name == "John"
    end

    test "raises on validation failure" do
      schema = %{age: [type: :integer, validators: [min: 18]]}
      params = %{"age" => "10"}

      assert_raise RuntimeError, ~r/Invalid value for age/, fn ->
        Filtr.run(schema, params, error_mode: :raise)
      end
    end
  end

  describe "required fields and defaults" do
    test "applies static default value when param is missing" do
      schema = %{page: [type: :integer, validators: [default: 1]]}
      params = %{}

      result = Filtr.run(schema, params)
      assert result.page == 1
    end

    test "applies function default when param is missing" do
      schema = %{
        timestamp: [
          type: :integer,
          validators: [default: fn -> 12_345 end]
        ]
      }

      params = %{}

      result = Filtr.run(schema, params)
      assert result.timestamp == 12_345
    end

    test "does not apply default when param is provided" do
      schema = %{page: [type: :integer, validators: [default: 1]]}
      params = %{"page" => "2"}

      result = Filtr.run(schema, params)
      assert result.page == 2
    end

    test "required field with nil value fails in strict mode" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{"name" => nil}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.name
    end

    test "required field with value succeeds" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{"name" => "John"}

      result = Filtr.run(schema, params)
      assert result.name == "John"
    end
  end

  describe "custom cast functions" do
    test "processes custom cast function returning {:ok, value}" do
      custom_cast = fn value, _opts -> {:ok, String.upcase(value)} end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params)
      assert result.name == "JOHN"
    end

    test "processes custom cast function returning plain value" do
      custom_cast = fn value, _opts -> String.upcase(value) end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params)
      assert result.name == "JOHN"
    end

    test "handles custom cast function error in strict mode" do
      custom_cast = fn _value, _opts -> {:error, "custom error"} end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["custom error"]} = result.name
    end

    test "handles custom cast function returning error list" do
      custom_cast = fn _value, _opts -> {:error, ["error1", "error2"]} end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["error1", "error2"]} = result.name
    end
  end

  describe "custom validate functions" do
    test "processes custom validation function returning true" do
      custom_validator = fn value -> String.length(value) > 2 end

      schema = %{name: [type: :string, validators: [custom: custom_validator]]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params)
      assert result.name == "john"
    end

    test "processes custom validation function returning :ok" do
      custom_validator = fn value -> if String.length(value) > 2, do: :ok, else: :error end

      schema = %{name: [type: :string, validators: [custom: custom_validator]]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params)
      assert result.name == "john"
    end

    test "processes custom validation function returning {:ok, _}" do
      custom_validator = fn value ->
        if String.length(value) > 2, do: {:ok, value}, else: {:error, "too short"}
      end

      schema = %{name: [type: :string, validators: [custom: custom_validator]]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params)
      assert result.name == "john"
    end

    test "handles custom validation function returning false error value" do
      custom_validator = fn value -> String.length(value) > 10 end

      schema = %{name: [type: :string, validators: [custom: custom_validator]]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["invalid value"]} = result.name
    end

    test "handles custom validation function returning :error error value" do
      custom_validator = fn value -> if String.length(value) > 10, do: :ok, else: :error end

      schema = %{name: [type: :string, validators: [custom: custom_validator]]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["invalid value"]} = result.name
    end

    test "handles custom validation function returning {:error, error} error value" do
      custom_validator = fn value ->
        if String.length(value) > 10 do
          :ok
        else
          {:error, "must be longer than 10 characters"}
        end
      end

      schema = %{name: [type: :string, validators: [custom: custom_validator]]}
      params = %{"name" => "john"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["must be longer than 10 characters"]} = result.name
    end

    test "returns only unique errors" do
      validator1 = fn _value -> {:error, "too short"} end
      validator2 = fn _value -> {:error, "too short"} end
      validator3 = fn _value -> {:error, "invalid format"} end

      schema = %{
        name: [
          type: :string,
          validators: [
            custom: validator1,
            custom: validator2,
            custom: validator3
          ]
        ]
      }

      params = %{"name" => "ab"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["too short", "invalid format"]} = result.name
    end
  end

  describe "type passthrough" do
    test "processes :__none__ type as passthrough" do
      schema = %{data: [type: :__none__]}
      params = %{"data" => %{"key" => "value"}}

      result = Filtr.run(schema, params)
      assert result.data == %{"key" => "value"}
    end

    test "processes nil type as passthrough" do
      schema = %{data: [type: nil]}
      params = %{"data" => "anything"}

      result = Filtr.run(schema, params)
      assert result.data == "anything"
    end
  end

  describe "unsupported types" do
    test "returns error for unsupported type in strict mode" do
      schema = %{data: [type: :unsupported_type]}
      params = %{"data" => "value"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, [error]} = result.data
      assert error =~ "unsupported type"
    end

    test "returns nil for unsupported type in fallback mode" do
      schema = %{data: [type: :unsupported_type]}
      params = %{"data" => "value"}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert result.data == nil
    end

    test "raises for unsupported type in raise mode" do
      schema = %{data: [type: :unsupported_type]}
      params = %{"data" => "value"}

      assert_raise RuntimeError, ~r/unsupported type/, fn ->
        Filtr.run(schema, params, error_mode: :raise)
      end
    end
  end

  describe "validator processing" do
    test "skips :default and :required in validation phase" do
      schema = %{
        name: [type: :string, validators: [required: true, default: "test", min: 2]]
      }

      params = %{"name" => "John"}

      result = Filtr.run(schema, params)
      assert result.name == "John"
    end

    test "processes multiple validators" do
      schema = %{
        username: [type: :string, validators: [min: 3, max: 20]]
      }

      params = %{"username" => "john_doe"}

      result = Filtr.run(schema, params)
      assert result.username == "john_doe"
    end

    test "collects multiple validation errors in strict mode" do
      schema = %{
        age: [type: :integer, validators: [min: 18, max: 10]]
      }

      params = %{"age" => "15"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, [_, _]} = result.age
    end
  end

  describe "opts merging" do
    test "schema opts override run_opts for individual fields" do
      schema = %{
        name: [type: :string, validators: [required: true], error_mode: :fallback]
      }

      params = %{}

      # Run with strict, but field uses fallback
      result = Filtr.run(schema, params, error_mode: :strict)
      assert result.name == nil
    end

    test "run_opts are used when field opts don't specify error_mode" do
      schema = %{
        name: [type: :string, validators: [required: true]]
      }

      params = %{}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.name
    end
  end

  describe "error mode per field" do
    test "allows mixing error modes across multiple fields" do
      schema = %{
        email: [type: :string, validators: [required: true, pattern: ~r/@/], error_mode: :strict],
        age: [type: :integer, validators: [min: 18, default: 18], error_mode: :fallback],
        id: [type: :integer, validators: [required: true], error_mode: :raise]
      }

      params = %{"email" => "invalid", "age" => "10"}

      # id field with :raise should raise
      assert_raise RuntimeError, ~r/Invalid value for id: required/, fn ->
        Filtr.run(schema, params)
      end
    end

    test "strict mode field returns error tuple while fallback field returns default" do
      schema = %{
        email: [type: :string, validators: [required: true], error_mode: :strict],
        optional_field: [type: :string, validators: [default: "default"], error_mode: :fallback]
      }

      params = %{}

      result = Filtr.run(schema, params)
      assert {:error, ["required"]} = result.email
      assert result.optional_field == "default"
    end

    test "fallback field ignores global strict mode" do
      schema = %{
        critical: [type: :integer, validators: [required: true]],
        optional: [type: :integer, validators: [default: 0], error_mode: :fallback]
      }

      params = %{"critical" => "10", "optional" => "invalid"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result.critical == 10
      assert result.optional == 0
    end

    test "strict field overrides global fallback mode" do
      schema = %{
        critical: [type: :integer, validators: [required: true], error_mode: :strict],
        optional: [type: :string, validators: [default: "default"]]
      }

      params = %{"optional" => "value"}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert {:error, ["required"]} = result.critical
      assert result.optional == "value"
    end

    test "raise field overrides global strict mode" do
      schema = %{
        critical: [type: :integer, validators: [required: true], error_mode: :raise],
        optional: [type: :string, validators: [default: "default"]]
      }

      params = %{"optional" => "value"}

      assert_raise RuntimeError, ~r/Invalid value for critical: required/, fn ->
        Filtr.run(schema, params, error_mode: :strict)
      end
    end

    test "field error mode works with validation errors" do
      schema = %{
        strict_field: [type: :integer, validators: [min: 18], error_mode: :strict],
        fallback_field: [type: :integer, validators: [min: 18, default: 18], error_mode: :fallback]
      }

      params = %{"strict_field" => "10", "fallback_field" => "10"}

      result = Filtr.run(schema, params)
      assert {:error, ["must be at least 18"]} = result.strict_field
      assert result.fallback_field == 18
    end

    test "field error mode works with cast errors" do
      schema = %{
        strict_field: [type: :integer, error_mode: :strict],
        fallback_field: [type: :integer, validators: [default: 0], error_mode: :fallback]
      }

      params = %{"strict_field" => "not_an_int", "fallback_field" => "not_an_int"}

      result = Filtr.run(schema, params)
      assert {:error, ["invalid integer"]} = result.strict_field
      assert result.fallback_field == 0
    end

    test "field error mode works with nested schemas" do
      schema = %{
        user: %{
          name: [type: :string, validators: [required: true], error_mode: :strict],
          age: [type: :integer, validators: [default: 0], error_mode: :fallback]
        }
      }

      params = %{"user" => %{"age" => "invalid"}}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert {:error, ["required"]} = result.user.name
      assert result.user.age == 0
    end

    test "all fields use same custom error mode when specified" do
      schema = %{
        field1: [type: :string, validators: [required: true], error_mode: :strict],
        field2: [type: :string, validators: [required: true], error_mode: :strict],
        field3: [type: :string, validators: [required: true], error_mode: :strict]
      }

      params = %{}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert {:error, ["required"]} = result.field1
      assert {:error, ["required"]} = result.field2
      assert {:error, ["required"]} = result.field3
    end

    test "field error mode overrides config default" do
      original_mode = Application.get_env(:filtr, :error_mode)

      Application.put_env(:filtr, :error_mode, :strict)

      schema = %{
        field: [type: :string, validators: [required: true, default: "default"], error_mode: :fallback]
      }

      params = %{}

      result = Filtr.run(schema, params)
      assert result.field == "default"

      Application.put_env(:filtr, :error_mode, original_mode)
    end
  end

  describe "_valid? field" do
    test "sets _valid? to true when all params are valid" do
      schema = %{
        name: [type: :string, validators: [required: true]],
        age: [type: :integer, validators: [min: 18]]
      }

      params = %{"name" => "John", "age" => "25"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result._valid? == true
      assert result.name == "John"
      assert result.age == 25
    end

    test "sets _valid? to false when params have errors" do
      schema = %{
        name: [type: :string, validators: [required: true]],
        age: [type: :integer, validators: [min: 18]]
      }

      params = %{"age" => "10"}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result._valid? == false
      assert {:error, ["required"]} = result.name
      assert {:error, _} = result.age
    end

    test "sets _valid? to false when nested params have errors" do
      schema = %{
        user: %{
          name: [type: :string, validators: [required: true]],
          email: [type: :string, validators: [required: true]]
        }
      }

      params = %{"user" => %{"name" => "John"}}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result._valid? == false
      assert result.user.name == "John"
      assert {:error, ["required"]} = result.user.email
    end

    test "sets _valid? to false when list items have errors" do
      schema = %{
        tags: [type: {:list, :string}, validators: [min: 3]]
      }

      params = %{"tags" => ["valid", "no"]}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result._valid? == false
      assert ["valid", {:error, _}] = result.tags
    end

    test "sets _valid? to true in fallback mode" do
      schema = %{
        name: [type: :string, validators: [required: true]]
      }

      params = %{}

      result = Filtr.run(schema, params, error_mode: :fallback)
      assert result._valid? == true
    end

    test "sets _valid? to true in raise mode" do
      schema = %{
        name: [type: :string]
      }

      params = %{"name" => "John"}

      result = Filtr.run(schema, params, error_mode: :raise)
      assert result._valid? == true
    end

    test "_valid? works with mixed field error modes" do
      schema = %{
        strict_field: [type: :string, validators: [required: true], error_mode: :strict],
        fallback_field: [type: :string, validators: [default: "default"], error_mode: :fallback]
      }

      params = %{}

      result = Filtr.run(schema, params, error_mode: :strict)
      assert result._valid? == false
      assert {:error, ["required"]} = result.strict_field
      assert result.fallback_field == "default"
    end
  end

  describe "collect_errors/1" do
    test "returns nil for filtr result without errors" do
      filtr_result = %{
        solid: "best framework",
        frameworks: ["react", "solid", "vue", "svelte"],
        user: %{
          name: "Jakub",
          authorized: true,
          articles: [
            %{id: 1, title: "Good Luck", tags: ["game", "stock"], likes: []},
            %{id: 2, title: "Have Fun", tags: [], likes: [%{id: 1, by: "john.price"}]}
          ]
        }
      }

      assert is_nil(Filtr.collect_errors(filtr_result))
    end

    test "returns errors for simple filtr result with errors" do
      filtr_result = %{
        correct: true,
        one: {:error, "error"},
        multiple: {:error, ["error1", "error2"]}
      }

      assert %{
               one: ["error"],
               multiple: ["error1", "error2"]
             } == Filtr.collect_errors(filtr_result)
    end

    test "returns errors for nested filtr result with errors" do
      filtr_result = %{
        correct: true,
        error_nested: %{
          correct: "true",
          one: {:error, "error"},
          multiple: {:error, ["error1", "error2"]}
        }
      }

      assert %{
               error_nested: %{
                 one: ["error"],
                 multiple: ["error1", "error2"]
               }
             } == Filtr.collect_errors(filtr_result)
    end

    test "returns errors for multiple nested filtr result with errors" do
      filtr_result = %{
        correct: true,
        one: %{
          correct: "true",
          two: %{
            correct: 1,
            three: %{
              correct: %{correct: [1, 2, 3]},
              one: {:error, "error"},
              multiple: {:error, ["error1", "error2"]}
            }
          }
        }
      }

      assert %{
               one: %{
                 two: %{
                   three: %{
                     one: ["error"],
                     multiple: ["error1", "error2"]
                   }
                 }
               }
             } == Filtr.collect_errors(filtr_result)
    end

    test "returns errors for list filtr result with errors" do
      filtr_result = %{
        correct: true,
        error_nested: %{
          correct: "true",
          list_with_errors: [1, {:error, "error"}, 2, {:error, ["error1", "error2"]}]
        }
      }

      assert %{
               error_nested: %{
                 list_with_errors: %{
                   1 => ["error"],
                   3 => ["error1", "error2"]
                 }
               }
             } == Filtr.collect_errors(filtr_result)
    end

    test "returns errors for in list nested filtr result with errors" do
      filtr_result = %{
        users: [
          %{id: 1, name: "jack"},
          %{id: 2, name: {:error, "error"}},
          %{id: 3, name: {:error, ["error1", "error2"]}}
        ]
      }

      assert %{
               users: %{
                 1 => %{name: ["error"]},
                 2 => %{name: ["error1", "error2"]}
               }
             } == Filtr.collect_errors(filtr_result)
    end

    test "flow with schema and validation" do
      schema = %{
        name: [type: :string, validators: [in: ["solid", "svelte"]]],
        age: [type: :integer],
        tags: [type: {:list, :string}]
      }

      correct_params = %{
        name: "solid",
        age: "21",
        tags: ["a", "b", "c"]
      }

      result = Filtr.run(schema, correct_params, error_mode: :strict)
      assert is_nil(Filtr.collect_errors(result))

      invalid_params = %{
        name: "something else",
        age: "are you sure?",
        tags: ["a", 1, "c", [1, 2]]
      }

      result = Filtr.run(schema, invalid_params, error_mode: :strict)

      assert %{
               age: ["invalid integer"],
               name: ["must be one of: solid, svelte"],
               tags: %{1 => ["invalid string"], 3 => ["invalid string"]}
             } == Filtr.collect_errors(result)
    end
  end
end
