defmodule Pex.ControllerTest do
  use ExUnit.Case
  
  import Plug.Test

  alias Pex.Controller

  describe "parse_params/2" do
    test "successfully parses valid parameters" do
      conn = conn(:get, "/", %{"page" => "2", "search" => "test"})
      schema = %{
        page: [type: :integer, default: 1],
        search: [type: :string, optional: true]
      }

      assert {:ok, %{page: 2, search: "test"}} = Controller.parse_params(conn, schema)
    end

    test "returns errors for invalid parameters" do
      conn = conn(:get, "/", %{"page" => "invalid"})
      schema = %{page: [type: :integer]}

      assert {:error, %{page: "invalid integer"}} = Controller.parse_params(conn, schema)
    end
  end

  describe "assign_parsed_params/2" do
    test "assigns valid parameters to connection" do
      conn = conn(:get, "/", %{"page" => "3"})
      schema = %{page: [type: :integer, default: 1]}

      assert {:ok, updated_conn} = Controller.assign_parsed_params(conn, schema)
      assert %{page: 3} = updated_conn.assigns.pex_params
    end

    test "assigns errors to connection on validation failure" do
      conn = conn(:get, "/", %{"page" => "invalid"})
      schema = %{page: [type: :integer]}

      assert {:error, updated_conn, errors} = Controller.assign_parsed_params(conn, schema)
      assert %{page: "invalid integer"} = errors
      assert %{page: "invalid integer"} = updated_conn.assigns.pex_errors
    end
  end

  describe "get_parsed_params/1" do
    test "returns assigned parameters" do
      conn = conn(:get, "/")
      conn = Plug.Conn.assign(conn, :pex_params, %{page: 1, limit: 10})

      assert %{page: 1, limit: 10} = Controller.get_parsed_params(conn)
    end

    test "returns empty map when no parameters assigned" do
      conn = conn(:get, "/")

      assert %{} = Controller.get_parsed_params(conn)
    end
  end

  describe "get_param_errors/1" do
    test "returns assigned errors" do
      conn = conn(:get, "/")
      errors = %{page: "invalid integer"}
      conn = Plug.Conn.assign(conn, :pex_errors, errors)

      assert ^errors = Controller.get_param_errors(conn)
    end

    test "returns empty map when no errors assigned" do
      conn = conn(:get, "/")

      assert %{} = Controller.get_param_errors(conn)
    end
  end
end