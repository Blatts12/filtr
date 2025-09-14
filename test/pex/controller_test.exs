defmodule Pex.ControllerTest do
  use ExUnit.Case, async: true

  defmodule TestController do
    use Pex.Controller

    param :name, :string, required: true
    param :age, :integer, min: 18

    def create(conn, params) do
      {conn, params}
    end

    param :q, :string, default: ""
    param :page, :integer, default: 1, min: 1

    def search(conn, params) do
      {conn, params}
    end

    param :category, :string, in: ["books", "movies"], default: "books"
    param :sort, :string, in: ["name", "date"], default: "name"

    def index(conn, params) do
      {conn, params}
    end

    # Function without params - should not be wrapped
    def show(conn, params) do
      {conn, params}
    end
  end

  defmodule StrictModeController do
    use Pex.Controller, error_mode: :strict

    param :name, :string, required: true

    def create(conn, params) do
      {conn, params}
    end
  end

  defmodule RaiseModeController do
    use Pex.Controller, error_mode: :raise

    param :name, :string, required: true

    def create(conn, params) do
      {conn, params}
    end
  end

  describe "macro" do
    test "controller functions are defined" do
      assert function_exported?(TestController, :create, 2)
      assert function_exported?(TestController, :search, 2)
      assert function_exported?(TestController, :index, 2)
      assert function_exported?(TestController, :show, 2)
    end
  end

  describe "parameter validation with fallback mode" do
    test "validates required parameters" do
      conn = %{}
      params = %{"name" => "John", "age" => "25"}

      {^conn, validated_params} = TestController.create(conn, params)

      assert validated_params.name == "John"
      assert validated_params.age == 25
    end

    test "applies default values" do
      conn = %{}
      params = %{}

      {^conn, validated_params} = TestController.search(conn, params)

      assert validated_params.q == ""
      assert validated_params.page == 1
    end

    test "validates constraints" do
      conn = %{}
      params = %{"page" => "2"}

      {^conn, validated_params} = TestController.search(conn, params)

      assert validated_params.page == 2
    end

    test "validates enum constraints" do
      conn = %{}
      params = %{"category" => "movies", "sort" => "date"}

      {^conn, validated_params} = TestController.index(conn, params)

      assert validated_params.category == "movies"
      assert validated_params.sort == "date"
    end

    test "falls back to defaults on invalid enum values" do
      conn = %{}
      params = %{"category" => "invalid", "sort" => "invalid"}

      {^conn, validated_params} = TestController.index(conn, params)

      assert validated_params.category == "books"
      assert validated_params.sort == "name"
    end

    test "functions without param definitions work normally" do
      conn = %{}
      params = %{"raw" => "data"}

      {^conn, ^params} = TestController.show(conn, params)
    end

    test "handles missing required parameters with fallback" do
      conn = %{}
      params = %{"age" => "25"}

      {^conn, validated_params} = TestController.create(conn, params)

      # In fallback mode, missing required params should get default values
      assert Map.has_key?(validated_params, :name)
      assert validated_params.age == 25
    end
  end

  describe "strict error mode" do
    test "works with valid parameters" do
      conn = %{}
      params = %{"name" => "John"}

      {^conn, validated_params} = StrictModeController.create(conn, params)

      assert validated_params.name == "John"
    end

    test "returns tuple with error with invalid parameters" do
      conn = %{}
      params = %{"age" => "25"}

      {^conn, errored_params} = StrictModeController.create(conn, params)

      assert errored_params.name == {:error, ["required"]}
    end
  end

  describe "raise error mode" do
    test "works with valid parameters" do
      conn = %{}
      params = %{"name" => "John"}

      {^conn, validated_params} = RaiseModeController.create(conn, params)

      assert validated_params.name == "John"
    end

    test "raises with invalid parameters" do
      conn = %{}
      params = %{"age" => "25"}

      assert_raise ArgumentError, "Validation failed for name: required", fn ->
        RaiseModeController.create(conn, params)
      end
    end
  end

  describe "render module" do
    test "renders without params" do
      module =
        defmodule TestFallbackController do
          use Pex.Controller, error_mode: :fallback
        end

      assert {_, _, _, :ok} = module
    end

    test "renders with params" do
      module =
        defmodule TestFallbackParamController do
          use Pex.Controller, error_mode: :fallback

          param :user, :string, required: true

          def test(conn, params) do
            {conn, params}
          end
        end

      assert {_, _, _, {:test, 2}} = module
    end

    test "renders and ignores param without function" do
      module =
        defmodule TestFallbackNoParamController do
          use Pex.Controller, error_mode: :fallback

          param :user, :string, required: true
        end

      assert {_, _, _, :ok} = module
    end

    test "raises on invalid error mode" do
      assert_raise ArgumentError, fn ->
        defmodule TestInvalidErrorModeController do
          use Pex.Controller, error_mode: :invalid
        end
      end
    end
  end
end
