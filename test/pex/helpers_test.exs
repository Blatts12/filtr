defmodule Pex.HelpersTest do
  use ExUnit.Case, async: false

  alias Pex.Helpers

  describe "default_error_mode/0" do
    test "returns :fallback when no configuration is set" do
      original_value = Application.get_env(:pex, :error_mode)

      Application.delete_env(:pex, :error_mode)
      assert Helpers.default_error_mode() == :fallback

      Application.put_env(:pex, :error_mode, original_value)
    end

    test "returns configured error mode when set" do
      original_value = Application.get_env(:pex, :error_mode)

      Application.put_env(:pex, :error_mode, :strict)
      assert Helpers.default_error_mode() == :strict

      Application.put_env(:pex, :error_mode, original_value)
    end
  end

  describe "plugins/0" do
    test "returns DefaultPlugin" do
      original_plugins = Application.get_env(:pex, :plugins, [])

      Application.delete_env(:pex, :plugins)
      assert Helpers.plugins() == [Pex.DefaultPlugin]

      Application.put_env(:pex, :plugins, original_plugins)
    end

    test "includes additional plugins from configuration" do
      original_plugins = Application.get_env(:pex, :plugins, [])

      defmodule TestPlugin do
        use Pex.Plugin
      end

      Application.put_env(:pex, :plugins, [TestPlugin])
      # Default plugin is always first
      assert [Pex.DefaultPlugin, TestPlugin] = Helpers.plugins()

      Application.put_env(:pex, :plugins, original_plugins)
    end
  end

  describe "type_plugin_map/0" do
    test "builds a map from types to their plugins" do
      original_plugins = Application.get_env(:pex, :plugins, [])

      Application.delete_env(:pex, :plugins)

      type_map = Helpers.type_plugin_map()

      assert type_map[:string] == Pex.DefaultPlugin
      assert type_map[:integer] == Pex.DefaultPlugin
      assert type_map[:float] == Pex.DefaultPlugin
      assert type_map[:boolean] == Pex.DefaultPlugin
      assert type_map[:time] == Pex.DefaultPlugin
      assert type_map[:date] == Pex.DefaultPlugin
      assert type_map[:datetime] == Pex.DefaultPlugin
      assert type_map[:list] == Pex.DefaultPlugin

      Application.put_env(:pex, :plugins, original_plugins)
    end

    test "later plugins override earlier plugins for the same type" do
      original_plugins = Application.get_env(:pex, :plugins)

      defmodule TestPluginOverride do
        use Pex.Plugin

        @impl true
        def types, do: [:string, :custom_type]
      end

      Application.put_env(:pex, :plugins, [TestPluginOverride])

      type_map = Helpers.type_plugin_map()

      assert type_map[:string] == TestPluginOverride
      assert type_map[:custom_type] == TestPluginOverride

      assert type_map[:integer] == Pex.DefaultPlugin
      assert type_map[:boolean] == Pex.DefaultPlugin

      Application.put_env(:pex, :plugins, original_plugins)
    end

    test "handles empty plugin types list" do
      original_plugins = Application.get_env(:pex, :plugins)

      defmodule EmptyPlugin do
        use Pex.Plugin

        @impl true
        def types, do: []
      end

      Application.put_env(:pex, :plugins, [EmptyPlugin])

      type_map = Helpers.type_plugin_map()

      assert type_map[:string] == Pex.DefaultPlugin

      Application.put_env(:pex, :plugins, original_plugins)
    end
  end
end
