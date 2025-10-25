defmodule Pex.DefaultPlugin.Validate do
  @moduledoc false

  @spec validate(value :: any(), type :: atom(), validator :: {atom(), term()}, opts :: keyword()) ::
          Pex.Plugin.validate_result()

  # String
  def validate(value, :string, {:length, length}, _opts) do
    if String.length(value) == length,
      do: :ok,
      else: {:error, "must be exactly #{length} characters long"}
  end

  def validate(value, :string, {:min, min}, _opts) do
    if String.length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} characters long"}
  end

  def validate(value, :string, {:max, max}, _opts) do
    if String.length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} characters long"}
  end

  def validate(value, :string, {:pattern, pattern}, _opts) do
    if value =~ pattern,
      do: :ok,
      else: {:error, "does not match pattern"}
  end

  def validate(value, :string, {:starts_with, prefix}, _opts) do
    if String.starts_with?(value, prefix),
      do: :ok,
      else: {:error, "does not start with #{prefix}"}
  end

  def validate(value, :string, {:ends_with, suffix}, _opts) do
    if String.ends_with?(value, suffix),
      do: :ok,
      else: {:error, "does not end with #{suffix}"}
  end

  def validate(value, :string, {:contains, substring}, _opts) do
    if String.contains?(value, substring),
      do: :ok,
      else: {:error, "must contain '#{substring}'"}
  end

  @alphanumeric_regex ~r/^[a-zA-Z0-9]+$/

  def validate(value, :string, {:alphanumeric, true}, _opts) do
    if value =~ @alphanumeric_regex,
      do: :ok,
      else: {:error, "must contain only letters and numbers"}
  end

  # Integer
  def validate(value, :integer, {:min, min}, _opts) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  def validate(value, :integer, {:max, max}, _opts) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  def validate(value, :integer, {:positive, true}, _opts) when is_number(value) do
    if value > 0, do: :ok, else: {:error, "must be positive"}
  end

  def validate(value, :integer, {:negative, true}, _opts) when is_number(value) do
    if value < 0, do: :ok, else: {:error, "must be negative"}
  end

  # Float
  def validate(value, :float, {:min, min}, _opts) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  def validate(value, :float, {:max, max}, _opts) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  def validate(value, :float, {:positive, true}, _opts) when is_number(value) do
    if value > 0, do: :ok, else: {:error, "must be positive"}
  end

  def validate(value, :float, {:negative, true}, _opts) when is_number(value) do
    if value < 0, do: :ok, else: {:error, "must be negative"}
  end

  # Date
  def validate(value, :date, {:min, min}, _opts) do
    if Date.compare(value, min) in [:gt, :eq],
      do: :ok,
      else: {:error, "must be after or equal to #{min}"}
  end

  def validate(value, :date, {:max, max}, _opts) do
    if Date.compare(value, max) in [:lt, :eq],
      do: :ok,
      else: {:error, "must be before or equal to #{max}"}
  end

  # DateTime
  def validate(value, :datetime, {:min, min}, _opts) do
    if DateTime.compare(value, min) in [:gt, :eq],
      do: :ok,
      else: {:error, "must be after or equal to #{min}"}
  end

  def validate(value, :datetime, {:max, max}, _opts) do
    if DateTime.compare(value, max) in [:lt, :eq],
      do: :ok,
      else: {:error, "must be before or equal to #{max}"}
  end

  # List
  def validate(value, :list, {:min, min}, _opts) do
    if length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} items long"}
  end

  def validate(value, :list, {:max, max}, _opts) do
    if length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} items long"}
  end

  def validate(value, :list, {:length, len}, _opts) when is_list(value) do
    if length(value) == len,
      do: :ok,
      else: {:error, "must be exactly #{len} items long"}
  end

  def validate(value, :list, {:unique, true}, _opts) when is_list(value) do
    if length(value) == length(Enum.uniq(value)),
      do: :ok,
      else: {:error, "must contain unique values"}
  end

  def validate(value, :list, {:non_empty, true}, _opts) when is_list(value) do
    if value == [], do: {:error, "must not be empty"}, else: :ok
  end

  def validate(values, :list, {:in, list}, _opts) do
    if Enum.any?(values, &(&1 not in list)),
      do: {:error, "invalid value in list"},
      else: :ok
  end

  # General
  def validate(value, _, {:in, list}, _opts) when is_list(list) do
    if value in list, do: :ok, else: {:error, "must be one of: #{Enum.join(list, ", ")}"}
  end
end
