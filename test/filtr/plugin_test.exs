defmodule Filtr.PluginTest do
  use ExUnit.Case, async: false

  # credo:disable-for-this-file Credo.Check.Design.AliasUsage

  alias Filtr.Plugin

  describe "__using__ macro" do
    test "sets up behaviour with default types/0 returning empty list" do
      defmodule BasicPlugin do
        @moduledoc false
        use Plugin
      end

      assert BasicPlugin.types() == []
    end

    test "allows overriding types/0" do
      defmodule CustomTypesPlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:custom_type]
      end

      assert CustomTypesPlugin.types() == [:custom_type]
    end

    test "allows implementing cast/3 callback" do
      defmodule CastPlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:uppercase]

        @impl true
        def cast(value, :uppercase, _opts) do
          {:ok, String.upcase(value)}
        end

        @impl true
        def validate(value, :uppercase, validator, opts) do
          Filtr.DefaultPlugin.validate(value, :string, validator, opts)
        end
      end

      assert {:ok, "HELLO"} = CastPlugin.cast("hello", :uppercase, [])
    end

    test "allows implementing validate/4 callback" do
      defmodule ValidatePlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:even_number]

        @impl true
        def cast(value, :even_number, opts) do
          Filtr.DefaultPlugin.cast(value, :integer, opts)
        end

        @impl true
        def validate(value, :even_number, {:divisible_by, n}, _opts) do
          if rem(value, n) == 0, do: :ok, else: {:error, "not divisible by #{n}"}
        end
      end

      assert :ok = ValidatePlugin.validate(10, :even_number, {:divisible_by, 2}, [])
      assert {:error, _} = ValidatePlugin.validate(11, :even_number, {:divisible_by, 2}, [])
    end
  end

  describe "all/0" do
    test "returns all registered plugins including DefaultPlugin" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      Application.delete_env(:filtr, :plugins)

      assert [Filtr.DefaultPlugin] = Plugin.all()

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "returns plugins in correct order with DefaultPlugin first" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      defmodule FirstPlugin do
        @moduledoc false
        use Plugin
      end

      defmodule SecondPlugin do
        @moduledoc false
        use Plugin
      end

      Application.put_env(:filtr, :plugins, [FirstPlugin, SecondPlugin])

      assert [Filtr.DefaultPlugin, FirstPlugin, SecondPlugin] = Plugin.all()

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end
  end

  describe "find_for_type/1" do
    test "finds DefaultPlugin for built-in types" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      Application.delete_env(:filtr, :plugins)

      assert Plugin.find_for_type(:string) == Filtr.DefaultPlugin
      assert Plugin.find_for_type(:integer) == Filtr.DefaultPlugin
      assert Plugin.find_for_type(:boolean) == Filtr.DefaultPlugin
      assert Plugin.find_for_type(:date) == Filtr.DefaultPlugin

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "finds custom plugin for custom types" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      defmodule CustomTypePlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:custom, :special]
      end

      Application.put_env(:filtr, :plugins, [CustomTypePlugin])

      assert Plugin.find_for_type(:custom) == CustomTypePlugin
      assert Plugin.find_for_type(:special) == CustomTypePlugin

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "returns nil for unsupported types" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      Application.delete_env(:filtr, :plugins)

      assert Plugin.find_for_type(:nonexistent_type) == nil
      assert Plugin.find_for_type(:unknown) == nil

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "later plugins are first in the list" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      defmodule FirstOverridePlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:shared_type]
      end

      defmodule SecondOverridePlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:shared_type]
      end

      Application.put_env(:filtr, :plugins, [FirstOverridePlugin, SecondOverridePlugin])
      assert Plugin.find_for_type(:shared_type) == SecondOverridePlugin
      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "custom plugin can override DefaultPlugin types" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      defmodule StringOverridePlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:string]
      end

      Application.put_env(:filtr, :plugins, [StringOverridePlugin])

      assert Plugin.find_for_type(:string) == StringOverridePlugin
      assert Plugin.find_for_type(:integer) == Filtr.DefaultPlugin

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end
  end

  describe "custom plugin behaviour implementation" do
    test "plugin can implement cast/3 callback" do
      defmodule CastTestPlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:uppercase]

        @impl true
        def cast(value, :uppercase, _opts) when is_binary(value) do
          {:ok, String.upcase(value)}
        end
      end

      assert {:ok, "HELLO"} = CastTestPlugin.cast("hello", :uppercase, [])
      assert {:ok, "WORLD"} = CastTestPlugin.cast("world", :uppercase, [])
    end

    test "plugin can implement validate/4 callback with different validators" do
      defmodule ValidateTestPlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:even_number]

        @impl true
        def cast(value, :even_number, _opts) when is_integer(value), do: {:ok, value}

        @impl true
        def validate(value, :even_number, {:must_be_even, true}, _opts) do
          if rem(value, 2) == 0, do: :ok, else: {:error, "must be even"}
        end

        def validate(value, :even_number, {:min, min}, _opts) do
          if value >= min, do: :ok, else: {:error, "too small"}
        end

        def validate(_value, :even_number, _validator, _opts), do: :ok
      end

      # Test even validation
      assert :ok = ValidateTestPlugin.validate(10, :even_number, {:must_be_even, true}, [])

      assert {:error, "must be even"} =
               ValidateTestPlugin.validate(11, :even_number, {:must_be_even, true}, [])

      # Test min validation
      assert :ok = ValidateTestPlugin.validate(20, :even_number, {:min, 10}, [])
      assert {:error, "too small"} = ValidateTestPlugin.validate(5, :even_number, {:min, 10}, [])
    end

    test "plugin can return different validation result types" do
      defmodule ValidationResultsPlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:test]

        @impl true
        def cast(value, :test, _opts), do: {:ok, value}

        @impl true
        def validate(_value, :test, {:return_ok, _}, _opts), do: :ok
        def validate(_value, :test, {:return_true, _}, _opts), do: true
        def validate(_value, :test, {:return_false, _}, _opts), do: false
        def validate(_value, :test, {:return_error, _}, _opts), do: :error
        def validate(_value, :test, {:return_ok_tuple, _}, _opts), do: {:ok, "valid"}
        def validate(_value, :test, {:return_error_tuple, msg}, _opts), do: {:error, msg}
      end

      assert :ok == ValidationResultsPlugin.validate("x", :test, {:return_ok, true}, [])
      assert true == ValidationResultsPlugin.validate("x", :test, {:return_true, true}, [])
      assert false == ValidationResultsPlugin.validate("x", :test, {:return_false, true}, [])
      assert :error == ValidationResultsPlugin.validate("x", :test, {:return_error, true}, [])

      assert {:ok, "valid"} ==
               ValidationResultsPlugin.validate("x", :test, {:return_ok_tuple, true}, [])

      assert {:error, "custom"} ==
               ValidationResultsPlugin.validate("x", :test, {:return_error_tuple, "custom"}, [])
    end

    test "plugin can handle multiple types" do
      defmodule MultiTypePlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:type_a, :type_b, :type_c]

        @impl true
        def cast(value, :type_a, _opts), do: {:ok, "A:#{value}"}
        def cast(value, :type_b, _opts), do: {:ok, "B:#{value}"}
        def cast(value, :type_c, _opts), do: {:ok, "C:#{value}"}

        @impl true
        def validate(_value, _type, _validator, _opts), do: :ok
      end

      assert [:type_a, :type_b, :type_c] = MultiTypePlugin.types()
      assert {:ok, "A:test"} = MultiTypePlugin.cast("test", :type_a, [])
      assert {:ok, "B:test"} = MultiTypePlugin.cast("test", :type_b, [])
      assert {:ok, "C:test"} = MultiTypePlugin.cast("test", :type_c, [])
    end

    test "plugin cast can return error" do
      defmodule ErrorCastPlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:strict_integer]

        @impl true
        def cast(value, :strict_integer, _opts) when is_integer(value), do: {:ok, value}
        def cast(_value, :strict_integer, _opts), do: {:error, "not an integer"}

        @impl true
        def validate(_value, :strict_integer, _validator, _opts), do: :ok
      end

      assert {:ok, 42} = ErrorCastPlugin.cast(42, :strict_integer, [])
      assert {:error, "not an integer"} = ErrorCastPlugin.cast("42", :strict_integer, [])
      assert {:error, "not an integer"} = ErrorCastPlugin.cast(3.14, :strict_integer, [])
    end

    test "plugin cast can return error list" do
      defmodule ErrorListCastPlugin do
        @moduledoc false
        use Plugin

        @impl true
        def types, do: [:validated]

        @impl true
        def cast(_value, :validated, _opts) do
          {:error, ["error1", "error2", "error3"]}
        end

        @impl true
        def validate(_value, :validated, _validator, _opts), do: :ok
      end

      assert {:error, ["error1", "error2", "error3"]} =
               ErrorListCastPlugin.cast("x", :validated, [])
    end
  end
end
