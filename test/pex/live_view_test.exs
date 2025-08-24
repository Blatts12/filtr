defmodule Pex.LiveViewTest do
  use ExUnit.Case

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  doctest Pex.LiveView

  alias Pex.LiveViewTest.Endpoint

  @endpoint Endpoint

  describe "live view with fallback error mode" do
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

  describe "live view with strict error mode" do
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

  describe "live view with raise error mode" do
    setup [:init_session]

    test "raises an error with no params - required params missing", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError, ~r/Validation failed/, fn ->
        {:ok, _lv, _html} = live(conn, "/raise")
      end
    end

    test "raises an error with invalid params", %{conn: conn} do
      assert_raise Plug.Conn.WrapperError, ~r/Validation failed/, fn ->
        {:ok, _lv, _html} = live(conn, "/raise?query=elixir&limit=invalid")
      end
    end

    test "does not raise an error with missing optional param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/raise?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).pex
    end
  end

  defp get_assigns(%{module: module} = lv) do
    module.run(lv, fn socket -> {:reply, socket.assigns, socket} end)
  end

  defp init_session(_) do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end
end
