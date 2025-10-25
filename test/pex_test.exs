defmodule PexTest do
  use ExUnit.Case, async: false

  describe "run/2 and run/3 basic behavior" do
    test "processes single field schema" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}

      result = Pex.run(schema, params)
      assert result.name == "John"
    end

    test "processes multiple fields in schema" do
      schema = %{
        name: [type: :string],
        age: [type: :integer]
      }

      params = %{name: "John", age: "25"}

      result = Pex.run(schema, params)
      assert result.name == "John"
      assert result.age == 25
    end

    test "handles missing params as nil" do
      schema = %{name: [type: :string]}
      params = %{}

      result = Pex.run(schema, params)
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

      result = Pex.run(schema, params)
      assert result.user.name == "John"
    end

    test "passes run_opts to nested schemas" do
      schema = %{
        user: %{
          name: [type: :string, validators: [required: true]]
        }
      }

      params = %{"user" => %{}}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.user.name
    end

    test "allows nested schema to override run_opts" do
      schema = %{
        user: %{
          name: [type: :string, validators: [required: true], error_mode: :fallback]
        }
      }

      params = %{"user" => %{}}

      result = Pex.run(schema, params, error_mode: :strict)
      assert result.user.name == nil
    end
  end

  describe "list handling" do
    test "processes list of simple types" do
      schema = %{tags: [type: {:list, :string}]}
      params = %{"tags" => ["elixir", "phoenix"]}

      result = Pex.run(schema, params)
      assert result.tags == ["elixir", "phoenix"]
    end

    test "processes list with type casting" do
      schema = %{scores: [type: {:list, :integer}]}
      params = %{"scores" => ["10", "20", "30"]}

      result = Pex.run(schema, params)
      assert result.scores == [10, 20, 30]
    end

    test "handles empty list" do
      schema = %{tags: [type: {:list, :string}]}
      params = %{"tags" => []}

      result = Pex.run(schema, params)
      assert result.tags == []
    end

    test "processes each list item with validators" do
      schema = %{tags: [type: {:list, :string}, validators: [min: 2]]}
      params = %{"tags" => ["elixir", "a", "phoenix"]}

      result = Pex.run(schema, params, error_mode: :strict)
      assert ["elixir", {:error, _}, "phoenix"] = result.tags
    end
  end

  describe "error mode: fallback" do
    test "returns default value on cast error" do
      schema = %{age: [type: :integer, validators: [default: 0]]}
      params = %{"age" => "invalid"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result.age == 0
    end

    test "returns nil on cast error without default" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "invalid"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result.age == nil
    end

    test "handles required field missing with default" do
      schema = %{name: [type: :string, validators: [required: true, default: "Guest"]]}
      params = %{}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result.name == "Guest"
    end

    test "handles required field missing without default" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result.name == nil
    end

    test "handles validation failure with default" do
      schema = %{age: [type: :integer, validators: [min: 18, default: 18]]}
      params = %{"age" => "10"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result.age == 18
    end
  end

  describe "error mode: strict" do
    test "returns error tuple on cast error" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "invalid"}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, _} = result.age
    end

    test "returns error on required field missing" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.name
    end

    test "returns valid value on success" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}

      result = Pex.run(schema, params, error_mode: :strict)
      assert result.name == "John"
    end

    test "returns validation errors" do
      schema = %{age: [type: :integer, validators: [min: 18]]}
      params = %{"age" => "10"}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, _} = result.age
    end

    test "uses default error mode from config when not specified" do
      original_mode = Application.get_env(:pex, :error_mode)

      Application.put_env(:pex, :error_mode, :strict)
      schema = %{age: [type: :integer, validators: [min: 18]]}
      params = %{"age" => "10"}

      result = Pex.run(schema, params)
      assert {:error, _} = result.age

      Application.put_env(:pex, :error_mode, original_mode)
    end
  end

  describe "error mode: raise" do
    test "raises on cast error" do
      schema = %{age: [type: :integer]}
      params = %{"age" => "invalid"}

      assert_raise RuntimeError, ~r/Invalid value for age/, fn ->
        Pex.run(schema, params, error_mode: :raise)
      end
    end

    test "raises on required field missing" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{}

      assert_raise RuntimeError, ~r/Invalid value for name: required/, fn ->
        Pex.run(schema, params, error_mode: :raise)
      end
    end

    test "returns valid value on success" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}

      result = Pex.run(schema, params, error_mode: :raise)
      assert result.name == "John"
    end

    test "raises on validation failure" do
      schema = %{age: [type: :integer, validators: [min: 18]]}
      params = %{"age" => "10"}

      assert_raise RuntimeError, ~r/Invalid value for age/, fn ->
        Pex.run(schema, params, error_mode: :raise)
      end
    end
  end

  describe "required fields and defaults" do
    test "applies static default value when param is missing" do
      schema = %{page: [type: :integer, validators: [default: 1]]}
      params = %{}

      result = Pex.run(schema, params)
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

      result = Pex.run(schema, params)
      assert result.timestamp == 12_345
    end

    test "does not apply default when param is provided" do
      schema = %{page: [type: :integer, validators: [default: 1]]}
      params = %{"page" => "2"}

      result = Pex.run(schema, params)
      assert result.page == 2
    end

    test "required field with nil value fails in strict mode" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{"name" => nil}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.name
    end

    test "required field with value succeeds" do
      schema = %{name: [type: :string, validators: [required: true]]}
      params = %{"name" => "John"}

      result = Pex.run(schema, params)
      assert result.name == "John"
    end
  end

  describe "custom cast functions" do
    test "processes custom cast function returning {:ok, value}" do
      custom_cast = fn value, _opts ->
        {:ok, String.upcase(value)}
      end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Pex.run(schema, params)
      assert result.name == "JOHN"
    end

    test "processes custom cast function returning plain value" do
      custom_cast = fn value, _opts ->
        String.upcase(value)
      end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Pex.run(schema, params)
      assert result.name == "JOHN"
    end

    test "handles custom cast function error in strict mode" do
      custom_cast = fn _value, _opts ->
        {:error, "custom error"}
      end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, ["custom error"]} = result.name
    end

    test "handles custom cast function returning error list" do
      custom_cast = fn _value, _opts ->
        {:error, ["error1", "error2"]}
      end

      schema = %{name: [type: custom_cast]}
      params = %{"name" => "john"}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, ["error1", "error2"]} = result.name
    end
  end

  describe "type passthrough" do
    test "processes :__none__ type as passthrough" do
      schema = %{data: [type: :__none__]}
      params = %{"data" => %{"key" => "value"}}

      result = Pex.run(schema, params)
      assert result.data == %{"key" => "value"}
    end

    test "processes nil type as passthrough" do
      schema = %{data: [type: nil]}
      params = %{"data" => "anything"}

      result = Pex.run(schema, params)
      assert result.data == "anything"
    end
  end

  describe "unsupported types" do
    test "returns error for unsupported type in strict mode" do
      schema = %{data: [type: :unsupported_type]}
      params = %{"data" => "value"}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, [error]} = result.data
      assert error =~ "unsupported type"
    end

    test "returns nil for unsupported type in fallback mode" do
      schema = %{data: [type: :unsupported_type]}
      params = %{"data" => "value"}

      result = Pex.run(schema, params, error_mode: :fallback)
      assert result.data == nil
    end

    test "raises for unsupported type in raise mode" do
      schema = %{data: [type: :unsupported_type]}
      params = %{"data" => "value"}

      assert_raise RuntimeError, ~r/unsupported type/, fn ->
        Pex.run(schema, params, error_mode: :raise)
      end
    end
  end

  describe "validator processing" do
    test "skips :default and :required in validation phase" do
      schema = %{
        name: [type: :string, validators: [required: true, default: "test", min: 2]]
      }

      params = %{"name" => "John"}

      result = Pex.run(schema, params)
      assert result.name == "John"
    end

    test "processes multiple validators" do
      schema = %{
        username: [type: :string, validators: [min: 3, max: 20]]
      }

      params = %{"username" => "john_doe"}

      result = Pex.run(schema, params)
      assert result.username == "john_doe"
    end

    test "collects multiple validation errors in strict mode" do
      schema = %{
        age: [type: :integer, validators: [min: 18, max: 10]]
      }

      params = %{"age" => "15"}

      result = Pex.run(schema, params, error_mode: :strict)
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
      result = Pex.run(schema, params, error_mode: :strict)
      assert result.name == nil
    end

    test "run_opts are used when field opts don't specify error_mode" do
      schema = %{
        name: [type: :string, validators: [required: true]]
      }

      params = %{}

      result = Pex.run(schema, params, error_mode: :strict)
      assert {:error, ["required"]} = result.name
    end
  end
end
