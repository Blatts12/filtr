defmodule PexTest do
  use ExUnit.Case
  doctest Pex

  describe "run/2" do
    test "returns empty map for empty schema" do
      assert Pex.run(%{}, %{}) == %{}
    end

    test "processes simple string parameter" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}

      assert Pex.run(schema, params) == %{name: "John"}
    end

    test "processes simple integer parameter" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "25"}

      assert Pex.run(schema, params) == %{age: 25}
    end

    test "uses default values when parameter is missing" do
      schema = %{
        name: [type: :string, default: "Anonymous"],
        age: [type: :integer, default: 0]
      }

      params = %{}

      assert Pex.run(schema, params) == %{name: "Anonymous", age: 0}
    end

    test "processes multiple parameters" do
      schema = %{
        name: [type: :string],
        age: [type: :integer],
        active: [type: :boolean]
      }

      params = %{"name" => "John", "age" => "25", "active" => "true"}

      assert Pex.run(schema, params) == %{name: "John", age: 25, active: true}
    end

    test "supports atom keys in params" do
      schema = %{name: [type: :string]}
      params = %{name: "John"}

      assert Pex.run(schema, params) == %{name: "John"}
    end

    test "string keys take precedence over atom keys" do
      schema = %{name: [type: :string]}
      params = %{"name" => "String John", name: "Atom John"}

      assert Pex.run(schema, params) == %{name: "String John"}
    end

    test "handles nested schemas" do
      schema = %{
        user: %{
          name: [type: :string],
          age: [type: :integer]
        },
        settings: %{
          theme: [type: :string, default: "light"]
        }
      }

      params = %{
        "user" => %{"name" => "John", "age" => "25"},
        "settings" => %{}
      }

      expected = %{
        user: %{name: "John", age: 25},
        settings: %{theme: "light"}
      }

      assert Pex.run(schema, params) == expected
    end

    test "handles validation failure by including error in result" do
      schema = %{name: [type: :string, required: true]}
      params = %{}

      assert %{name: {:error, ["required"]}} = Pex.run(schema, params, error_mode: :strict)
    end

    test "handles casting failure by including error in result" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "not_a_number"}

      assert %{age: {:error, ["invalid integer"]}} = Pex.run(schema, params, error_mode: :strict)
    end
  end

  describe "run/3 with error_mode option" do
    test "returns defaults on validation failure when error_mode: :fallback" do
      schema = %{
        name: [type: :string, required: true, default: "Anonymous"],
        age: [type: :integer, default: 0]
      }

      params = %{}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result == %{name: "Anonymous", age: 0}
    end

    test "returns defaults on casting failure when error_mode: :fallback" do
      schema = %{
        age: [type: :integer, default: 18],
        score: [type: :float, default: 0.0]
      }

      params = %{"age" => "not_a_number", "score" => "invalid"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result == %{age: 18, score: 0.0}
    end

    test "returns nil for missing defaults when error_mode: :fallback" do
      schema = %{name: [type: :string, required: true]}
      params = %{}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result == %{name: nil}
    end

    test "processes valid parameters normally when error_mode: :fallback" do
      schema = %{
        name: [type: :string],
        age: [type: :integer]
      }

      params = %{"name" => "John", "age" => "25"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result == %{name: "John", age: 25}
    end

    test "raises ArgumentError on validation failure when error_mode: :raise" do
      schema = %{
        name: [type: :string, required: true],
        age: [type: :integer, min: 18]
      }

      params = %{}

      assert_raise ArgumentError, ~r/Validation failed/, fn ->
        Pex.run(schema, params, error_mode: :raise)
      end
    end

    test "raises ArgumentError on casting failure when error_mode: :raise" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "not_a_number"}

      assert_raise ArgumentError, ~r/Validation failed/, fn ->
        Pex.run(schema, params, error_mode: :raise)
      end
    end

    test "calls custom function when error_mode is function/2" do
      func = fn key, errors -> {key, errors} end

      schema = %{name: [type: :string, required: true]}
      params = %{}

      assert %{name: ["required"]} = Pex.run(schema, params, error_mode: func)
    end

    test "calls custom function when error_mode is function/3" do
      func = fn key, errors, params -> {key, [errors, params]} end

      schema = %{name: [type: :string, required: true]}
      params = %{}

      assert %{name: [["required"], %{}]} = Pex.run(schema, params, error_mode: func)
    end

    test "returns strict error tuples when error_mode: :strict" do
      schema = %{name: [type: :string, required: true]}
      params = %{}

      assert %{name: {:error, ["required"]}} = Pex.run(schema, params, error_mode: :strict)
    end

    test "error_mode defaults to :fallback when not specified" do
      schema = %{name: [type: :string, required: true, default: "Yes"]}
      params = %{}

      result_default = Pex.run(schema, params)
      result_explicit = Pex.run(schema, params, error_mode: :fallback)

      assert result_default == result_explicit
    end

    test "raises when invalid error_mode is specified" do
      schema = %{name: [type: :string, required: true]}
      params = %{}

      assert_raise RuntimeError, ~r/Invalid error mode/, fn ->
        Pex.run(schema, params, error_mode: :invalid)
      end
    end
  end

  describe "default value functions" do
    test "executes 0-arity default functions" do
      counter = Agent.start_link(fn -> 0 end)
      {:ok, pid} = counter

      default_fn = fn ->
        Agent.update(pid, &(&1 + 1))
        Agent.get(pid, & &1)
      end

      schema = %{count: [type: :integer, default: default_fn]}
      params = %{}

      result = Pex.run(schema, params)
      assert result == %{count: 1}

      Agent.stop(pid)
    end

    test "executes 1-arity default functions with key" do
      default_fn = fn key -> "default_#{key}" end

      schema = %{name: [type: :string, default: default_fn]}
      params = %{}

      result = Pex.run(schema, params)
      assert result == %{name: "default_name"}
    end

    test "executes 2-arity default functions with key and params" do
      default_fn = fn key, params ->
        user_id = Map.get(params, "user_id", "unknown")
        "#{key}_#{user_id}"
      end

      schema = %{session: [type: :string, default: default_fn]}
      params = %{"user_id" => "123"}

      result = Pex.run(schema, params)
      assert result == %{session: "session_123"}
    end
  end

  describe "empty_pex_params/0" do
    test "returns empty map" do
      assert Pex.empty_pex_params() == %{}
    end
  end

  describe "supported_types/0" do
    test "returns supported types" do
      assert match?([:string | _], Pex.supported_types())
    end
  end

  describe "type casting integration" do
    test "casts various types correctly" do
      schema = %{
        name: [type: :string],
        age: [type: :integer],
        height: [type: :float],
        active: [type: :boolean],
        birthday: [type: :date],
        created_at: [type: :datetime],
        tags: [type: :list],
        scores: [type: {:list, :integer}]
      }

      params = %{
        "name" => "John",
        "age" => "25",
        "height" => "5.9",
        "active" => "true",
        "birthday" => "1990-01-15",
        "created_at" => "2023-12-25T10:30:00Z",
        "tags" => "elixir,phoenix,web",
        "scores" => "85,92,78"
      }

      result = Pex.run(schema, params)

      assert result.name == "John"
      assert result.age == 25
      assert result.height == 5.9
      assert result.active == true
      assert result.birthday == ~D[1990-01-15]
      assert result.created_at == ~U[2023-12-25 10:30:00Z]
      assert result.tags == ["elixir", "phoenix", "web"]
      assert result.scores == [85, 92, 78]
    end
  end

  describe "validation integration" do
    test "validates string constraints" do
      schema = %{
        name: [type: :string, min: 2, max: 10],
        email: [type: :string, pattern: ~r/@/]
      }

      params = %{"name" => "John", "email" => "john@example.com"}

      result = Pex.run(schema, params)
      assert result == %{name: "John", email: "john@example.com"}
    end

    test "validates numeric constraints" do
      schema = %{
        age: [type: :integer, min: 18, max: 65],
        score: [type: :float, min: 0.0, max: 100.0]
      }

      params = %{"age" => "25", "score" => "85.5"}

      result = Pex.run(schema, params)
      assert result == %{age: 25, score: 85.5}
    end

    test "validates required fields" do
      schema = %{
        name: [type: :string, required: true],
        email: [type: :string, required: true]
      }

      params = %{"name" => "John", "email" => "john@example.com"}

      result = Pex.run(schema, params)
      assert result == %{name: "John", email: "john@example.com"}
    end

    test "validates custom validation functions" do
      email_validator = fn email ->
        if String.contains?(email, "@") and String.contains?(email, ".") do
          :ok
        else
          {:error, "invalid email format"}
        end
      end

      schema = %{
        email: [type: :string, validate: email_validator]
      }

      params = %{"email" => "john@example.com"}

      result = Pex.run(schema, params)
      assert result == %{email: "john@example.com"}
    end
  end

  describe "error handling edge cases" do
    test "handles multiple validation failures correctly" do
      schema = %{name: [type: :string, required: true, min: 10]}
      params = %{}

      assert %{name: {:error, ["required"]}} = Pex.run(schema, params, error_mode: :strict)
    end

    test "handles deeply nested schemas" do
      schema = %{
        user: %{
          profile: %{
            name: [type: :string, required: true],
            age: [type: :integer, min: 18]
          }
        }
      }

      params = %{
        "user" => %{
          "profile" => %{
            "name" => "John",
            "age" => "25"
          }
        }
      }

      result = Pex.run(schema, params)

      expected = %{
        user: %{
          profile: %{
            name: "John",
            age: 25
          }
        }
      }

      assert result == expected
    end

    test "handles nested schema with missing nested params" do
      schema = %{
        user: %{
          name: [type: :string, default: "Anonymous"],
          age: [type: :integer, default: 0]
        }
      }

      params = %{"user" => %{}}

      result = Pex.run(schema, params)

      expected = %{
        user: %{
          name: "Anonymous",
          age: 0
        }
      }

      assert result == expected
    end

    test "handles empty nested params" do
      schema = %{user: %{name: [type: :string, default: "Anonymous"]}}

      params = %{"user" => %{}}

      result = Pex.run(schema, params)
      expected = %{user: %{name: "Anonymous"}}
      assert result == expected
    end
  end

  describe "comprehensive error handling with error_mode" do
    test "multiple errors with error_mode: :fallback returns defaults" do
      schema = %{
        name: [type: :string, required: true, min: 10, default: "Default"],
        age: [type: :integer, min: 21, default: 18],
        score: [type: :float, default: 0.0]
      }

      params = %{"age" => "invalid", "score" => "bad"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result == %{name: "Default", age: 18, score: 0.0}
    end

    test "nested schema errors with error_mode: :fallback" do
      schema = %{
        user: %{
          name: [type: :string, required: true, default: "Anonymous"],
          age: [type: :integer, default: 0]
        }
      }

      params = %{"user" => %{"age" => "invalid"}}

      result = Pex.run(schema, params, error_mode: :fallback)

      expected = %{
        user: %{
          name: "Anonymous",
          age: 0
        }
      }

      assert result == expected
    end
  end

  describe "function defaults with error scenarios" do
    test "function defaults work correctly during errors" do
      counter_fn = fn -> System.system_time(:millisecond) end

      schema = %{
        id: [type: :integer, default: counter_fn],
        name: [type: :string, required: true, default: "Default"]
      }

      params = %{"id" => "invalid"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert is_integer(result.id)
      assert result.name == "Default"
    end

    test "2-arity function default during error" do
      key_params_fn = fn key, params ->
        prefix = Map.get(params, "prefix", "default")
        "#{prefix}_#{key}"
      end

      schema = %{
        generated: [type: :string, default: key_params_fn]
      }

      params = %{"generated" => 123, "prefix" => "test"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result.generated == "test_generated"
    end
  end
end
