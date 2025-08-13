defmodule PexTest do
  use ExUnit.Case
  doctest Pex

  describe "parse/2" do
    test "parses simple string parameter" do
      schema = %{name: [type: :string]}
      params = %{"name" => "John"}
      
      assert {:ok, %{name: "John"}} = Pex.parse(params, schema)
    end

    test "applies default values for missing parameters" do
      schema = %{page: [type: :integer, default: 1]}
      params = %{}
      
      assert {:ok, %{page: 1}} = Pex.parse(params, schema)
    end

    test "validates required parameters" do
      schema = %{name: [type: :string]}
      params = %{}
      
      assert {:error, %{name: "required"}} = Pex.parse(params, schema)
    end

    test "handles optional parameters" do
      schema = %{search: [type: :string, optional: true]}
      params = %{}
      
      assert {:ok, %{search: nil}} = Pex.parse(params, schema)
    end

    test "casts integer parameters" do
      schema = %{page: [type: :integer]}
      params = %{"page" => "5"}
      
      assert {:ok, %{page: 5}} = Pex.parse(params, schema)
    end

    test "validates integer casting" do
      schema = %{page: [type: :integer]}
      params = %{"page" => "not_a_number"}
      
      assert {:error, %{page: "invalid integer"}} = Pex.parse(params, schema)
    end

    test "casts float parameters" do
      schema = %{price: [type: :float]}
      params = %{"price" => "19.99"}
      
      assert {:ok, %{price: 19.99}} = Pex.parse(params, schema)
    end

    test "casts boolean parameters" do
      schema = %{active: [type: :boolean]}
      params = %{"active" => "true"}
      
      assert {:ok, %{active: true}} = Pex.parse(params, schema)
    end

    test "handles boolean false values" do
      schema = %{active: [type: :boolean]}
      params = %{"active" => "false"}
      
      assert {:ok, %{active: false}} = Pex.parse(params, schema)
    end

    test "casts list parameters from strings" do
      schema = %{tags: [type: :list]}
      params = %{"tags" => "red,green,blue"}
      
      assert {:ok, %{tags: ["red", "green", "blue"]}} = Pex.parse(params, schema)
    end

    test "applies custom validators" do
      validator = fn value ->
        if value > 0, do: {:ok, value}, else: {:error, "must be positive"}
      end
      
      schema = %{count: [type: :integer, validator: validator]}
      params = %{"count" => "5"}
      
      assert {:ok, %{count: 5}} = Pex.parse(params, schema)
    end

    test "fails with custom validator errors" do
      validator = fn value ->
        if value > 0, do: {:ok, value}, else: {:error, "must be positive"}
      end
      
      schema = %{count: [type: :integer, validator: validator]}
      params = %{"count" => "-1"}
      
      assert {:error, %{count: "must be positive"}} = Pex.parse(params, schema)
    end

    test "handles multiple parameters" do
      schema = %{
        page: [type: :integer, default: 1],
        limit: [type: :integer, default: 10],
        search: [type: :string, optional: true]
      }
      params = %{"page" => "2", "search" => "test"}
      
      assert {:ok, %{page: 2, limit: 10, search: "test"}} = Pex.parse(params, schema)
    end

    test "returns error for first validation failure" do
      schema = %{
        page: [type: :integer],
        limit: [type: :integer]
      }
      params = %{"page" => "invalid", "limit" => "also_invalid"}
      
      # Should return error for the first field that fails
      assert {:error, errors} = Pex.parse(params, schema)
      assert map_size(errors) == 1
    end
  end
end
