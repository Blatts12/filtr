defmodule Filtr.DefaultPlugin.Cast do
  @moduledoc false

  @spec cast(value :: any(), type :: atom(), opts :: keyword()) :: Filtr.Plugin.cast_result()

  # String
  def cast(value, :string, _opts) when is_binary(value), do: {:ok, value}
  def cast(_value, :string, _opts), do: {:error, "invalid string"}

  # Integer
  def cast(value, :integer, _opts) when is_integer(value), do: {:ok, value}

  def cast(value, :integer, _opts) do
    case Integer.parse(value) do
      {int, _} -> {:ok, int}
      _ -> {:error, "invalid integer"}
    end
  end

  # Float
  def cast(value, :float, _opts) when is_float(value), do: {:ok, value}

  def cast(value, :float, _opts) do
    case Float.parse(value) do
      {float, _} -> {:ok, float}
      _ -> {:error, "invalid float"}
    end
  end

  # Boolean
  def cast(value, :boolean, _opts) when is_boolean(value), do: {:ok, value}

  def cast(value, :boolean, _opts) when is_binary(value) do
    case String.downcase(value) do
      v when v in ["true", "1", "yes"] -> {:ok, true}
      v when v in ["false", "0", "no"] -> {:ok, false}
      _ -> {:error, "invalid boolean"}
    end
  end

  def cast(_value, :boolean, _opts), do: {:error, "invalid boolean"}

  # Date
  def cast(%Date{} = date, :date, _opts), do: {:ok, date}
  def cast(%DateTime{} = dt, :date, _opts), do: {:ok, DateTime.to_date(dt)}
  def cast(%NaiveDateTime{} = ndt, :date, _opts), do: {:ok, NaiveDateTime.to_date(ndt)}

  def cast(value, :date, _opts) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, "invalid date"}
    end
  end

  def cast(_value, :date, _opts), do: {:error, "invalid date"}

  # DateTime
  def cast(%DateTime{} = dt, :datetime, _opts), do: {:ok, dt}
  def cast(%NaiveDateTime{} = ndt, :datetime, _opts), do: {:ok, DateTime.from_naive!(ndt, "Etc/UTC")}

  def cast(value, :datetime, _opts) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _} -> {:ok, datetime}
      _ -> {:error, "invalid datetime"}
    end
  end

  def cast(_value, :datetime, _opts), do: {:error, "invalid datetime"}

  # List
  def cast(value, :list, opts) when is_binary(value), do: cast(String.split(value, ",", trim: true), :list, opts)
  def cast(values, :list, _opts) when is_list(values), do: {:ok, values}
  def cast(_value, :list, _opts), do: {:error, "invalid list"}
end
