defmodule Filtr.HelpersTest do
  use ExUnit.Case, async: false

  alias Filtr.Helpers

  describe "supported_error_mode?/1" do
    test "returns true for :fallback" do
      assert Helpers.supported_error_mode?(:fallback) == true
    end

    test "returns true for :strict" do
      assert Helpers.supported_error_mode?(:strict) == true
    end

    test "returns true for :raise" do
      assert Helpers.supported_error_mode?(:raise) == true
    end

    test "returns false for invalid modes" do
      assert Helpers.supported_error_mode?(:invalid) == false
      assert Helpers.supported_error_mode?(:unknown) == false
      assert Helpers.supported_error_mode?(nil) == false
    end
  end

  describe "supported_error_modes/0" do
    test "returns list containing all supported modes" do
      modes = Helpers.supported_error_modes()

      assert :fallback in modes
      assert :strict in modes
      assert :raise in modes
    end

    test "returns exactly three modes" do
      assert length(Helpers.supported_error_modes()) == 3
    end
  end

  describe "type_plugin_map/0" do
    test "builds a map from types to their plugins" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      Application.delete_env(:filtr, :plugins)

      type_map = Helpers.type_plugin_map()

      assert type_map[:string] == Filtr.DefaultPlugin
      assert type_map[:integer] == Filtr.DefaultPlugin
      assert type_map[:float] == Filtr.DefaultPlugin
      assert type_map[:boolean] == Filtr.DefaultPlugin
      assert type_map[:time] == Filtr.DefaultPlugin
      assert type_map[:date] == Filtr.DefaultPlugin
      assert type_map[:datetime] == Filtr.DefaultPlugin
      assert type_map[:list] == Filtr.DefaultPlugin

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "later plugins are first on the list of pluhins" do
      original_plugins = Application.get_env(:filtr, :plugins)
      :persistent_term.erase(:filtr_type_plugin_map)

      defmodule TestPluginOverride do
        @moduledoc false
        use Filtr.Plugin

        @impl true
        def types, do: [:string, :custom_type]
      end

      Application.put_env(:filtr, :plugins, [TestPluginOverride])

      type_map = Helpers.type_plugin_map()

      assert type_map[:string] == TestPluginOverride
      assert type_map[:custom_type] == TestPluginOverride

      assert type_map[:integer] == Filtr.DefaultPlugin
      assert type_map[:boolean] == Filtr.DefaultPlugin

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "handles empty plugin types list" do
      original_plugins = Application.get_env(:filtr, :plugins)
      :persistent_term.erase(:filtr_type_plugin_map)

      defmodule EmptyPlugin do
        @moduledoc false
        use Filtr.Plugin

        @impl true
        def types, do: []
      end

      Application.put_env(:filtr, :plugins, [EmptyPlugin])

      type_map = Helpers.type_plugin_map()

      assert type_map[:string] == Filtr.DefaultPlugin

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end

    test "caches the type plugin map in persistent_term" do
      original_plugins = Application.get_env(:filtr, :plugins)
      :persistent_term.erase(:filtr_type_plugin_map)

      Application.delete_env(:filtr, :plugins)

      # First call should build and cache
      map1 = Helpers.type_plugin_map()
      # Second call should return cached version
      map2 = Helpers.type_plugin_map()

      assert map1 == map2
      assert :persistent_term.get(:filtr_type_plugin_map) == map1

      Application.put_env(:filtr, :plugins, original_plugins)
      :persistent_term.erase(:filtr_type_plugin_map)
    end
  end
end
