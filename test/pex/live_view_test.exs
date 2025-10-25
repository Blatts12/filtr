defmodule Pex.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Pex.LiveViewTest.Endpoint
  alias Plug.Conn.WrapperError

  @endpoint Endpoint

  describe "live view default error mode (fallback)" do
    setup [:init_session]

    test "default values in assigns with no params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default")
      assert %{limit: 10, query: nil} = get_assigns(lv).pex
    end

    test "correct values in assigns with valid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default?query=elixir&limit=5")
      assert %{limit: 5, query: "elixir"} = get_assigns(lv).pex
    end

    test "default values in assigns with invalid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default?query=elixir&limit=invalid")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).pex

      {:ok, lv, _html} = live(conn, "/default?query=123&limit=1")
      assert %{limit: 10, query: "123"} = get_assigns(lv).pex
    end

    test "default and correct values in assigns with one missing param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).pex
    end
  end

  describe "live view fallback error mode" do
    setup [:init_session]

    test "default values in assigns with no params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback")
      assert %{limit: 10, query: nil} = get_assigns(lv).pex
    end

    test "correct values in assigns with valid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback?query=elixir&limit=5")
      assert %{limit: 5, query: "elixir"} = get_assigns(lv).pex
    end

    test "default values in assigns with invalid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback?query=elixir&limit=invalid")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).pex

      {:ok, lv, _html} = live(conn, "/fallback?query=123&limit=1")
      assert %{limit: 10, query: "123"} = get_assigns(lv).pex
    end

    test "default and correct values in assigns with one missing param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).pex
    end
  end

  describe "live view strict error mode" do
    setup [:init_session]

    test "default and errored value in assigns with no params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/strict")
      assert %{limit: 10, query: {:error, ["required"]}} = get_assigns(lv).pex
    end

    test "correct values in assigns with valid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/strict?query=elixir&limit=5")
      assert %{limit: 5, query: "elixir"} = get_assigns(lv).pex
    end

    test "default and correct values in assigns with one missing param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/strict?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).pex
    end
  end

  describe "live view raise error mode" do
    setup [:init_session]

    test "raises an error with no params - required params missing", %{conn: conn} do
      assert_raise WrapperError, ~r/Invalid value for query: required/, fn ->
        {:ok, _lv, _html} = live(conn, "/raise")
      end
    end

    test "raises an error with invalid params", %{conn: conn} do
      assert_raise WrapperError, ~r/Invalid value for limit/, fn ->
        {:ok, _lv, _html} = live(conn, "/raise?query=elixir&limit=invalid")
      end
    end

    test "does not raise an error with missing optional param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/raise?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).pex
    end
  end

  describe "renders module" do
    test "creates module without params" do
      module =
        defmodule TestLiveView do
          use Phoenix.LiveView, namespace: Pex
          use Pex.LiveView
        end

      assert {_, _, _, {:on_mount, 4}} = module
    end

    test "creates module with params" do
      module =
        defmodule TestLiveViewParams do
          @moduledoc false
          use Phoenix.LiveView, namespace: Pex
          use Pex.LiveView

          param :name, :string
          param :age, :integer, default: 25, required: true
        end

      assert {_, _, _, :ok} = module
    end

    test "raises when provided with invalid error mode" do
      assert_raise ArgumentError, fn ->
        defmodule TestInvalidErrorMode do
          @moduledoc false
          use Phoenix.LiveView, namespace: Pex
          use Pex.LiveView, error_mode: :invalid
        end
      end
    end
  end

  defp init_session(_) do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  defp get_assigns(%{module: module} = lv) do
    module.run(lv, fn socket -> {:reply, socket.assigns, socket} end)
  end
end
