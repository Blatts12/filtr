defmodule Pex.Validator do
  @moduledoc false

  @common_opts [:validate]
  @string_opts [:min, :max, :in, :pattern, :starts_with, :ends_with]
  @integer_opts [:min, :max, :in]
  @float_opts [:min, :max, :in]
  @date_opts [:min, :max, :in]
  @datetime_opts [:min, :max, :in]
  @list_opts [:min, :max]
  @none_opts []

  @supported_opts %{
    string: @string_opts,
    integer: @integer_opts,
    float: @float_opts,
    date: @date_opts,
    datetime: @datetime_opts,
    list: @list_opts,
    __none__: @none_opts
  }

  @spec run(value :: any(), type :: Pex.supported_types()) ::
          {:ok, any()} | {:error, [binary()] | binary()}
  @spec run(value :: any(), type :: Pex.supported_types(), opts :: keyword()) ::
          {:ok, any()} | {:error, [binary()] | binary()}
  def run(value, type, opts \\ []) do
    opts = Keyword.take(opts, Map.get(@supported_opts, type, []) ++ @common_opts)

    with :ok <- check_required(value, opts),
         :ok <- valid_value(value, type, opts) do
      {:ok, value}
    end
  end

  defp check_required(value, opts) do
    case Keyword.get(opts, :required, false) do
      true when value in ["", nil] -> {:error, "required"}
      _ -> :ok
    end
  end

  defp valid_value(value, type, opts) do
    errors =
      Enum.map(opts, fn {opt, check} -> valid?(opt, value, type, check) end)
      |> Enum.filter(&match?({:error, _}, &1))
      |> Enum.map(&elem(&1, 1))

    if errors == [],
      do: :ok,
      else: {:error, errors}
  end

  # In
  defp valid?(:in, values, :list, list) do
    if Enum.any?(values, &(&1 not in list)),
      do: {:error, "invalid value in list"},
      else: :ok
  end

  defp valid?(:in, value, _type, list) do
    if value in list, do: :ok, else: {:error, "value not in list"}
  end

  # Max
  defp valid?(:max, value, :string, max) do
    if String.length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} characters long"}
  end

  defp valid?(:max, value, :integer, max) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  defp valid?(:max, value, :float, max) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  defp valid?(:max, value, :date, max) do
    if Date.compare(value, max) in [:lt, :eq],
      do: :ok,
      else: {:error, "must be before or equal to #{max}"}
  end

  defp valid?(:max, value, :datetime, max) do
    if DateTime.compare(value, max) in [:lt, :eq],
      do: :ok,
      else: {:error, "must be before or equal to #{max}"}
  end

  defp valid?(:max, value, :list, max) do
    if length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} items long"}
  end

  # Min
  defp valid?(:min, value, :string, min) do
    if String.length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} characters long"}
  end

  defp valid?(:min, value, :integer, min) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  defp valid?(:min, value, :float, min) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  defp valid?(:min, value, :date, min) do
    if Date.compare(value, min) in [:gt, :eq],
      do: :ok,
      else: {:error, "must be after or equal to #{min}"}
  end

  defp valid?(:min, value, :datetime, min) do
    if DateTime.compare(value, min) in [:gt, :eq],
      do: :ok,
      else: {:error, "must be after or equal to #{min}"}
  end

  defp valid?(:min, value, :list, min) do
    if length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} items long"}
  end

  # Pattern
  defp valid?(:pattern, value, :string, pattern) do
    if value =~ pattern, do: :ok, else: {:error, "does not match pattern"}
  end

  # Starts with
  defp valid?(:starts_with, value, :string, prefix) do
    if String.starts_with?(value, prefix),
      do: :ok,
      else: {:error, "does not start with #{prefix}"}
  end

  # Ends with
  defp valid?(:ends_with, value, :string, suffix) do
    if String.ends_with?(value, suffix),
      do: :ok,
      else: {:error, "does not end with #{suffix}"}
  end

  # Custom
  defp valid?(:validate, value, _type, valid_fn) when is_function(valid_fn, 1) do
    case valid_fn.(value) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
      false -> {:error, "validation failed"}
      _ -> :ok
    end
  end

  defp valid?(opt, _value, _type, _check) when opt in [:required], do: :ok
  defp valid?(op, _value, type, _check), do: raise("unsupported validation: #{op}, type: #{type}")
end
