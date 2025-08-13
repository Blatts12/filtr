defmodule Pex.Validators do
  @moduledoc """
  Common validators for Pex query parameter validation.

  This module provides a collection of commonly used validators
  that can be used in Pex schema definitions.
  """

  @doc """
  Validates that a number is positive (greater than 0).

  ## Examples

      iex> Pex.Validators.positive(5)
      {:ok, 5}

      iex> Pex.Validators.positive(0)
      {:error, "must be positive"}

      iex> Pex.Validators.positive(-1)
      {:error, "must be positive"}
  """
  @spec positive(number()) :: {:ok, number()} | {:error, String.t()}
  def positive(value) when is_number(value) and value > 0, do: {:ok, value}
  def positive(_value), do: {:error, "must be positive"}

  @doc """
  Validates that a number is within a specified range (inclusive).

  ## Examples

      iex> Pex.Validators.range(5, 1, 10)
      {:ok, 5}

      iex> Pex.Validators.range(1, 1, 10)
      {:ok, 1}

      iex> Pex.Validators.range(10, 1, 10)
      {:ok, 10}

      iex> Pex.Validators.range(0, 1, 10)
      {:error, "must be between 1 and 10"}

      iex> Pex.Validators.range(11, 1, 10)
      {:error, "must be between 1 and 10"}
  """
  @spec range(number(), number(), number()) :: {:ok, number()} | {:error, String.t()}
  def range(value, min, max) when is_number(value) and value >= min and value <= max do
    {:ok, value}
  end
  def range(_value, min, max), do: {:error, "must be between #{min} and #{max}"}

  @doc """
  Validates that a string has a minimum length.

  ## Examples

      iex> Pex.Validators.min_length("hello", 3)
      {:ok, "hello"}

      iex> Pex.Validators.min_length("hi", 3)
      {:error, "must be at least 3 characters long"}
  """
  @spec min_length(String.t(), non_neg_integer()) :: {:ok, String.t()} | {:error, String.t()}
  def min_length(value, min) when is_binary(value) and byte_size(value) >= min do
    {:ok, value}
  end
  def min_length(_value, min), do: {:error, "must be at least #{min} characters long"}

  @doc """
  Validates that a string has a maximum length.

  ## Examples

      iex> Pex.Validators.max_length("hello", 10)
      {:ok, "hello"}

      iex> Pex.Validators.max_length("this is too long", 10)
      {:error, "must be at most 10 characters long"}
  """
  @spec max_length(String.t(), non_neg_integer()) :: {:ok, String.t()} | {:error, String.t()}
  def max_length(value, max) when is_binary(value) and byte_size(value) <= max do
    {:ok, value}
  end
  def max_length(_value, max), do: {:error, "must be at most #{max} characters long"}

  @doc """
  Validates that a value is one of the allowed options.

  ## Examples

      iex> Pex.Validators.one_of("red", ["red", "green", "blue"])
      {:ok, "red"}

      iex> Pex.Validators.one_of("yellow", ["red", "green", "blue"])
      {:error, "must be one of: red, green, blue"}
  """
  @spec one_of(any(), list()) :: {:ok, any()} | {:error, String.t()}
  def one_of(value, options) do
    if Enum.member?(options, value) do
      {:ok, value}
    else
      options_str = Enum.join(options, ", ")
      {:error, "must be one of: #{options_str}"}
    end
  end

  @doc """
  Validates that a string matches a regular expression.

  ## Examples

      iex> email_regex = ~r/^[\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,}$/
      iex> Pex.Validators.format("user@example.com", email_regex)
      {:ok, "user@example.com"}

      iex> email_regex = ~r/^[\\w._%+-]+@[\\w.-]+\\.[A-Za-z]{2,}$/
      iex> Pex.Validators.format("invalid-email", email_regex)
      {:error, "invalid format"}
  """
  @spec format(String.t(), Regex.t()) :: {:ok, String.t()} | {:error, String.t()}
  def format(value, regex) when is_binary(value) do
    if Regex.match?(regex, value) do
      {:ok, value}
    else
      {:error, "invalid format"}
    end
  end
  def format(_value, _regex), do: {:error, "invalid format"}

  @doc """
  Validates that a list is not empty.

  ## Examples

      iex> Pex.Validators.not_empty(["a", "b"])
      {:ok, ["a", "b"]}

      iex> Pex.Validators.not_empty([])
      {:error, "cannot be empty"}
  """
  @spec not_empty(list()) :: {:ok, list()} | {:error, String.t()}
  def not_empty([]), do: {:error, "cannot be empty"}
  def not_empty(list) when is_list(list), do: {:ok, list}
  def not_empty(_value), do: {:error, "must be a list"}

  @doc """
  Validates that a list has a specific length.

  ## Examples

      iex> Pex.Validators.length(["a", "b"], 2)
      {:ok, ["a", "b"]}

      iex> Pex.Validators.length(["a"], 2)
      {:error, "must have exactly 2 items"}
  """
  @spec length(list(), non_neg_integer()) :: {:ok, list()} | {:error, String.t()}
  def length(list, expected) when is_list(list) and length(list) == expected do
    {:ok, list}
  end
  def length(list, expected) when is_list(list) do
    {:error, "must have exactly #{expected} items"}
  end
  def length(_value, _expected), do: {:error, "must be a list"}
end