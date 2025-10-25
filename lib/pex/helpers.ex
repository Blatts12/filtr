defmodule Pex.Helpers do
  @moduledoc false

  @spec default_error_mode() :: atom()
  def default_error_mode do
    Application.get_env(:pex, :error_mode) || :fallback
  end

  @spec plugins() :: [module()]
  def plugins do
    [Pex.DefaultPlugin] ++ Application.get_env(:pex, :plugins, [])
  end

  @spec type_plugin_map() :: %{atom() => module()}
  def type_plugin_map do
    Enum.reduce(plugins(), %{}, fn plugin, type_map ->
      types = plugin.types()

      Enum.reduce(types, type_map, fn type, type_map ->
        Map.update(type_map, type, [plugin], fn p -> [plugin | p] end)
      end)
    end)
  end
end
