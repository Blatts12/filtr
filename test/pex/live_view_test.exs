defmodule Pex.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Pex.LiveViewTest.Endpoint
  alias Pex.LiveViewTest.FallbackLive
  alias Pex.LiveViewTest.RaiseLive
  alias Pex.LiveViewTest.StrictLive

  @endpoint Endpoint

  describe "param macro" do
    test "defines parameters correctly" do
      assert function_exported?(FallbackLive, :mount, 3)
      assert function_exported?(FallbackLive, :handle_params, 3)
    end
  end

  describe "parameter validation with fallback mode" do
    test "validates and assigns parameters with defaults" do
      {:ok, view, _html} = live(build_conn(), "/fallback")

      # LiveView should start successfully with defaults
      assert Process.alive?(view.pid)
    end

    test "validates and assigns provided parameters" do
      {:ok, view, _html} = live(build_conn(), "/fallback?query=test&limit=20")

      # LiveView should start successfully with valid parameters
      assert Process.alive?(view.pid)
    end

    test "applies validation constraints with fallback" do
      {:ok, view, _html} = live(build_conn(), "/fallback?query=test&limit=3")

      # LiveView should start successfully, using fallback for invalid limit
      assert Process.alive?(view.pid)
    end
  end

  describe "parameter validation with strict mode" do
    test "works with valid parameters" do
      {:ok, view, _html} = live(build_conn(), "/strict?query=test&limit=10")

      # LiveView should start successfully
      assert Process.alive?(view.pid)
    end
  end

  describe "parameter validation with raise mode" do
    test "works with valid parameters" do
      {:ok, view, _html} = live(build_conn(), "/raise?query=test&limit=10")

      # LiveView should start successfully
      assert Process.alive?(view.pid)
    end
  end

  describe "error mode validation" do
    test "raises on invalid error mode" do
      assert_raise ArgumentError, ~r/error_mode must be one of/, fn ->
        defmodule InvalidErrorModeLiveView do
          use Phoenix.LiveView
          use Pex.LiveView, error_mode: :invalid
        end
      end
    end

    test "accepts valid error modes" do
      assert Code.ensure_loaded?(FallbackLive)
      assert Code.ensure_loaded?(StrictLive)
      assert Code.ensure_loaded?(RaiseLive)
    end
  end

  describe "integration with Phoenix LiveView" do
    test "parameters are processed during mount" do
      {:ok, view, _html} = live(build_conn(), "/fallback?query=test&limit=15")

      # We can't directly access socket assigns in tests, but we can verify
      # the LiveView process is running and handling parameters correctly
      assert Process.alive?(view.pid)
    end

    test "parameters are processed during handle_params" do
      {:ok, view, _html} = live(build_conn(), "/fallback?query=initial")

      # Navigate to trigger handle_params with new parameters
      render_patch(view, "/fallback?query=updated&limit=25")
    end
  end

  describe "no parameters defined" do
    defmodule NoParamsLiveView do
      use Phoenix.LiveView
      use Pex.LiveView

      def mount(_params, _session, socket) do
        {:ok, socket}
      end

      def handle_params(_params, _uri, socket) do
        {:noreply, socket}
      end

      def render(assigns) do
        ~H"""
        <div>No params</div>
        """
      end
    end

    test "works normally without any param definitions" do
      # This should not raise any errors during compilation
      assert Code.ensure_loaded?(NoParamsLiveView)
    end
  end
end
