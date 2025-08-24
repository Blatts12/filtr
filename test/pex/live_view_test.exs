defmodule Pex.LiveViewTest do
  use ExUnit.Case

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Pex.LiveViewTest.Endpoint
  alias Plug.Conn.WrapperError

  doctest Pex.LiveView

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
      assert_raise WrapperError, ~r/Validation failed/, fn ->
        {:ok, _lv, _html} = live(conn, "/raise")
      end
    end

    test "raises an error with invalid params", %{conn: conn} do
      assert_raise WrapperError, ~r/Validation failed/, fn ->
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

  describe "__using__ macro" do
    defmodule TestLiveView do
      use Phoenix.LiveView, namespace: Pex

      use Pex.LiveView,
        schema: %{
          test_param: [type: :string, default: "default_value"]
        }

      @impl true
      def render(assigns), do: ~H""

      @impl true
      def mount(_params, _session, socket), do: {:ok, socket}

      @impl true
      def handle_params(_params, _url, socket), do: {:noreply, socket}
    end

    test "defines on_mount/4 function" do
      assert function_exported?(TestLiveView, :on_mount, 4)
    end

    test "accepts different error_mode options" do
      defmodule StrictLiveView do
        use Phoenix.LiveView, namespace: Pex

        use Pex.LiveView,
          schema: %{param: [type: :string, default: "test"]},
          error_mode: :strict
      end

      assert function_exported?(StrictLiveView, :on_mount, 4)
    end

    test "raises error when schema is missing" do
      assert_raise RuntimeError, "schema is required", fn ->
        defmodule InvalidLiveView do
          use Phoenix.LiveView, namespace: Pex
          use Pex.LiveView
        end
      end
    end

    test "raises error when provided with invalid error_mode" do
      assert_raise ArgumentError, ~r/error_mode must be one of/, fn ->
        defmodule InvalidLiveView do
          use Phoenix.LiveView, namespace: Pex
          use Pex.LiveView, error_mode: :invalid, schema: %{}
        end
      end
    end
  end

  defp init_session(_) do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end
end
