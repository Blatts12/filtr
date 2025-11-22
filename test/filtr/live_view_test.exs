defmodule Filtr.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Filtr.LiveViewTest.Endpoint
  alias Plug.Conn.WrapperError

  @endpoint Endpoint

  describe "live view default error mode (fallback)" do
    setup [:init_session]

    test "default values in assigns with no params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default")
      assert %{limit: 10, query: nil} = get_assigns(lv).filtr
    end

    test "correct values in assigns with valid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default?query=elixir&limit=5")
      assert %{limit: 5, query: "elixir"} = get_assigns(lv).filtr
    end

    test "default values in assigns with invalid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default?query=elixir&limit=invalid")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).filtr

      {:ok, lv, _html} = live(conn, "/default?query=123&limit=1")
      assert %{limit: 10, query: "123"} = get_assigns(lv).filtr
    end

    test "default and correct values in assigns with one missing param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/default?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).filtr
    end
  end

  describe "live view fallback error mode" do
    setup [:init_session]

    test "default values in assigns with no params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback")
      assert %{limit: 10, query: nil} = get_assigns(lv).filtr
    end

    test "correct values in assigns with valid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback?query=elixir&limit=5")
      assert %{limit: 5, query: "elixir"} = get_assigns(lv).filtr
    end

    test "default values in assigns with invalid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback?query=elixir&limit=invalid")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).filtr

      {:ok, lv, _html} = live(conn, "/fallback?query=123&limit=1")
      assert %{limit: 10, query: "123"} = get_assigns(lv).filtr
    end

    test "default and correct values in assigns with one missing param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/fallback?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).filtr
    end
  end

  describe "live view strict error mode" do
    setup [:init_session]

    test "default and errored value in assigns with no params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/strict")
      assert %{limit: 10, query: {:error, ["required"]}} = get_assigns(lv).filtr
    end

    test "correct values in assigns with valid params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/strict?query=elixir&limit=5")
      assert %{limit: 5, query: "elixir"} = get_assigns(lv).filtr
    end

    test "default and correct values in assigns with one missing param", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/strict?query=elixir")
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).filtr
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
      assert %{limit: 10, query: "elixir"} = get_assigns(lv).filtr
    end
  end

  describe "nested schema" do
    setup [:init_session]

    test "validates nested parameters", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/nested?user[name]=John&user[age]=25")
      filtr = get_assigns(lv).filtr

      assert filtr.user.name == "John"
      assert filtr.user.age == 25
    end

    test "applies defaults to nested parameters", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/nested?user[name]=John")
      filtr = get_assigns(lv).filtr

      assert filtr.user.name == "John"
      assert Map.has_key?(filtr.user, :age)
    end

    test "handles missing nested object with fallback", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/nested")
      filtr = get_assigns(lv).filtr

      # In fallback mode, missing nested params should get a map
      assert is_nil(filtr.user.name)
      assert is_nil(filtr.user.age)
    end

    test "validates constraints on nested parameters", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/nested?user[name]=John&user[age]=16")
      filtr = get_assigns(lv).filtr

      assert filtr.user.name == "John"
      assert Map.has_key?(filtr.user, :age)
    end
  end

  describe "mixed flat and nested schema" do
    setup [:init_session]

    test "validates both flat and nested parameters", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/mixed?name=John&settings[theme]=dark&settings[notifications]=false")
      filtr = get_assigns(lv).filtr

      assert filtr.name == "John"
      assert filtr.settings.theme == "dark"
      assert filtr.settings.notifications == false
    end

    test "applies defaults to nested while validating flat", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/mixed?name=John")
      filtr = get_assigns(lv).filtr

      assert filtr.name == "John"
      assert filtr.settings.theme == "light"
      assert filtr.settings.notifications == true
    end

    test "handles missing nested object in mixed schema", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/mixed?name=John")
      filtr = get_assigns(lv).filtr

      assert filtr.name == "John"
      assert is_map(filtr.settings)
      assert filtr.settings.theme == "light"
    end
  end

  describe "double nested schema" do
    setup [:init_session]

    test "validates triple nested parameters", %{conn: conn} do
      {:ok, lv, _html} =
        live(
          conn,
          "/double_nested?company[name]=Acme&company[headquarters][country]=UK&company[headquarters][contact][email]=info@acme.com&company[headquarters][contact][phone]=44-123-456"
        )

      filtr = get_assigns(lv).filtr

      assert filtr.company.name == "Acme"
      assert filtr.company.headquarters.country == "UK"
      assert filtr.company.headquarters.contact.email == "info@acme.com"
      assert filtr.company.headquarters.contact.phone == "44-123-456"
    end

    test "applies defaults to triple nested parameters", %{conn: conn} do
      {:ok, lv, _html} =
        live(
          conn,
          "/double_nested?company[name]=Acme&company[headquarters][contact][email]=info@acme.com"
        )

      filtr = get_assigns(lv).filtr

      assert filtr.company.name == "Acme"
      assert filtr.company.headquarters.country == "US"
      assert filtr.company.headquarters.contact.email == "info@acme.com"
      assert filtr.company.headquarters.contact.phone == ""
    end

    test "handles missing double nested object with fallback", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/double_nested?company[name]=Acme")
      filtr = get_assigns(lv).filtr

      assert filtr.company.name == "Acme"
      assert is_map(filtr.company.headquarters)
    end
  end

  describe "empty nested schema" do
    setup [:init_session]

    test "nothing happens when provided with empty user in params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/empty_nested?user=")
      filtr = get_assigns(lv).filtr

      assert filtr.user == %{}
    end

    test "nothing happens when provided with user in params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/empty_nested?user[name]=John")
      filtr = get_assigns(lv).filtr

      assert filtr.user == %{}
    end

    test "nothing happens when provided with empty params", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/empty_nested")
      filtr = get_assigns(lv).filtr

      assert filtr.user == %{}
    end
  end

  describe "list with nested schema" do
    setup [:init_session]

    test "validates list of nested objects with indexed map", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?users[0][name]=John&users[0][age]=25&users[1][name]=Jane&users[1][age]=30")
      filtr = get_assigns(lv).filtr

      assert length(filtr.users) == 2
      assert Enum.at(filtr.users, 0).name == "John"
      assert Enum.at(filtr.users, 0).age == 25
      assert Enum.at(filtr.users, 1).name == "Jane"
      assert Enum.at(filtr.users, 1).age == 30
    end

    test "applies defaults to nested parameters in list with indexed map", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?tags[0][color]=&tags[1][label]=custom")
      filtr = get_assigns(lv).filtr

      assert length(filtr.tags) == 2
      assert Enum.at(filtr.tags, 0).label == "default"
      assert Enum.at(filtr.tags, 0).color == "blue"
      assert Enum.at(filtr.tags, 1).label == "custom"
      assert Enum.at(filtr.tags, 1).color == "blue"
    end

    test "validates enum constraints in list with indexed map", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?tags[0][label]=tag1&tags[0][color]=red&tags[1][label]=tag2&tags[1][color]=green")
      filtr = get_assigns(lv).filtr

      assert Enum.at(filtr.tags, 0).color == "red"
      assert Enum.at(filtr.tags, 1).color == "green"
    end

    test "falls back on invalid enum values in list with indexed map", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?tags[0][label]=tag1&tags[0][color]=invalid")
      filtr = get_assigns(lv).filtr

      assert Enum.at(filtr.tags, 0).color == "blue"
    end

    test "validates constraints on nested parameters in list with indexed map", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?users[0][name]=John&users[0][age]=25&users[1][name]=Jane&users[1][age]=16")
      filtr = get_assigns(lv).filtr

      assert Enum.at(filtr.users, 0).age == 25
      # Age is below min (18), should fallback to nil
      assert is_nil(Enum.at(filtr.users, 1).age)
    end

    test "handles missing list parameter with fallback", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested")
      filtr = get_assigns(lv).filtr

      assert filtr.users == []
    end

    test "validates mixed flat and list with nested schema using indexed map", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?items[0][name]=Item 1&items[0][quantity]=5&items[1][name]=Item 2")
      filtr = get_assigns(lv).filtr

      assert length(filtr.items) == 2
      assert Enum.at(filtr.items, 0).name == "Item 1"
      assert Enum.at(filtr.items, 0).quantity == 5
      assert Enum.at(filtr.items, 1).name == "Item 2"
      assert Enum.at(filtr.items, 1).quantity == 1
    end

    test "handles indexed map with some invalid items", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?users[0][name]=John&users[0][age]=25&users[1][age]=30&users[2][name]=Bob&users[2][age]=invalid")
      filtr = get_assigns(lv).filtr

      assert length(filtr.users) == 3
      assert Enum.at(filtr.users, 0).name == "John"
      assert Enum.at(filtr.users, 0).age == 25
      # Missing required name field, should fallback to nil
      assert is_nil(Enum.at(filtr.users, 1).name)
      assert Enum.at(filtr.users, 1).age == 30
      assert Enum.at(filtr.users, 2).name == "Bob"
      # Invalid age type, should fallback to nil
      assert is_nil(Enum.at(filtr.users, 2).age)
    end

    test "handles non-sequential indexed map keys", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/list_nested?users[2][name]=Bob&users[2][age]=35&users[0][name]=John&users[0][age]=25&users[1][name]=Jane&users[1][age]=30")
      filtr = get_assigns(lv).filtr

      # Should be sorted by keys
      assert length(filtr.users) == 3
      assert Enum.at(filtr.users, 0).name == "John"
      assert Enum.at(filtr.users, 1).name == "Jane"
      assert Enum.at(filtr.users, 2).name == "Bob"
    end
  end

  describe "renders module" do
    test "creates module without params" do
      module =
        defmodule TestLiveView do
          use Phoenix.LiveView, namespace: Filtr
          use Filtr.LiveView
        end

      assert {_, _, _, {:on_mount, 4}} = module
    end

    test "creates module with params" do
      module =
        defmodule TestLiveViewParams do
          @moduledoc false
          use Phoenix.LiveView, namespace: Filtr
          use Filtr.LiveView

          param :name, :string
          param :age, :integer, default: 25, required: true
        end

      assert {_, _, _, :ok} = module
    end

    test "raises when provided with invalid error mode" do
      assert_raise ArgumentError, fn ->
        defmodule TestInvalidErrorMode do
          @moduledoc false
          use Phoenix.LiveView, namespace: Filtr
          use Filtr.LiveView, error_mode: :invalid
        end
      end
    end

    test "raises when provided with nested schema" do
      assert_raise ArgumentError, fn ->
        defmodule TestInvalidErrorMode do
          @moduledoc false
          use Phoenix.LiveView, namespace: Filtr
          use Filtr.LiveView

          param :user do
            IO.inspect("Hello World")
          end
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
