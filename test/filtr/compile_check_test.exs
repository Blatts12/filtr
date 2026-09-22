defmodule Filtr.CompileCheckTest do
  use ExUnit.Case, async: false

  alias Filtr.CompileCheck

  doctest CompileCheck

  defmodule MoneyPlugin do
    @moduledoc false
    use Filtr.Plugin

    @impl Filtr.Plugin
    def types, do: [:money]

    @impl Filtr.Plugin
    def cast(value, :money, _ctx), do: {:ok, value}

    @impl Filtr.Plugin
    def validate(value, :money, validator, ctx), do: Filtr.DefaultPlugin.validate(value, :integer, validator, ctx)
  end

  defp with_plugins(plugins, fun) do
    original = Application.get_env(:filtr, :plugins, [])
    Application.put_env(:filtr, :plugins, plugins)

    try do
      fun.()
    after
      Application.put_env(:filtr, :plugins, original)
    end
  end

  describe "check_type!/2 with types that pass" do
    test "accepts every type the default plugin owns" do
      for type <- Filtr.DefaultPlugin.types() do
        assert CompileCheck.check_type!(:key, type) == :ok
      end
    end

    test "accepts the passthrough markers" do
      assert CompileCheck.check_type!(:key, nil) == :ok
      assert CompileCheck.check_type!(:key, :__none__) == :ok
    end

    test "accepts a list of a known type" do
      assert CompileCheck.check_type!(:tags, {:list, :string}) == :ok
      assert CompileCheck.check_type!(:matrix, {:list, {:list, :integer}}) == :ok
    end

    test "accepts a nested schema map, including one inside a list" do
      schema = %{name: %{type: :string}, age: %{type: :integer}}

      assert CompileCheck.check_type!(:user, schema) == :ok
      assert CompileCheck.check_type!(:users, {:list, schema}) == :ok
    end

    test "accepts a cast function of arity 1, 2 and 3" do
      assert CompileCheck.check_type!(:slug, fn value -> value end) == :ok
      assert CompileCheck.check_type!(:slug, fn value, _ctx -> value end) == :ok
      assert CompileCheck.check_type!(:slug, fn value, _schema, _ctx -> value end) == :ok
    end

    test "accepts a type a configured plugin owns" do
      with_plugins([MoneyPlugin], fn ->
        assert CompileCheck.check_type!(:price, :money) == :ok
      end)
    end

    test "skips a type the macro cannot see as a literal" do
      attribute_ast = {:@, [], [{:money, [], nil}]}
      variable_ast = {:type, [], nil}

      assert CompileCheck.check_type!(:price, attribute_ast) == :ok
      assert CompileCheck.check_type!(:price, variable_ast) == :ok
    end

    test "skips the check when a configured plugin cannot be resolved" do
      with_plugins([NotEvenAModule], fn ->
        assert CompileCheck.check_type!(:price, :money) == :ok
        assert CompileCheck.check_type!(:price, :intger) == :ok
      end)
    end
  end

  describe "check_type!/2 with types that fail" do
    test "raises on an unknown type" do
      assert_raise ArgumentError, ~r/unknown type :intger for param :age/, fn ->
        CompileCheck.check_type!(:age, :intger)
      end
    end

    test "suggests the type the typo is closest to" do
      assert_raise ArgumentError, ~r/Did you mean :integer\?/, fn ->
        CompileCheck.check_type!(:age, :intger)
      end
    end

    test "leaves out the suggestion when nothing is close" do
      error =
        assert_raise ArgumentError, fn ->
          CompileCheck.check_type!(:price, :money)
        end

      refute Exception.message(error) =~ "Did you mean"
    end

    test "lists the known types" do
      assert_raise ArgumentError, ~r/Known types: :boolean, :date, :datetime/, fn ->
        CompileCheck.check_type!(:age, :intger)
      end
    end

    test "raises on an unknown type inside a list" do
      assert_raise ArgumentError, ~r/unknown type :intger/, fn ->
        CompileCheck.check_type!(:ages, {:list, :intger})
      end
    end

    test "raises on an unknown type inside a nested schema" do
      assert_raise ArgumentError, ~r/unknown type :strng for param :name/, fn ->
        CompileCheck.check_type!(:user, %{name: %{type: :strng}})
      end
    end

    test "raises on a cast function of the wrong arity" do
      assert_raise ArgumentError, ~r/takes 4 arguments/, fn ->
        CompileCheck.check_type!(:slug, fn a, b, c, d -> {a, b, c, d} end)
      end
    end

    test "raises on a type that is not an atom, a tuple, a map or a function" do
      assert_raise ArgumentError, ~r/invalid type "string" for param :name/, fn ->
        CompileCheck.check_type!(:name, "string")
      end
    end

    test "names the schema when there is no key to name" do
      assert_raise ArgumentError, ~r/unknown type :intger for param in your schema/, fn ->
        CompileCheck.check_type!(nil, :intger)
      end
    end
  end

  describe "param macros" do
    test "a typo in a controller param fails to compile" do
      assert_raise ArgumentError, ~r/unknown type :intger for param :age/, fn ->
        Code.compile_string("""
        defmodule Filtr.CompileCheckTest.TypoController do
          use Filtr.Controller

          param :age, :intger

          def show(conn, params), do: {conn, params}
        end
        """)
      end
    end

    test "a typo inside a nested controller block fails to compile" do
      assert_raise ArgumentError, ~r/unknown type :strng for param :name/, fn ->
        Code.compile_string("""
        defmodule Filtr.CompileCheckTest.NestedTypoController do
          use Filtr.Controller

          param :user do
            param :name, :strng
          end

          def show(conn, params), do: {conn, params}
        end
        """)
      end
    end

    test "a typo in a list block fails to compile" do
      assert_raise ArgumentError, ~r/unknown type :intger for param :age/, fn ->
        Code.compile_string("""
        defmodule Filtr.CompileCheckTest.ListTypoController do
          use Filtr.Controller

          param :users, :list do
            param :age, :intger
          end

          def show(conn, params), do: {conn, params}
        end
        """)
      end
    end

    test "a typo in a live view param fails to compile" do
      assert_raise ArgumentError, ~r/unknown type :strng for param :query/, fn ->
        Code.compile_string("""
        defmodule Filtr.CompileCheckTest.TypoLive do
          use Phoenix.LiveView
          use Filtr.LiveView

          param :query, :strng

          def render(assigns), do: ~H"<div></div>"
        end
        """)
      end
    end

    test "a valid controller still compiles" do
      assert [{_module, _bin} | _] =
               Code.compile_string("""
               defmodule Filtr.CompileCheckTest.ValidController do
                 use Filtr.Controller

                 param :name, :string, required: true
                 param :tags, {:list, :string}, default: []

                 param :filters do
                   param :page, :integer, min: 1
                 end

                 def show(conn, params), do: {conn, params}
               end
               """)
    end
  end
end
