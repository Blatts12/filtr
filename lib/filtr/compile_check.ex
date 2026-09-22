defmodule Filtr.CompileCheck do
  @moduledoc """
  Compile-time checks for the types you declare with `param`.

  A typo like `param :age, :intger` used to compile without a word and then fail on the
  first request with "missing plugin for type :intger". The mistake lives in the schema,
  not in the request, so this module looks the type up while your module compiles and
  raises there instead.

  `Filtr.Controller` and `Filtr.LiveView` call it for you. Reach for `check_type!/2`
  directly only when you build Filtr schemas from a macro of your own.

  ## What gets checked

  The `:type` of a param, and nothing else. A type passes when it is one of these:

  - an atom some plugin lists in `types/0`, which is what `Filtr.Helpers.type_plugin_map/0`
    collects
  - `nil` or `:__none__`, the two passthrough markers
  - a `{:list, type}` tuple whose inner type passes
  - a nested schema map, checked key by key
  - a function of arity 1, 2 or 3, the arities `Filtr.Processor.Cast` knows how to call

  Anything the macro cannot see as a literal is left alone. Write `param :price, @money`
  or `param :price, type_from_config()` and the check steps aside, because the value only
  exists once the module runs. You keep the flexibility, and you lose the safety net for
  that one param.

  ## Types from your own plugins

  Types come from plugins, and plugins come from config, so the check reads
  `config :filtr, plugins: [...]` the same way the runtime does. Two limits follow from
  that.

  A plugin registered at runtime with `Application.put_env/3` is invisible at compile
  time, and a param using its types would fail to compile. The same goes for a plugin the
  compiler cannot resolve yet. The check treats both as "I cannot know" and skips silently
  rather than blaming code that is fine.

  If a setup of yours still trips it, turn the check off:

      config :filtr, compile_checks: false

  A word of caution before you do. Filtr reads this at compile time, so changing it means
  recompiling Filtr itself with `mix deps.compile filtr --force`, and every typo goes back
  to being a runtime error.
  """

  alias Filtr.Types

  @enabled Application.compile_env(:filtr, :compile_checks, true)

  @doc """
  Checks the type of a single param, raising `ArgumentError` when it cannot work.

  Returns `:ok` for a type that passes and for a type it cannot resolve. The key is only
  used to name the offending param in the error message.

  ## Examples

      iex> Filtr.CompileCheck.check_type!(:age, :integer)
      :ok

      iex> Filtr.CompileCheck.check_type!(:tags, {:list, :string})
      :ok

  A type nobody claims, such as `:intger`, raises instead.
  """
  @spec check_type!(Types.key() | nil, Types.key_type()) :: :ok

  if @enabled do
    import Filtr.Processor.Opaque, only: [is_opaque: 1]

    alias Filtr.Plugin

    @suggestion_threshold 0.8

    def check_type!(key, type), do: check(key, type)

    defp check(_key, type) when is_opaque(type), do: :ok
    defp check(_key, type) when is_function(type, 1) or is_function(type, 2) or is_function(type, 3), do: :ok
    defp check(key, type) when is_function(type), do: raise_invalid_function_arity!(key, type)
    defp check(key, {:list, inner_type}), do: check(key, inner_type)
    defp check(_key, type) when is_map(type), do: check_schema(type)
    defp check(key, type) when is_atom(type), do: check_known_type!(key, type)
    defp check(key, type) when is_binary(type) or is_number(type), do: raise_invalid_type!(key, type)

    # A type the macro cannot see as a literal, such as a module attribute or a variable.
    defp check(_key, _type), do: :ok

    defp check_schema(schema) do
      Enum.each(schema, fn
        {key, %{type: type}} -> check(key, type)
        _entry -> :ok
      end)
    end

    defp check_known_type!(key, type) do
      case all_known_types() do
        :unknown -> :ok
        types -> if type in types, do: :ok, else: raise_unknown_type!(key, type, types)
      end
    end

    defp all_known_types do
      Enum.reduce_while(Plugin.all(), [], fn plugin, acc ->
        case get_plugin_types(plugin) do
          {:ok, types} -> {:cont, types ++ acc}
          :error -> {:halt, :unknown}
        end
      end)
    end

    defp get_plugin_types(plugin) do
      with {:module, module} <- Code.ensure_compiled(plugin),
           true <- function_exported?(module, :types, 0) do
        {:ok, module.types()}
      else
        _other -> :error
      end
    end

    defp raise_unknown_type!(key, type, types) do
      raise ArgumentError, """
      unknown type #{inspect(type)} for param #{param_name(key)}
      #{suggestion(type, types)}
      Known types: #{types |> Enum.sort() |> Enum.map_join(", ", &inspect/1)}

      A type has to be one of the types above, a {:list, type} tuple, a nested schema map,
      nil to pass the value through, or a function of arity 1, 2 or 3.

      Types come from plugins. Register yours with:

          config :filtr, plugins: [MyApp.MyPlugin]
      """
    end

    defp raise_invalid_type!(key, type) do
      raise ArgumentError, """
      invalid type #{inspect(type)} for param #{param_name(key)}

      A type has to be a type atom such as :string, a {:list, type} tuple, a nested schema
      map, nil to pass the value through, or a function of arity 1, 2 or 3.
      """
    end

    defp raise_invalid_function_arity!(key, fun) do
      {:arity, arity} = Function.info(fun, :arity)

      raise ArgumentError, """
      the cast function for param #{param_name(key)} takes #{arity} arguments

      Filtr picks the clause by arity, so a cast function has to take one of these:

          value
          value, context
          value, key_schema, context
      """
    end

    defp suggestion(type, types) do
      name = Atom.to_string(type)

      types
      |> Enum.map(&{String.jaro_distance(name, Atom.to_string(&1)), &1})
      |> Enum.filter(fn {score, _candidate} -> score >= @suggestion_threshold end)
      |> Enum.sort(:desc)
      |> case do
        [{_score, candidate} | _rest] -> "\nDid you mean #{inspect(candidate)}?\n"
        [] -> ""
      end
    end

    defp param_name(nil), do: "in your schema"
    defp param_name(key), do: inspect(key)
  else
    def check_type!(_key, _type), do: :ok
  end
end
