defmodule Filtr.ErrorsTest do
  use ExUnit.Case, async: true

  alias Filtr.Errors

  describe "collect/1" do
    test "returns nil for a result without errors" do
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

      assert is_nil(Errors.collect(filtr_result))
    end

    test "returns nil for an empty result" do
      assert is_nil(Errors.collect(%{}))
    end

    test "returns the errors of a flat result" do
      filtr_result = %{
        correct: true,
        one: {:error, "error"},
        multiple: {:error, ["error1", "error2"]}
      }

      assert %{
               one: ["error"],
               multiple: ["error1", "error2"]
             } == Errors.collect(filtr_result)
    end

    test "returns the errors of a nested result" do
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
             } == Errors.collect(filtr_result)
    end

    test "returns the errors of a deeply nested result" do
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
             } == Errors.collect(filtr_result)
    end

    test "indexes the errors of a list of scalars" do
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
             } == Errors.collect(filtr_result)
    end

    test "indexes the errors of a list of maps" do
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
             } == Errors.collect(filtr_result)
    end

    test "indexes the errors of a list mixing maps and error tuples" do
      filtr_result = %{
        users: [
          %{id: 1, name: "jack"},
          {:error, "invalid map"},
          %{id: 3, name: {:error, "error"}}
        ]
      }

      assert %{
               users: %{
                 1 => ["invalid map"],
                 2 => %{name: ["error"]}
               }
             } == Errors.collect(filtr_result)
    end

    test "skips struct values instead of walking them" do
      filtr_result = %{
        published_at: ~U[2026-09-17 10:00:00Z],
        nested: %{on: ~D[2026-09-17], name: {:error, "error"}},
        dates: [~D[2026-09-17], {:error, "invalid date"}]
      }

      assert %{
               nested: %{name: ["error"]},
               dates: %{1 => ["invalid date"]}
             } == Errors.collect(filtr_result)
    end

    test "works on a real run result" do
      schema = %{
        name: %{type: :string, validators: [in: ["solid", "svelte"]]},
        age: %{type: :integer},
        tags: %{type: {:list, :string}}
      }

      correct_params = %{name: "solid", age: "21", tags: ["a", "b", "c"]}

      result = Filtr.run(schema, correct_params, error_mode: :strict)
      assert is_nil(Errors.collect(result))

      invalid_params = %{name: "something else", age: "are you sure?", tags: ["a", 1, "c", [1, 2]]}

      result = Filtr.run(schema, invalid_params, error_mode: :strict)

      assert %{
               age: ["invalid integer"],
               name: ["must be one of: solid, svelte"],
               tags: %{1 => ["invalid string"], 3 => ["invalid string"]}
             } == Errors.collect(result)
    end
  end
end
