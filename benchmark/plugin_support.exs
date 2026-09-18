# Shared setup for the plugin benchmarks (plugins.exs, plugin_registration.exs).
#
# Defines ten trivial plugins, each contributing one custom type (:custom_1 ..
# :custom_10) that casts any value through unchanged and accepts any validator,
# plus helpers to (re)register a subset of them from a Benchee `before_scenario`.

for n <- 1..10 do
  defmodule Module.concat(FiltrBench.Plugins, "Plugin#{n}") do
    @moduledoc false
    use Filtr.Plugin

    @custom_type String.to_atom("custom_#{n}")

    @impl true
    def types, do: [@custom_type]

    @impl true
    def cast(value, @custom_type, _ctx), do: {:ok, value}

    @impl true
    def validate(_value, @custom_type, _validator, _ctx), do: :ok
  end
end

defmodule FiltrBench.PluginSupport do
  @moduledoc false

  @all for n <- 1..10, do: Module.concat(FiltrBench.Plugins, "Plugin#{n}")

  @doc "The first `count` trivial plugins."
  def take(count), do: Enum.take(@all, count)

  @doc "Registers `plugins` as the app's plugin list (no cache rebuild)."
  def configure(plugins), do: Application.put_env(:filtr, :plugins, plugins)

  @doc """
  Registers `plugins` and rebuilds the cached type->plugin map so the change
  takes effect for `Filtr.run/2`.
  """
  def register(plugins) do
    configure(plugins)
    :persistent_term.erase(:filtr_type_plugin_map)
    Filtr.Helpers.type_plugin_map()
    :ok
  end

  @doc "Restores the global plugin config to its default (no extra plugins)."
  def reset do
    Application.delete_env(:filtr, :plugins)
    :persistent_term.erase(:filtr_type_plugin_map)
    :ok
  end
end
