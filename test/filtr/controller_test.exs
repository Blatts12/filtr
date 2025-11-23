defmodule Filtr.ControllerTest do
  use ExUnit.Case, async: true

  defmodule TestController do
    use Filtr.Controller

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
    use Filtr.Controller, error_mode: :strict

    param :name, :string, required: true

    def create(conn, params) do
      {conn, params}
    end
  end

  defmodule RaiseModeController do
    use Filtr.Controller, error_mode: :raise

    param :name, :string, required: true

    def create(conn, params) do
      {conn, params}
    end
  end

  defmodule FieldErrorModeController do
    use Filtr.Controller, error_mode: :raise

    param :name, :string, required: true, error_mode: :fallback

    def create(conn, params) do
      {conn, params}
    end
  end

  defmodule NestedSchemaController do
    use Filtr.Controller

    param :user do
      param :name, :string, required: true
      param :age, :integer, min: 18
    end

    def create(conn, params) do
      {conn, params}
    end

    param :filter do
      param :category, :string, in: ["books", "movies"], default: "books"
      param :sort, :string, default: "name"
    end

    def search(conn, params) do
      {conn, params}
    end
  end

  defmodule MixedSchemaController do
    use Filtr.Controller

    param :name, :string, required: true

    param :settings do
      param :theme, :string, default: "light"
      param :notifications, :boolean, default: true
    end

    def update(conn, params) do
      {conn, params}
    end
  end

  defmodule DoubleNestedSchemaController do
    use Filtr.Controller

    param :user do
      param :name, :string, required: true

      param :address do
        param :street, :string, default: ""
        param :city, :string, required: true
        param :postal_code, :string, default: ""
      end
    end

    def create(conn, params) do
      {conn, params}
    end

    param :company do
      param :name, :string, required: true

      param :headquarters do
        param :country, :string, default: "US"

        param :contact do
          param :email, :string, required: true
          param :phone, :string, default: ""
        end
      end
    end

    def register(conn, params) do
      {conn, params}
    end
  end

  defmodule EmptyNestedSchemaController do
    use Filtr.Controller

    param :name, :string, required: true

    param :user do
    end

    def create(conn, params) do
      {conn, params}
    end
  end

  defmodule ListNestedSchemaController do
    use Filtr.Controller

    param :users, :list do
      param :name, :string, required: true
      param :age, :integer, min: 18
    end

    def create(conn, params) do
      {conn, params}
    end

    param :tags, :list do
      param :label, :string, default: "default"
      param :color, :string, in: ["red", "blue", "green"], default: "blue"
    end

    def update(conn, params) do
      {conn, params}
    end

    param :title, :string, required: true

    param :items, :list do
      param :name, :string, required: true
      param :quantity, :integer, min: 1, default: 1
    end

    def order(conn, params) do
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

      assert_raise RuntimeError, "Invalid value for name: required", fn ->
        RaiseModeController.create(conn, params)
      end
    end
  end

  describe "error mode per field" do
    test "doesn't raise with missing parameters" do
      conn = %{}

      {^conn, validated_params} = FieldErrorModeController.create(conn, %{})
      assert is_nil(validated_params.name)
    end
  end

  describe "nested schema" do
    test "validates nested parameters" do
      conn = %{}
      params = %{"user" => %{"name" => "John", "age" => "25"}}

      {^conn, validated_params} = NestedSchemaController.create(conn, params)

      assert validated_params.user.name == "John"
      assert validated_params.user.age == 25
    end

    test "applies defaults to nested parameters" do
      conn = %{}
      params = %{"filter" => %{}}

      {^conn, validated_params} = NestedSchemaController.search(conn, params)

      assert validated_params.filter.category == "books"
      assert validated_params.filter.sort == "name"
    end

    test "validates nested enum constraints" do
      conn = %{}
      params = %{"filter" => %{"category" => "movies", "sort" => "date"}}

      {^conn, validated_params} = NestedSchemaController.search(conn, params)

      assert validated_params.filter.category == "movies"
      assert validated_params.filter.sort == "date"
    end

    test "handles missing nested object with fallback" do
      conn = %{}
      params = %{}

      {^conn, validated_params} = NestedSchemaController.create(conn, params)

      # In fallback mode, missing nested params should get a map with defaults
      assert is_nil(validated_params.user.name)
      assert is_nil(validated_params.user.age)
    end

    test "validates constraints on nested parameters" do
      conn = %{}
      params = %{"user" => %{"name" => "John", "age" => "16"}}

      {^conn, validated_params} = NestedSchemaController.create(conn, params)

      # Age is below min (18), should fallback
      assert validated_params.user.name == "John"
      assert is_nil(validated_params.user.age)
    end
  end

  describe "mixed flat and nested schema" do
    test "validates both flat and nested parameters" do
      conn = %{}
      params = %{"name" => "John", "settings" => %{"theme" => "dark", "notifications" => "false"}}

      {^conn, validated_params} = MixedSchemaController.update(conn, params)

      assert validated_params.name == "John"
      assert validated_params.settings.theme == "dark"
      assert validated_params.settings.notifications == false
    end

    test "applies defaults to nested while validating flat" do
      conn = %{}
      params = %{"name" => "John", "settings" => %{}}

      {^conn, validated_params} = MixedSchemaController.update(conn, params)

      assert validated_params.name == "John"
      assert validated_params.settings.theme == "light"
      assert validated_params.settings.notifications == true
    end

    test "handles missing nested object in mixed schema" do
      conn = %{}
      params = %{"name" => "John"}

      {^conn, validated_params} = MixedSchemaController.update(conn, params)

      assert validated_params.name == "John"
      assert is_map(validated_params.settings)
      assert validated_params.settings.theme == "light"
    end
  end

  describe "double nested schema" do
    test "validates double nested parameters" do
      conn = %{}

      params = %{
        "user" => %{
          "name" => "John",
          "address" => %{
            "street" => "Main St",
            "city" => "New York",
            "postal_code" => "10001"
          }
        }
      }

      {^conn, validated_params} = DoubleNestedSchemaController.create(conn, params)

      assert validated_params.user.name == "John"
      assert validated_params.user.address.street == "Main St"
      assert validated_params.user.address.city == "New York"
      assert validated_params.user.address.postal_code == "10001"
    end

    test "applies defaults to double nested parameters" do
      conn = %{}

      params = %{
        "user" => %{
          "name" => "John",
          "address" => %{
            "city" => "New York"
          }
        }
      }

      {^conn, validated_params} = DoubleNestedSchemaController.create(conn, params)

      assert validated_params.user.name == "John"
      assert validated_params.user.address.street == ""
      assert validated_params.user.address.city == "New York"
      assert validated_params.user.address.postal_code == ""
    end

    test "validates all fields in double nested parameters" do
      conn = %{}

      params = %{
        "user" => %{
          "name" => "John",
          "address" => %{
            "street" => "123 Main St",
            "city" => "New York",
            "postal_code" => "12345"
          }
        }
      }

      {^conn, validated_params} = DoubleNestedSchemaController.create(conn, params)

      assert validated_params.user.name == "John"
      assert validated_params.user.address.street == "123 Main St"
      assert validated_params.user.address.city == "New York"
      assert validated_params.user.address.postal_code == "12345"
    end

    test "validates triple nested parameters" do
      conn = %{}

      params = %{
        "company" => %{
          "name" => "Acme Corp",
          "headquarters" => %{
            "country" => "UK",
            "contact" => %{
              "email" => "info@acme.com",
              "phone" => "+44-123-456"
            }
          }
        }
      }

      {^conn, validated_params} = DoubleNestedSchemaController.register(conn, params)

      assert validated_params.company.name == "Acme Corp"
      assert validated_params.company.headquarters.country == "UK"
      assert validated_params.company.headquarters.contact.email == "info@acme.com"
      assert validated_params.company.headquarters.contact.phone == "+44-123-456"
    end

    test "applies defaults to triple nested parameters" do
      conn = %{}

      params = %{
        "company" => %{
          "name" => "Acme Corp",
          "headquarters" => %{
            "contact" => %{
              "email" => "info@acme.com"
            }
          }
        }
      }

      {^conn, validated_params} = DoubleNestedSchemaController.register(conn, params)

      assert validated_params.company.name == "Acme Corp"
      assert validated_params.company.headquarters.country == "US"
      assert validated_params.company.headquarters.contact.email == "info@acme.com"
      assert validated_params.company.headquarters.contact.phone == ""
    end

    test "handles missing double nested object with fallback" do
      conn = %{}

      params = %{
        "user" => %{
          "name" => "John"
        }
      }

      {^conn, validated_params} = DoubleNestedSchemaController.create(conn, params)

      assert validated_params.user.name == "John"
      assert is_map(validated_params.user.address)
    end
  end

  describe "empty nested schema" do
    test "nothing happens when provided with empty user in params" do
      conn = %{}
      params = %{"user" => %{}}

      {^conn, validated_params} = EmptyNestedSchemaController.create(conn, params)

      assert validated_params.user == %{}
    end

    test "nothing happens when provided with user in params" do
      conn = %{}
      params = %{"user" => %{"name" => "John"}}

      {^conn, validated_params} = EmptyNestedSchemaController.create(conn, params)

      assert validated_params.user == %{}
    end

    test "nothing happens when provided with empty params" do
      conn = %{}
      params = %{}

      {^conn, validated_params} = EmptyNestedSchemaController.create(conn, params)

      assert validated_params.user == %{}
    end
  end

  describe "list with nested schema" do
    test "validates list of nested objects" do
      conn = %{}

      params = %{
        "users" => [
          %{"name" => "John", "age" => "25"},
          %{"name" => "Jane", "age" => "30"}
        ]
      }

      {^conn, validated_params} = ListNestedSchemaController.create(conn, params)

      assert length(validated_params.users) == 2
      assert Enum.at(validated_params.users, 0).name == "John"
      assert Enum.at(validated_params.users, 0).age == 25
      assert Enum.at(validated_params.users, 1).name == "Jane"
      assert Enum.at(validated_params.users, 1).age == 30
    end

    test "applies defaults to nested parameters in list" do
      conn = %{}

      params = %{
        "tags" => [
          %{},
          %{"label" => "custom"}
        ]
      }

      {^conn, validated_params} = ListNestedSchemaController.update(conn, params)

      assert length(validated_params.tags) == 2
      assert Enum.at(validated_params.tags, 0).label == "default"
      assert Enum.at(validated_params.tags, 0).color == "blue"
      assert Enum.at(validated_params.tags, 1).label == "custom"
      assert Enum.at(validated_params.tags, 1).color == "blue"
    end

    test "validates enum constraints in list" do
      conn = %{}

      params = %{
        "tags" => [
          %{"label" => "tag1", "color" => "red"},
          %{"label" => "tag2", "color" => "green"}
        ]
      }

      {^conn, validated_params} = ListNestedSchemaController.update(conn, params)

      assert Enum.at(validated_params.tags, 0).color == "red"
      assert Enum.at(validated_params.tags, 1).color == "green"
    end

    test "falls back on invalid enum values in list" do
      conn = %{}

      params = %{
        "tags" => [
          %{"label" => "tag1", "color" => "invalid"}
        ]
      }

      {^conn, validated_params} = ListNestedSchemaController.update(conn, params)

      assert Enum.at(validated_params.tags, 0).color == "blue"
    end

    test "validates constraints on nested parameters in list" do
      conn = %{}

      params = %{
        "users" => [
          %{"name" => "John", "age" => "25"},
          %{"name" => "Jane", "age" => "16"}
        ]
      }

      {^conn, validated_params} = ListNestedSchemaController.create(conn, params)

      assert Enum.at(validated_params.users, 0).age == 25
      # Age is below min (18), should fallback to nil
      assert is_nil(Enum.at(validated_params.users, 1).age)
    end

    test "handles empty list" do
      conn = %{}
      params = %{"users" => []}

      {^conn, validated_params} = ListNestedSchemaController.create(conn, params)

      assert validated_params.users == []
    end

    test "handles missing list parameter with fallback" do
      conn = %{}
      params = %{}

      {^conn, validated_params} = ListNestedSchemaController.create(conn, params)

      assert validated_params.users == []
    end

    test "validates mixed flat and list with nested schema" do
      conn = %{}

      params = %{
        "title" => "Order 1",
        "items" => [
          %{"name" => "Item 1", "quantity" => "5"},
          %{"name" => "Item 2"}
        ]
      }

      {^conn, validated_params} = ListNestedSchemaController.order(conn, params)

      assert validated_params.title == "Order 1"
      assert length(validated_params.items) == 2
      assert Enum.at(validated_params.items, 0).name == "Item 1"
      assert Enum.at(validated_params.items, 0).quantity == 5
      assert Enum.at(validated_params.items, 1).name == "Item 2"
      assert Enum.at(validated_params.items, 1).quantity == 1
    end

    test "handles list with some invalid items" do
      conn = %{}

      params = %{
        "users" => [
          %{"name" => "John", "age" => "25"},
          %{"age" => "30"},
          %{"name" => "Bob", "age" => "invalid"}
        ]
      }

      {^conn, validated_params} = ListNestedSchemaController.create(conn, params)

      assert length(validated_params.users) == 3
      assert Enum.at(validated_params.users, 0).name == "John"
      assert Enum.at(validated_params.users, 0).age == 25
      # Missing required name field, should fallback to nil
      assert is_nil(Enum.at(validated_params.users, 1).name)
      assert Enum.at(validated_params.users, 1).age == 30
      assert Enum.at(validated_params.users, 2).name == "Bob"
      # Invalid age type, should fallback to nil
      assert is_nil(Enum.at(validated_params.users, 2).age)
    end
  end

  describe "render module" do
    test "renders without params" do
      module =
        defmodule TestFallbackController do
          use Filtr.Controller, error_mode: :fallback
        end

      assert {_, _, _, :ok} = module
    end

    test "renders with params" do
      module =
        defmodule TestFallbackParamController do
          use Filtr.Controller, error_mode: :fallback

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
          use Filtr.Controller, error_mode: :fallback

          param :user, :string, required: true
        end

      assert {_, _, _, :ok} = module
    end

    test "raises on invalid error mode" do
      assert_raise ArgumentError, fn ->
        defmodule TestInvalidErrorModeController do
          use Filtr.Controller, error_mode: :invalid
        end
      end
    end

    test "raises on invalid nested schema" do
      assert_raise ArgumentError, fn ->
        defmodule TestInvalidNestedSchemaController do
          use Filtr.Controller

          param :user do
            String.downcase("ASD")
          end
        end
      end
    end
  end
end
