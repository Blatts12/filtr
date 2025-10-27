defmodule Filtr.HelpersTest do
  use ExUnit.Case, async: false

  alias Filtr.Helpers

  describe "default_error_mode/0" do
    test "returns :fallback when no configuration is set" do
      original_value = Application.get_env(:filtr, :error_mode)

      Application.delete_env(:filtr, :error_mode)
      assert Helpers.default_error_mode() == :fallback

      Application.put_env(:filtr, :error_mode, original_value)
    end

    test "returns configured error mode when set" do
      original_value = Application.get_env(:filtr, :error_mode)

      Application.put_env(:filtr, :error_mode, :strict)
      assert Helpers.default_error_mode() == :strict

      Application.put_env(:filtr, :error_mode, original_value)
    end
  end

  describe "type_plugin_map/0" do
    test "builds a map from types to their plugins" do
      original_plugins = Application.get_env(:filtr, :plugins, [])
      :persistent_term.erase(:filtr_type_plugin_map)

      Application.delete_env(:filtr, :plugins)

      type_map = Helpers.type_plugin_map()

      assert type_map[:string] == [Filtr.DefaultPlugin]
      assert type_map[:integer] == [Filtr.DefaultPlugin]
      assert type_map[:float] == [Filtr.DefaultPlugin]
      assert type_map[:boolean] == [Filtr.DefaultPlugin]
      assert type_map[:time] == [Filtr.DefaultPlugin]
      assert type_map[:date] == [Filtr.DefaultPlugin]
      assert type_map[:datetime] == [Filtr.DefaultPlugin]
      assert type_map[:list] == [Filtr.DefaultPlugin]

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

      assert type_map[:string] == [TestPluginOverride, Filtr.DefaultPlugin]
      assert type_map[:custom_type] == [TestPluginOverride]

      assert type_map[:integer] == [Filtr.DefaultPlugin]
      assert type_map[:boolean] == [Filtr.DefaultPlugin]

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

      assert type_map[:string] == [Filtr.DefaultPlugin]

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
