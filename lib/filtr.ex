defmodule Filtr do
  @moduledoc "Main file"

  @spec run(schema :: map(), params :: map()) :: map()
  @spec run(schema :: map(), params :: map(), run_opts :: keyword()) :: map()
  def run(schema, params, run_opts \\ []) do
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
  defdelegate collect_errors(filtr_result), to: Filtr.Errors, as: :collect
end
