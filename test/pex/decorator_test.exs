defmodule Pex.DecoratorTest do
  use ExUnit.Case
  use Decorator.Define, pex: 1

  # Import the pex decorator for testing
  import Pex.Decorator

  describe "pex decorator" do
    test "raises error when schema is missing" do
      assert_raise RuntimeError, "schema is required", fn ->
        # This would be caught at compile time, but we test the runtime error
        pex([], quote(do: :ok), %{args: [%{}, %{}]})
      end
    end

    test "generates correct quoted code for basic schema" do
      schema = Macro.escape(%{name: [type: :string]})
      opts = [schema: schema]
      body = quote do: {:ok, params}
      context = %{args: [Macro.escape(%{}), Macro.escape(%{})]}

      result = pex(opts, body, context)

      # The result should be a quoted expression that calls Pex.run
      assert match?({:__block__, _, _}, result)
    end

    test "includes error_mode option when provided" do
      schema = Macro.escape(%{name: [type: :string]})
      opts = [schema: schema, error_mode: :strict]
      body = quote do: {:ok, params}
      context = %{args: [Macro.escape(%{}), Macro.escape(%{})]}

      result = pex(opts, body, context)

      # Convert to string to check if error_mode: :strict is included
      result_string = Macro.to_string(result)
      assert String.contains?(result_string, "error_mode: :strict")
    end

    test "defaults error_mode to :fallback when not provided" do
      schema = Macro.escape(%{name: [type: :string]})
      opts = [schema: schema]
      body = quote do: {:ok, params}
      context = %{args: [Macro.escape(%{}), Macro.escape(%{})]}

      result = pex(opts, body, context)

      # Convert to string to check if error_mode: :fallback is included
      result_string = Macro.to_string(result)
      assert String.contains?(result_string, "error_mode: :fallback")
    end
  end

  # Test the actual decorator functionality with a test module
  defmodule TestController do
    use Pex.Decorator

    @decorate pex(
                error_mode: :strict,
                schema: %{
                  name: [type: :string, required: true],
                  age: [type: :integer, min: 18]
                }
              )
    def create(conn, params) do
      {:ok, conn, params}
    end

    @decorate pex(
                schema: %{
                  q: [type: :string, default: ""],
                  page: [type: :integer, default: 1, min: 1]
                }
              )
    def search(conn, params) do
      {:search, conn, params}
    end

    @decorate pex(
                error_mode: :strict,
                schema: %{
                  filter: [type: :string, default: "all"]
                }
              )
    def index(conn, params) do
      {:index, conn, params}
    end

    # Test with nested schema
    @decorate pex(
                error_mode: :strict,
                schema: %{
                  user: %{
                    name: [type: :string, required: true],
                    email: [type: :string, pattern: ~r/@/]
                  },
                  meta: %{
                    source: [type: :string, default: "web"]
                  }
                }
              )
    def update(conn, params) do
      {:update, conn, params}
    end
  end

  describe "decorator integration" do
    test "processes valid parameters correctly" do
      conn = %{test: "conn"}
      params = %{"name" => "John", "age" => "25"}

      assert {:ok, ^conn, %{name: "John", age: 25}} =
               TestController.create(conn, params)
    end

    test "handles invalid parameters in strict mode" do
      conn = %{test: "conn"}
      # Below minimum age
      params = %{"name" => "John", "age" => "15"}

      assert {:ok, ^conn, %{name: "John", age: {:error, ["must be at least 18"]}}} =
               TestController.create(conn, params)
    end

    test "handles missing required parameters" do
      conn = %{test: "conn"}
      # Missing required name
      params = %{"age" => "25"}

      assert {:ok, ^conn, %{name: {:error, ["required"]}, age: 25}} =
               TestController.create(conn, params)
    end

    test "uses defaults for missing parameters" do
      conn = %{test: "conn"}
      params = %{}

      assert {:index, ^conn, %{filter: "all"}} =
               TestController.index(conn, params)
    end

    test "processes parameters with error_mode: :fallback" do
      conn = %{test: "conn"}
      # Invalid page
      params = %{"q" => "search term", "page" => "invalid"}

      assert {:search, ^conn, %{q: "search term", page: 1}} =
               TestController.search(conn, params)
    end

    test "handles empty parameters with defaults in error_mode: :fallback" do
      conn = %{test: "conn"}
      params = %{}

      assert {:search, ^conn, %{q: "", page: 1}} =
               TestController.search(conn, params)
    end

    test "processes nested schemas correctly" do
      conn = %{test: "conn"}

      params = %{
        "user" => %{"name" => "John", "email" => "john@example.com"},
        "meta" => %{}
      }

      assert {:update, ^conn,
              %{
                user: %{name: "John", email: "john@example.com"},
                meta: %{source: "web"}
              }} = TestController.update(conn, params)
    end

    test "handles nested schema validation failure" do
      conn = %{test: "conn"}

      params = %{
        "user" => %{"name" => "John", "email" => "invalid-email"},
        "meta" => %{}
      }

      assert {:update, ^conn,
              %{
                meta: %{source: "web"},
                user: %{email: {:error, ["does not match pattern"]}, name: "John"}
              }} = TestController.update(conn, params)
    end

    test "handles missing nested required fields" do
      conn = %{test: "conn"}

      params = %{
        # Missing required name
        "user" => %{"email" => "john@example.com"},
        "meta" => %{}
      }

      assert {:update, ^conn,
              %{
                meta: %{source: "web"},
                user: %{name: {:error, ["required"]}, email: "john@example.com"}
              }} = TestController.update(conn, params)
    end
  end

  describe "multiple parameter types" do
    # Test a controller with various parameter types
    defmodule TypeTestController do
      use Pex.Decorator

      @decorate pex(
                  schema: %{
                    name: [type: :string],
                    age: [type: :integer],
                    height: [type: :float],
                    active: [type: :boolean],
                    birthday: [type: :date],
                    created_at: [type: :datetime],
                    tags: [type: :list],
                    scores: [type: {:list, :integer}]
                  }
                )
      def process_types(conn, params) do
        {:types, conn, params}
      end
    end

    test "processes all parameter types correctly" do
      conn = %{test: "conn"}

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

      assert {:types, ^conn,
              %{
                name: "John",
                age: 25,
                height: 5.9,
                active: true,
                birthday: ~D[1990-01-15],
                created_at: ~U[2023-12-25 10:30:00Z],
                tags: ["elixir", "phoenix", "web"],
                scores: [85, 92, 78]
              }} = TypeTestController.process_types(conn, params)
    end
  end
end
