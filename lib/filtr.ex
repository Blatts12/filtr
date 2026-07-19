defmodule Filtr do
  @moduledoc "Main file"

  alias Filtr.Helpers

  @spec run(schema :: map(), params :: map()) :: map()
  @spec run(schema :: map(), params :: map(), run_opts :: keyword()) :: map()
  def run(schema, params, run_opts \\ []) do
    run_opts = Keyword.put(run_opts, :plugin_map, Helpers.type_plugin_map())

    Filtr.Processor.run(schema, params, run_opts)
  end

  @doc """
  Collects all errors from a Filtr result map into a structured error map.

  This function is primarily useful when using `:strict` error mode, where errors
  are returned as `{:error, [...]}` tuples in the result map rather than being
  replaced with default values (`:fallback`) or raising exceptions (`:raise`).

  This function traverses the result map returned by `Filtr.run/2` or `Filtr.run/3` and extracts
  all error tuples, organizing them into a hierarchical structure that mirrors the
  original schema structure.
  ## Examples

      iex> result = %{name: {:error, "required"}, age: 25}
      iex> Filtr.collect_errors(result)
      %{name: ["required"]}


      iex> result = %{name: "John", age: 25}
      iex> Filtr.collect_errors(result)
      nil

      iex> result = %{
      ...>   user: %{
      ...>     name: {:error, "required"},
      ...>     age: 25
      ...>   }
      ...> }
      iex> Filtr.collect_errors(result)
      %{user: %{name: ["required"]}}

      iex> result = %{tags: ["valid", {:error, "too short"}, "another"]}
      iex> Filtr.collect_errors(result)
      %{tags: %{1 => ["too short"]}}

      iex> result = %{
      ...>   users: [
      ...>     %{id: 1, name: "john"},
      ...>     %{id: 2, name: {:error, "required"}}
      ...>   ]
      ...> }
      iex> Filtr.collect_errors(result)
      %{users: %{1 => %{name: ["required"]}}}

  """
  @spec collect_errors(filtr_result :: map()) :: map() | nil
  def collect_errors(filtr_result) do
    errors = do_collect_errors(filtr_result)
    if errors == %{}, do: nil, else: errors
  end

  defp do_collect_errors(filtr_result) do
    Enum.reduce(filtr_result, %{}, fn
      {key, {:error, errors}}, acc ->
        Map.put(acc, key, List.wrap(errors))

      {key, value}, acc when is_map(value) ->
        errors = do_collect_errors(value)
        if errors == %{}, do: acc, else: Map.put(acc, key, errors)

      {key, [value | _] = values}, acc when is_map(value) ->
        errors =
          values
          |> Enum.reduce({%{}, 0}, fn value, {nested_acc, index} ->
            nested_errors = do_collect_errors(value)
            nested_acc = if nested_errors == %{}, do: nested_acc, else: Map.put(nested_acc, index, nested_errors)
            {nested_acc, index + 1}
          end)
          |> elem(0)

        if errors == %{}, do: acc, else: Map.put(acc, key, errors)

      {key, values}, acc when is_list(values) ->
        errors =
          values
          |> Enum.with_index()
          |> Enum.reduce(%{}, fn
            {{:error, error}, index}, nested_acc -> Map.put(nested_acc, index, List.wrap(error))
            _, nested_acc -> nested_acc
          end)

        if errors == %{}, do: acc, else: Map.put(acc, key, errors)

      _, acc ->
        acc
    end)
  end
end
