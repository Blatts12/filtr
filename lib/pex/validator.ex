defmodule Pex.Validator do
  @moduledoc """
  Provides validation functionality for parameter values based on their types and constraints.

  This module handles all validation logic for Pex, supporting both built-in validators
  for common data types and custom validation functions. It works in conjunction with
  `Pex.Caster` to ensure parameters are both properly cast and validated.

  ## Supported Validators

  ### Common Validators
  - `required` - Ensures the value is not empty or nil
  - `validate` - Custom validation function
  - `not_nil` - Must not be nil (allows empty strings)

  ### String Validators
  - `min` - Minimum string length
  - `max` - Maximum string length
  - `pattern` - Regex pattern matching
  - `starts_with` - String must start with specified prefix
  - `ends_with` - String must end with specified suffix
  - `in` - Value must be in the provided list
  - `contains` - String must contain specified substring
  - `length` - Exact string length requirement
  - `alphanumeric` - Must contain only letters and numbers

  ### Numeric Validators (Integer/Float)
  - `min` - Minimum numeric value
  - `max` - Maximum numeric value
  - `in` - Value must be in the provided list
  - `positive` - Must be greater than zero
  - `negative` - Must be less than zero

  ### Date/DateTime Validators
  - `min` - Minimum date/datetime
  - `max` - Maximum date/datetime
  - `in` - Value must be in the provided list

  ### List Validators
  - `min` - Minimum list length
  - `max` - Maximum list length
  - `in` - All values in list must be in the provided list
  - `unique` - All items must be unique
  - `non_empty` - List cannot be empty

  ## Examples

      # Basic validation
      Validator.run("hello", :string, [min: 3, max: 10])
      # => {:ok, "hello"}

      # Failed validation
      Validator.run("hi", :string, [min: 5])
      # => {:error, ["must be at least 5 characters long"]}

      # Custom validation
      email_validator = fn email ->
        if String.contains?(email, "@") do
          :ok
        else
          {:error, "must be a valid email"}
        end
      end

      Validator.run("user@example.com", :string, [validate: email_validator])
      # => {:ok, "user@example.com"}}

      # Numeric validation
      Validator.run(42, :integer, [positive: true])
      # => {:ok, 42}

      # List validation
      Validator.run([1, 2, 3], :list, [unique: true, non_empty: true])
      # => {:ok, [1, 2, 3]}

  This module is typically used internally by `Pex.run/2` and `Pex.run/3`, but can be
  used directly for custom validation scenarios.
  """

  @common_opts [:validate, :required, :not_nil]
  @string_opts [
    :min,
    :max,
    :in,
    :pattern,
    :starts_with,
    :ends_with,
    :contains,
    :length,
    :alphanumeric
  ]
  @integer_opts [:min, :max, :in, :positive, :negative]
  @float_opts [:min, :max, :in, :positive, :negative]
  @date_opts [:min, :max, :in]
  @datetime_opts [:min, :max, :in]
  @list_opts [:min, :max, :in, :unique, :non_empty]

  @supported_opts %{
    string: @string_opts,
    integer: @integer_opts,
    float: @float_opts,
    date: @date_opts,
    datetime: @datetime_opts,
    list: @list_opts,
    __none__: []
  }

  @doc """
  Validates a value according to its type and validation options.

  This function applies validation rules to a value that has already been cast to
  its appropriate type. It checks constraints like minimum/maximum values, required
  fields, pattern matching, and custom validation functions.

  ## Parameters

  - `value` - The value to validate (should already be cast to the correct type)
  - `type` - The expected type of the value (one of `Pex.supported_types()`)
  - `opts` - Keyword list of validation options

  ## Returns

  - `{:ok, value}` when validation passes
  - `{:error, error_message}` when a single validation fails
  - `{:error, [error_messages]}` when multiple validations fail

  ## Examples

      # String validation
      Validator.run("hello", :string, [min: 3, max: 10])
      # => {:ok, "hello"}

      Validator.run("hi", :string, [min: 5])
      # => {:error, ["must be at least 5 characters long"]}

      # Numeric validation
      Validator.run(25, :integer, [min: 18, max: 65])
      # => {:ok, 25}

      # Pattern matching
      Validator.run("hello@example.com", :string, [pattern: ~r/@/])
      # => {:ok, "hello@example.com"}

      # Custom validation
      Validator.run("test", :string, [
        validate: fn value ->
          if String.length(value) > 2, do: :ok, else: {:error, "too short"}
        end
      ])
      # => {:ok, "test"}

      # Required validation
      Validator.run(nil, :string, [required: true])
      # => {:error, "required"}

      # Multiple validation failures
      Validator.run("x", :string, [min: 5, pattern: ~r/\\d+/])
      # => {:error, ["must be at least 5 characters long", "does not match pattern"]}

  ## Custom Validation Functions

  Custom validation functions can return:
  - `:ok` - validation passes
  - `{:ok, _}` - validation passes (return value ignored)
  - `{:error, message}` - validation fails with custom message
  - `:error` - validation fails with generic message
  - `false` - validation fails with generic message
  - Any other value - validation passes
  """
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

  # STRING VALIDATORS

  ## min length
  defp valid?(:min, value, :string, min) do
    if String.length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} characters long"}
  end

  ## max length
  defp valid?(:max, value, :string, max) do
    if String.length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} characters long"}
  end

  ## pattern
  defp valid?(:pattern, value, :string, pattern) when is_binary(value) do
    if value =~ pattern, do: :ok, else: {:error, "does not match pattern"}
  end

  defp valid?(:pattern, nil, :string, _pattern) do
    {:error, "does not match pattern"}
  end

  ## starts with
  defp valid?(:starts_with, value, :string, prefix) when is_binary(value) do
    if String.starts_with?(value, prefix),
      do: :ok,
      else: {:error, "does not start with #{prefix}"}
  end

  defp valid?(:starts_with, nil, :string, prefix) do
    {:error, "does not start with #{prefix}"}
  end

  ## ends with
  defp valid?(:ends_with, value, :string, suffix) when is_binary(value) do
    if String.ends_with?(value, suffix),
      do: :ok,
      else: {:error, "does not end with #{suffix}"}
  end

  defp valid?(:ends_with, nil, :string, suffix) do
    {:error, "does not end with #{suffix}"}
  end

  ## contains
  defp valid?(:contains, value, :string, substring) when is_binary(value) do
    if String.contains?(value, substring),
      do: :ok,
      else: {:error, "must contain '#{substring}'"}
  end

  defp valid?(:contains, nil, :string, substring) do
    {:error, "must contain '#{substring}'"}
  end

  ## exact length
  defp valid?(:length, value, :string, length) when is_binary(value) do
    if String.length(value) == length,
      do: :ok,
      else: {:error, "must be exactly #{length} characters long"}
  end

  defp valid?(:length, nil, :string, length) do
    {:error, "must be exactly #{length} characters long"}
  end

  ## alphanumeric
  defp valid?(:alphanumeric, value, :string, true) when is_binary(value) do
    alphanumeric_regex = ~r/^[a-zA-Z0-9]+$/

    if value =~ alphanumeric_regex,
      do: :ok,
      else: {:error, "must contain only letters and numbers"}
  end

  defp valid?(:alphanumeric, nil, :string, true) do
    {:error, "must contain only letters and numbers"}
  end

  # NUMERIC VALIDATORS

  ## Integer min value
  defp valid?(:min, value, :integer, min) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  ## Integer max value
  defp valid?(:max, value, :integer, max) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  ## Float min value
  defp valid?(:min, value, :float, min) do
    if value >= min, do: :ok, else: {:error, "must be at least #{min}"}
  end

  ## Float max value
  defp valid?(:max, value, :float, max) do
    if value <= max, do: :ok, else: {:error, "must be at most #{max}"}
  end

  ## Positive (integer/float)
  defp valid?(:positive, value, type, true)
       when type in [:integer, :float] and is_number(value) do
    if value > 0, do: :ok, else: {:error, "must be positive"}
  end

  ## Negative (integer/float)
  defp valid?(:negative, value, type, true)
       when type in [:integer, :float] and is_number(value) do
    if value < 0, do: :ok, else: {:error, "must be negative"}
  end

  # DATE/DATETIME VALIDATORS

  ## min
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

  ## max
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

  # LIST VALIDATORS

  ## min length
  defp valid?(:min, value, :list, min) do
    if length(value) >= min,
      do: :ok,
      else: {:error, "must be at least #{min} items long"}
  end

  ## max length
  defp valid?(:max, value, :list, max) do
    if length(value) <= max,
      do: :ok,
      else: {:error, "must be at most #{max} items long"}
  end

  ## exact length
  defp valid?(:length, value, :list, length) when is_list(value) do
    if length(value) == length,
      do: :ok,
      else: {:error, "must be exactly #{length} items long"}
  end

  ## unique values
  defp valid?(:unique, value, :list, true) when is_list(value) do
    if length(value) == length(Enum.uniq(value)),
      do: :ok,
      else: {:error, "must contain unique values"}
  end

  ## non-empty
  defp valid?(:non_empty, value, :list, true) when is_list(value) do
    if value != [], do: :ok, else: {:error, "must not be empty"}
  end

  ## in (all values must be in provided list)
  defp valid?(:in, values, :list, list) do
    if Enum.any?(values, &(&1 not in list)),
      do: {:error, "invalid value in list"},
      else: :ok
  end

  # GENERIC VALIDATORS

  # in (value must be in provided list)
  defp valid?(:in, value, _type, list) do
    if value in list, do: :ok, else: {:error, "value not in list"}
  end

  # Not nil validation (different from required - allows empty strings)
  defp valid?(:not_nil, value, _type, true) do
    if value != nil, do: :ok, else: {:error, "must not be nil"}
  end

  # Custom validation function
  defp valid?(:validate, value, _type, valid_fn) when is_function(valid_fn, 1) do
    case valid_fn.(value) do
      :ok -> :ok
      {:ok, _} -> :ok
      {:error, error} -> {:error, error}
      :error -> {:error, "validation failed"}
      false -> {:error, "validation failed"}
      _ -> :ok
    end
  end

  defp valid?(opt, _value, _type, _check) when opt in [:required], do: :ok

  defp valid?(opt, _value, type, _check),
    do: raise("unsupported validation: #{opt}, type: #{type}")
end
