defmodule Filtr.Errors do
  @moduledoc """
  Collects errors out of a result map returned by `Filtr.run/2` or `Filtr.run/3`.

  See `Filtr.collect_errors/1` for the public entry point and examples.
  """

  @doc """
  Walks a result map and returns its errors, or `nil` when there are none.
  """
  @spec collect(filtr_result :: map()) :: map() | nil
  # `Filtr.run/3` sets `_valid?` to false as soon as any key fails, so a true flag
  # means there is nothing to find and the walk can be skipped.
  def collect(%{_valid?: true}), do: nil

  def collect(filtr_result) do
    case collect_map(filtr_result) do
      errors when map_size(errors) == 0 -> nil
      errors -> errors
    end
  end

  defp collect_map(map) do
    :maps.fold(fn key, value, acc -> put_errors(acc, key, collect_value(value)) end, %{}, map)
  end

  defp collect_list([], _index, acc), do: acc

  defp collect_list([value | values], index, acc) do
    collect_list(values, index + 1, put_errors(acc, index, collect_value(value)))
  end

  defp collect_value({:error, errors}), do: List.wrap(errors)
  defp collect_value(%_{}), do: %{}
  defp collect_value(value) when is_map(value), do: collect_map(value)
  defp collect_value(values) when is_list(values), do: collect_list(values, 0, %{})
  defp collect_value(_value), do: %{}

  defp put_errors(acc, _key, errors) when errors == %{}, do: acc
  defp put_errors(acc, key, errors), do: Map.put(acc, key, errors)
end
