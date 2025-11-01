defmodule Filtr.Helpers do
  @moduledoc """
    Helper functions
  """

  @type_plugin_map_key :filtr_type_plugin_map

  @spec default_error_mode() :: atom()
  def default_error_mode do
    Application.get_env(:filtr, :error_mode) || :fallback
  end

  @spec type_plugin_map() :: %{atom() => [module()]}
  def type_plugin_map do
    case :persistent_term.get(@type_plugin_map_key, nil) do
      nil ->
        map = build_type_plugin_map()
        :persistent_term.put(@type_plugin_map_key, map)
        map

      map ->
        map
    end
  end

  defp build_type_plugin_map do
    plugins = Application.get_env(:filtr, :plugins) || []
    all_plugins = [Filtr.DefaultPlugin | plugins]

    Enum.reduce(all_plugins, %{}, fn plugin, type_map ->
      types = plugin.types()

      Enum.reduce(types, type_map, fn type, type_map ->
        Map.update(type_map, type, [plugin], fn p -> [plugin | p] end)
      end)
    end)
  end

  @run_opts_keys [:error_mode]

  @spec parse_param_opts(keyword()) :: keyword()
  def parse_param_opts(opts) do
    validators = Keyword.drop(opts, [:type] ++ @run_opts_keys)

    opts
    |> Keyword.take([:type] ++ @run_opts_keys)
    |> Keyword.put(:validators, validators)
  end
end
