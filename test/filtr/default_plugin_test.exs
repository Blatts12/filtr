defmodule Filtr.DefaultPluginTest do
  use ExUnit.Case, async: true

  alias Filtr.DefaultPlugin

  describe "types/0" do
    test "returns all supported types" do
      assert DefaultPlugin.types() == [
               :string,
               :integer,
               :float,
               :boolean,
               :time,
               :date,
               :datetime,
               :list
             ]
    end
  end

  describe "validate/4 - string validators" do
    test "validates exact length" do
      assert :ok = DefaultPlugin.validate("test", :string, {:length, 4}, [])
      assert {:error, msg} = DefaultPlugin.validate("test", :string, {:length, 5}, [])
      assert msg =~ "exactly 5 characters"
    end

    test "validates minimum length" do
      assert :ok = DefaultPlugin.validate("test", :string, {:min, 4}, [])
      assert :ok = DefaultPlugin.validate("test", :string, {:min, 3}, [])
      assert {:error, msg} = DefaultPlugin.validate("test", :string, {:min, 5}, [])
      assert msg =~ "at least 5 characters"
    end

    test "validates maximum length" do
      assert :ok = DefaultPlugin.validate("test", :string, {:max, 4}, [])
      assert :ok = DefaultPlugin.validate("test", :string, {:max, 5}, [])
      assert {:error, msg} = DefaultPlugin.validate("test", :string, {:max, 3}, [])
      assert msg =~ "at most 3 characters"
    end

    test "validates pattern" do
      assert :ok = DefaultPlugin.validate("test123", :string, {:pattern, ~r/\d/}, [])
      assert {:error, msg} = DefaultPlugin.validate("test", :string, {:pattern, ~r/\d/}, [])
      assert msg =~ "does not match pattern"
    end

    test "validates starts_with" do
      assert :ok = DefaultPlugin.validate("hello world", :string, {:starts_with, "hello"}, [])
      assert {:error, msg} = DefaultPlugin.validate("world", :string, {:starts_with, "hello"}, [])
      assert msg =~ "does not start with hello"
    end

    test "validates ends_with" do
      assert :ok = DefaultPlugin.validate("hello world", :string, {:ends_with, "world"}, [])
      assert {:error, msg} = DefaultPlugin.validate("hello", :string, {:ends_with, "world"}, [])
      assert msg =~ "does not end with world"
    end

    test "validates contains" do
      assert :ok = DefaultPlugin.validate("hello world", :string, {:contains, "lo wo"}, [])
      assert {:error, msg} = DefaultPlugin.validate("hello", :string, {:contains, "world"}, [])
      assert msg =~ "must contain 'world'"
    end

    test "validates alphanumeric" do
      assert :ok = DefaultPlugin.validate("abc123", :string, {:alphanumeric, true}, [])
      assert :ok = DefaultPlugin.validate("ABC", :string, {:alphanumeric, true}, [])
      assert {:error, msg} = DefaultPlugin.validate("abc-123", :string, {:alphanumeric, true}, [])
      assert msg =~ "only letters and numbers"
    end
  end

  describe "validate/4 - integer validators" do
    test "validates minimum value" do
      assert :ok = DefaultPlugin.validate(10, :integer, {:min, 10}, [])
      assert :ok = DefaultPlugin.validate(15, :integer, {:min, 10}, [])
      assert {:error, msg} = DefaultPlugin.validate(5, :integer, {:min, 10}, [])
      assert msg =~ "at least 10"
    end

    test "validates maximum value" do
      assert :ok = DefaultPlugin.validate(10, :integer, {:max, 10}, [])
      assert :ok = DefaultPlugin.validate(5, :integer, {:max, 10}, [])
      assert {:error, msg} = DefaultPlugin.validate(15, :integer, {:max, 10}, [])
      assert msg =~ "at most 10"
    end

    test "validates positive" do
      assert :ok = DefaultPlugin.validate(1, :integer, {:positive, true}, [])
      assert :ok = DefaultPlugin.validate(100, :integer, {:positive, true}, [])
      assert {:error, msg} = DefaultPlugin.validate(0, :integer, {:positive, true}, [])
      assert msg =~ "must be positive"
      assert {:error, _} = DefaultPlugin.validate(-1, :integer, {:positive, true}, [])
    end

    test "validates negative" do
      assert :ok = DefaultPlugin.validate(-1, :integer, {:negative, true}, [])
      assert :ok = DefaultPlugin.validate(-100, :integer, {:negative, true}, [])
      assert {:error, msg} = DefaultPlugin.validate(0, :integer, {:negative, true}, [])
      assert msg =~ "must be negative"
      assert {:error, _} = DefaultPlugin.validate(1, :integer, {:negative, true}, [])
    end
  end

  describe "validate/4 - float validators" do
    test "validates minimum value" do
      assert :ok = DefaultPlugin.validate(10.0, :float, {:min, 10.0}, [])
      assert :ok = DefaultPlugin.validate(15.5, :float, {:min, 10.0}, [])
      assert {:error, msg} = DefaultPlugin.validate(5.5, :float, {:min, 10.0}, [])
      assert msg =~ "at least 10.0"
    end

    test "validates maximum value" do
      assert :ok = DefaultPlugin.validate(10.0, :float, {:max, 10.0}, [])
      assert :ok = DefaultPlugin.validate(5.5, :float, {:max, 10.0}, [])
      assert {:error, msg} = DefaultPlugin.validate(15.5, :float, {:max, 10.0}, [])
      assert msg =~ "at most 10.0"
    end

    test "validates positive" do
      assert :ok = DefaultPlugin.validate(0.1, :float, {:positive, true}, [])
      assert :ok = DefaultPlugin.validate(100.5, :float, {:positive, true}, [])
      assert {:error, msg} = DefaultPlugin.validate(0.0, :float, {:positive, true}, [])
      assert msg =~ "must be positive"
      assert {:error, _} = DefaultPlugin.validate(-1.5, :float, {:positive, true}, [])
    end

    test "validates negative" do
      assert :ok = DefaultPlugin.validate(-0.1, :float, {:negative, true}, [])
      assert :ok = DefaultPlugin.validate(-100.5, :float, {:negative, true}, [])
      assert {:error, msg} = DefaultPlugin.validate(0.0, :float, {:negative, true}, [])
      assert msg =~ "must be negative"
      assert {:error, _} = DefaultPlugin.validate(1.5, :float, {:negative, true}, [])
    end
  end

  describe "validate/4 - date validators" do
    test "validates minimum date" do
      min_date = ~D[2024-01-01]
      assert :ok = DefaultPlugin.validate(~D[2024-01-01], :date, {:min, min_date}, [])
      assert :ok = DefaultPlugin.validate(~D[2024-02-01], :date, {:min, min_date}, [])
      assert {:error, msg} = DefaultPlugin.validate(~D[2023-12-31], :date, {:min, min_date}, [])
      assert msg =~ "after or equal to"
    end

    test "validates maximum date" do
      max_date = ~D[2024-12-31]
      assert :ok = DefaultPlugin.validate(~D[2024-12-31], :date, {:max, max_date}, [])
      assert :ok = DefaultPlugin.validate(~D[2024-01-01], :date, {:max, max_date}, [])
      assert {:error, msg} = DefaultPlugin.validate(~D[2025-01-01], :date, {:max, max_date}, [])
      assert msg =~ "before or equal to"
    end
  end

  describe "validate/4 - datetime validators" do
    test "validates minimum datetime" do
      min_dt = ~U[2024-01-01 00:00:00Z]
      assert :ok = DefaultPlugin.validate(~U[2024-01-01 00:00:00Z], :datetime, {:min, min_dt}, [])
      assert :ok = DefaultPlugin.validate(~U[2024-02-01 00:00:00Z], :datetime, {:min, min_dt}, [])
      assert {:error, msg} = DefaultPlugin.validate(~U[2023-12-31 23:59:59Z], :datetime, {:min, min_dt}, [])
      assert msg =~ "after or equal to"
    end

    test "validates maximum datetime" do
      max_dt = ~U[2024-12-31 23:59:59Z]
      assert :ok = DefaultPlugin.validate(~U[2024-12-31 23:59:59Z], :datetime, {:max, max_dt}, [])
      assert :ok = DefaultPlugin.validate(~U[2024-01-01 00:00:00Z], :datetime, {:max, max_dt}, [])
      assert {:error, msg} = DefaultPlugin.validate(~U[2025-01-01 00:00:00Z], :datetime, {:max, max_dt}, [])
      assert msg =~ "before or equal to"
    end
  end

  describe "validate/4 - list validators" do
    test "validates minimum length" do
      assert :ok = DefaultPlugin.validate([1, 2, 3], :list, {:min, 3}, [])
      assert :ok = DefaultPlugin.validate([1, 2, 3, 4], :list, {:min, 3}, [])
      assert {:error, msg} = DefaultPlugin.validate([1, 2], :list, {:min, 3}, [])
      assert msg =~ "at least 3 items"
    end

    test "validates maximum length" do
      assert :ok = DefaultPlugin.validate([1, 2, 3], :list, {:max, 3}, [])
      assert :ok = DefaultPlugin.validate([1, 2], :list, {:max, 3}, [])
      assert {:error, msg} = DefaultPlugin.validate([1, 2, 3, 4], :list, {:max, 3}, [])
      assert msg =~ "at most 3 items"
    end

    test "validates exact length" do
      assert :ok = DefaultPlugin.validate([1, 2, 3], :list, {:length, 3}, [])
      assert {:error, msg} = DefaultPlugin.validate([1, 2], :list, {:length, 3}, [])
      assert msg =~ "exactly 3 items"
    end

    test "validates uniqueness" do
      assert :ok = DefaultPlugin.validate([1, 2, 3], :list, {:unique, true}, [])
      assert {:error, msg} = DefaultPlugin.validate([1, 2, 2, 3], :list, {:unique, true}, [])
      assert msg =~ "unique values"
    end

    test "validates non-empty" do
      assert :ok = DefaultPlugin.validate([1], :list, {:non_empty, true}, [])
      assert {:error, msg} = DefaultPlugin.validate([], :list, {:non_empty, true}, [])
      assert msg =~ "must not be empty"
    end

    test "validates all items in allowed list" do
      assert :ok = DefaultPlugin.validate([1, 2], :list, {:in, [1, 2, 3]}, [])
      assert {:error, msg} = DefaultPlugin.validate([1, 4], :list, {:in, [1, 2, 3]}, [])
      assert msg =~ "invalid value in list"
    end
  end

  describe "validate/4 - general validators" do
    test "validates value is in list" do
      assert :ok = DefaultPlugin.validate("red", :string, {:in, ["red", "green", "blue"]}, [])
      assert :ok = DefaultPlugin.validate(2, :integer, {:in, [1, 2, 3]}, [])
      assert {:error, msg} = DefaultPlugin.validate("yellow", :string, {:in, ["red", "green", "blue"]}, [])
      assert msg =~ "must be one of"
    end
  end

  describe "validate/4 - not supported" do
    test "return error for not supported type" do
      assert DefaultPlugin.validate(2, :invalid, {:min, 2}, []) == :not_handled
    end

    test "return error for not supported validator" do
      assert DefaultPlugin.validate(2, :integer, {:invalid, [1, 2, 3]}, []) == :not_handled
    end
  end

  describe "cast/3 - string" do
    test "casts valid string" do
      assert {:ok, "test"} = DefaultPlugin.cast("test", :string, [])
    end

    test "returns error for non-string value" do
      assert {:error, "invalid string"} = DefaultPlugin.cast(123, :string, [])
      assert {:error, "invalid string"} = DefaultPlugin.cast(true, :string, [])
    end
  end

  describe "cast/3 - integer" do
    test "casts integer value" do
      assert {:ok, 42} = DefaultPlugin.cast(42, :integer, [])
    end

    test "parses integer from string" do
      assert {:ok, 42} = DefaultPlugin.cast("42", :integer, [])
      assert {:ok, -10} = DefaultPlugin.cast("-10", :integer, [])
    end

    test "returns error for invalid integer" do
      assert {:error, "invalid integer"} = DefaultPlugin.cast("not_a_number", :integer, [])
    end

    test "parses integer from string with decimal (ignores decimal part)" do
      assert {:ok, 12} = DefaultPlugin.cast("12.34", :integer, [])
    end
  end

  describe "cast/3 - float" do
    test "casts float value" do
      assert {:ok, 3.14} = DefaultPlugin.cast(3.14, :float, [])
    end

    test "parses float from string" do
      assert {:ok, 3.14} = DefaultPlugin.cast("3.14", :float, [])
      assert {:ok, -2.5} = DefaultPlugin.cast("-2.5", :float, [])
    end

    test "returns error for invalid float" do
      assert {:error, "invalid float"} = DefaultPlugin.cast("not_a_number", :float, [])
    end
  end

  describe "cast/3 - boolean" do
    test "casts boolean value" do
      assert {:ok, true} = DefaultPlugin.cast(true, :boolean, [])
      assert {:ok, false} = DefaultPlugin.cast(false, :boolean, [])
    end

    test "parses true from string" do
      assert {:ok, true} = DefaultPlugin.cast("true", :boolean, [])
      assert {:ok, true} = DefaultPlugin.cast("TRUE", :boolean, [])
      assert {:ok, true} = DefaultPlugin.cast("1", :boolean, [])
      assert {:ok, true} = DefaultPlugin.cast("yes", :boolean, [])
      assert {:ok, true} = DefaultPlugin.cast("YES", :boolean, [])
    end

    test "parses false from string" do
      assert {:ok, false} = DefaultPlugin.cast("false", :boolean, [])
      assert {:ok, false} = DefaultPlugin.cast("FALSE", :boolean, [])
      assert {:ok, false} = DefaultPlugin.cast("0", :boolean, [])
      assert {:ok, false} = DefaultPlugin.cast("no", :boolean, [])
      assert {:ok, false} = DefaultPlugin.cast("NO", :boolean, [])
    end

    test "returns error for invalid boolean" do
      assert {:error, "invalid boolean"} = DefaultPlugin.cast("maybe", :boolean, [])
      assert {:error, "invalid boolean"} = DefaultPlugin.cast(123, :boolean, [])
    end
  end

  describe "cast/3 - date" do
    test "casts Date struct" do
      date = ~D[2024-01-15]
      assert {:ok, ^date} = DefaultPlugin.cast(date, :date, [])
    end

    test "converts DateTime to Date" do
      datetime = ~U[2024-01-15 10:30:00Z]
      assert {:ok, ~D[2024-01-15]} = DefaultPlugin.cast(datetime, :date, [])
    end

    test "converts NaiveDateTime to Date" do
      naive = ~N[2024-01-15 10:30:00]
      assert {:ok, ~D[2024-01-15]} = DefaultPlugin.cast(naive, :date, [])
    end

    test "parses date from ISO8601 string" do
      assert {:ok, ~D[2024-01-15]} = DefaultPlugin.cast("2024-01-15", :date, [])
    end

    test "returns error for invalid date string" do
      assert {:error, "invalid date"} = DefaultPlugin.cast("not-a-date", :date, [])
      assert {:error, "invalid date"} = DefaultPlugin.cast("2024-13-01", :date, [])
    end
  end

  describe "cast/3 - datetime" do
    test "casts DateTime struct" do
      datetime = ~U[2024-01-15 10:30:00Z]
      assert {:ok, ^datetime} = DefaultPlugin.cast(datetime, :datetime, [])
    end

    test "converts NaiveDateTime to DateTime" do
      naive = ~N[2024-01-15 10:30:00]
      expected = DateTime.from_naive!(naive, "Etc/UTC")
      assert {:ok, ^expected} = DefaultPlugin.cast(naive, :datetime, [])
    end

    test "parses datetime from ISO8601 string" do
      {:ok, result} = DefaultPlugin.cast("2024-01-15T10:30:00Z", :datetime, [])
      assert %DateTime{} = result
      assert result.year == 2024
      assert result.month == 1
      assert result.day == 15
    end

    test "returns error for invalid datetime string" do
      assert {:error, "invalid datetime"} = DefaultPlugin.cast("not-a-datetime", :datetime, [])
    end
  end

  describe "cast/3 - list" do
    test "casts list value" do
      assert {:ok, [1, 2, 3]} = DefaultPlugin.cast([1, 2, 3], :list, [])
    end

    test "splits string by comma" do
      assert {:ok, ["a", "b", "c"]} = DefaultPlugin.cast("a,b,c", :list, [])
      assert {:ok, ["one", "two"]} = DefaultPlugin.cast("one,two", :list, [])
    end

    test "trims empty values when splitting" do
      assert {:ok, ["a", "b"]} = DefaultPlugin.cast("a,b,", :list, [])
    end

    test "returns error for invalid list" do
      assert {:error, "invalid list"} = DefaultPlugin.cast(123, :list, [])
      assert {:error, "invalid list"} = DefaultPlugin.cast(%{}, :list, [])
    end
  end

  describe "cast/3 - not supported" do
    test "return error for not supported type" do
      assert DefaultPlugin.cast(%{}, :invalid, []) == :not_handled
    end
  end
end
