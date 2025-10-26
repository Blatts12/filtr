defmodule Filtr.DefaultPlugin.CastTest do
  use ExUnit.Case, async: true

  alias Filtr.DefaultPlugin.Cast

  describe "cast/3 - string" do
    test "casts valid string" do
      assert {:ok, "test"} = Cast.cast("test", :string, [])
    end

    test "returns error for non-string value" do
      assert {:error, "invalid string"} = Cast.cast(123, :string, [])
      assert {:error, "invalid string"} = Cast.cast(true, :string, [])
    end
  end

  describe "cast/3 - integer" do
    test "casts integer value" do
      assert {:ok, 42} = Cast.cast(42, :integer, [])
    end

    test "parses integer from string" do
      assert {:ok, 42} = Cast.cast("42", :integer, [])
      assert {:ok, -10} = Cast.cast("-10", :integer, [])
    end

    test "returns error for invalid integer" do
      assert {:error, "invalid integer"} = Cast.cast("not_a_number", :integer, [])
    end

    test "parses integer from string with decimal (ignores decimal part)" do
      assert {:ok, 12} = Cast.cast("12.34", :integer, [])
    end
  end

  describe "cast/3 - float" do
    test "casts float value" do
      assert {:ok, 3.14} = Cast.cast(3.14, :float, [])
    end

    test "parses float from string" do
      assert {:ok, 3.14} = Cast.cast("3.14", :float, [])
      assert {:ok, -2.5} = Cast.cast("-2.5", :float, [])
    end

    test "returns error for invalid float" do
      assert {:error, "invalid float"} = Cast.cast("not_a_number", :float, [])
    end
  end

  describe "cast/3 - boolean" do
    test "casts boolean value" do
      assert {:ok, true} = Cast.cast(true, :boolean, [])
      assert {:ok, false} = Cast.cast(false, :boolean, [])
    end

    test "parses true from string" do
      assert {:ok, true} = Cast.cast("true", :boolean, [])
      assert {:ok, true} = Cast.cast("TRUE", :boolean, [])
      assert {:ok, true} = Cast.cast("1", :boolean, [])
      assert {:ok, true} = Cast.cast("yes", :boolean, [])
      assert {:ok, true} = Cast.cast("YES", :boolean, [])
    end

    test "parses false from string" do
      assert {:ok, false} = Cast.cast("false", :boolean, [])
      assert {:ok, false} = Cast.cast("FALSE", :boolean, [])
      assert {:ok, false} = Cast.cast("0", :boolean, [])
      assert {:ok, false} = Cast.cast("no", :boolean, [])
      assert {:ok, false} = Cast.cast("NO", :boolean, [])
    end

    test "returns error for invalid boolean" do
      assert {:error, "invalid boolean"} = Cast.cast("maybe", :boolean, [])
      assert {:error, "invalid boolean"} = Cast.cast(123, :boolean, [])
    end
  end

  describe "cast/3 - date" do
    test "casts Date struct" do
      date = ~D[2024-01-15]
      assert {:ok, ^date} = Cast.cast(date, :date, [])
    end

    test "converts DateTime to Date" do
      datetime = ~U[2024-01-15 10:30:00Z]
      assert {:ok, ~D[2024-01-15]} = Cast.cast(datetime, :date, [])
    end

    test "converts NaiveDateTime to Date" do
      naive = ~N[2024-01-15 10:30:00]
      assert {:ok, ~D[2024-01-15]} = Cast.cast(naive, :date, [])
    end

    test "parses date from ISO8601 string" do
      assert {:ok, ~D[2024-01-15]} = Cast.cast("2024-01-15", :date, [])
    end

    test "returns error for invalid date string" do
      assert {:error, "invalid date"} = Cast.cast("not-a-date", :date, [])
      assert {:error, "invalid date"} = Cast.cast("2024-13-01", :date, [])
    end
  end

  describe "cast/3 - datetime" do
    test "casts DateTime struct" do
      datetime = ~U[2024-01-15 10:30:00Z]
      assert {:ok, ^datetime} = Cast.cast(datetime, :datetime, [])
    end

    test "converts NaiveDateTime to DateTime" do
      naive = ~N[2024-01-15 10:30:00]
      expected = DateTime.from_naive!(naive, "Etc/UTC")
      assert {:ok, ^expected} = Cast.cast(naive, :datetime, [])
    end

    test "parses datetime from ISO8601 string" do
      {:ok, result} = Cast.cast("2024-01-15T10:30:00Z", :datetime, [])
      assert %DateTime{} = result
      assert result.year == 2024
      assert result.month == 1
      assert result.day == 15
    end

    test "returns error for invalid datetime string" do
      assert {:error, "invalid datetime"} = Cast.cast("not-a-datetime", :datetime, [])
    end
  end

  describe "cast/3 - list" do
    test "casts list value" do
      assert {:ok, [1, 2, 3]} = Cast.cast([1, 2, 3], :list, [])
    end

    test "splits string by comma" do
      assert {:ok, ["a", "b", "c"]} = Cast.cast("a,b,c", :list, [])
      assert {:ok, ["one", "two"]} = Cast.cast("one,two", :list, [])
    end

    test "trims empty values when splitting" do
      assert {:ok, ["a", "b"]} = Cast.cast("a,b,", :list, [])
    end

    test "returns error for invalid list" do
      assert {:error, "invalid list"} = Cast.cast(123, :list, [])
      assert {:error, "invalid list"} = Cast.cast(%{}, :list, [])
    end
  end
end
