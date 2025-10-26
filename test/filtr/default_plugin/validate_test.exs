defmodule Filtr.DefaultPlugin.ValidateTest do
  use ExUnit.Case, async: true

  alias Filtr.DefaultPlugin.Validate

  describe "validate/4 - string validators" do
    test "validates exact length" do
      assert :ok = Validate.validate("test", :string, {:length, 4}, [])
      assert {:error, msg} = Validate.validate("test", :string, {:length, 5}, [])
      assert msg =~ "exactly 5 characters"
    end

    test "validates minimum length" do
      assert :ok = Validate.validate("test", :string, {:min, 4}, [])
      assert :ok = Validate.validate("test", :string, {:min, 3}, [])
      assert {:error, msg} = Validate.validate("test", :string, {:min, 5}, [])
      assert msg =~ "at least 5 characters"
    end

    test "validates maximum length" do
      assert :ok = Validate.validate("test", :string, {:max, 4}, [])
      assert :ok = Validate.validate("test", :string, {:max, 5}, [])
      assert {:error, msg} = Validate.validate("test", :string, {:max, 3}, [])
      assert msg =~ "at most 3 characters"
    end

    test "validates pattern" do
      assert :ok = Validate.validate("test123", :string, {:pattern, ~r/\d/}, [])
      assert {:error, msg} = Validate.validate("test", :string, {:pattern, ~r/\d/}, [])
      assert msg =~ "does not match pattern"
    end

    test "validates starts_with" do
      assert :ok = Validate.validate("hello world", :string, {:starts_with, "hello"}, [])
      assert {:error, msg} = Validate.validate("world", :string, {:starts_with, "hello"}, [])
      assert msg =~ "does not start with hello"
    end

    test "validates ends_with" do
      assert :ok = Validate.validate("hello world", :string, {:ends_with, "world"}, [])
      assert {:error, msg} = Validate.validate("hello", :string, {:ends_with, "world"}, [])
      assert msg =~ "does not end with world"
    end

    test "validates contains" do
      assert :ok = Validate.validate("hello world", :string, {:contains, "lo wo"}, [])
      assert {:error, msg} = Validate.validate("hello", :string, {:contains, "world"}, [])
      assert msg =~ "must contain 'world'"
    end

    test "validates alphanumeric" do
      assert :ok = Validate.validate("abc123", :string, {:alphanumeric, true}, [])
      assert :ok = Validate.validate("ABC", :string, {:alphanumeric, true}, [])
      assert {:error, msg} = Validate.validate("abc-123", :string, {:alphanumeric, true}, [])
      assert msg =~ "only letters and numbers"
    end
  end

  describe "validate/4 - integer validators" do
    test "validates minimum value" do
      assert :ok = Validate.validate(10, :integer, {:min, 10}, [])
      assert :ok = Validate.validate(15, :integer, {:min, 10}, [])
      assert {:error, msg} = Validate.validate(5, :integer, {:min, 10}, [])
      assert msg =~ "at least 10"
    end

    test "validates maximum value" do
      assert :ok = Validate.validate(10, :integer, {:max, 10}, [])
      assert :ok = Validate.validate(5, :integer, {:max, 10}, [])
      assert {:error, msg} = Validate.validate(15, :integer, {:max, 10}, [])
      assert msg =~ "at most 10"
    end

    test "validates positive" do
      assert :ok = Validate.validate(1, :integer, {:positive, true}, [])
      assert :ok = Validate.validate(100, :integer, {:positive, true}, [])
      assert {:error, msg} = Validate.validate(0, :integer, {:positive, true}, [])
      assert msg =~ "must be positive"
      assert {:error, _} = Validate.validate(-1, :integer, {:positive, true}, [])
    end

    test "validates negative" do
      assert :ok = Validate.validate(-1, :integer, {:negative, true}, [])
      assert :ok = Validate.validate(-100, :integer, {:negative, true}, [])
      assert {:error, msg} = Validate.validate(0, :integer, {:negative, true}, [])
      assert msg =~ "must be negative"
      assert {:error, _} = Validate.validate(1, :integer, {:negative, true}, [])
    end
  end

  describe "validate/4 - float validators" do
    test "validates minimum value" do
      assert :ok = Validate.validate(10.0, :float, {:min, 10.0}, [])
      assert :ok = Validate.validate(15.5, :float, {:min, 10.0}, [])
      assert {:error, msg} = Validate.validate(5.5, :float, {:min, 10.0}, [])
      assert msg =~ "at least 10.0"
    end

    test "validates maximum value" do
      assert :ok = Validate.validate(10.0, :float, {:max, 10.0}, [])
      assert :ok = Validate.validate(5.5, :float, {:max, 10.0}, [])
      assert {:error, msg} = Validate.validate(15.5, :float, {:max, 10.0}, [])
      assert msg =~ "at most 10.0"
    end

    test "validates positive" do
      assert :ok = Validate.validate(0.1, :float, {:positive, true}, [])
      assert :ok = Validate.validate(100.5, :float, {:positive, true}, [])
      assert {:error, msg} = Validate.validate(0.0, :float, {:positive, true}, [])
      assert msg =~ "must be positive"
      assert {:error, _} = Validate.validate(-1.5, :float, {:positive, true}, [])
    end

    test "validates negative" do
      assert :ok = Validate.validate(-0.1, :float, {:negative, true}, [])
      assert :ok = Validate.validate(-100.5, :float, {:negative, true}, [])
      assert {:error, msg} = Validate.validate(0.0, :float, {:negative, true}, [])
      assert msg =~ "must be negative"
      assert {:error, _} = Validate.validate(1.5, :float, {:negative, true}, [])
    end
  end

  describe "validate/4 - date validators" do
    test "validates minimum date" do
      min_date = ~D[2024-01-01]
      assert :ok = Validate.validate(~D[2024-01-01], :date, {:min, min_date}, [])
      assert :ok = Validate.validate(~D[2024-02-01], :date, {:min, min_date}, [])
      assert {:error, msg} = Validate.validate(~D[2023-12-31], :date, {:min, min_date}, [])
      assert msg =~ "after or equal to"
    end

    test "validates maximum date" do
      max_date = ~D[2024-12-31]
      assert :ok = Validate.validate(~D[2024-12-31], :date, {:max, max_date}, [])
      assert :ok = Validate.validate(~D[2024-01-01], :date, {:max, max_date}, [])
      assert {:error, msg} = Validate.validate(~D[2025-01-01], :date, {:max, max_date}, [])
      assert msg =~ "before or equal to"
    end
  end

  describe "validate/4 - datetime validators" do
    test "validates minimum datetime" do
      min_dt = ~U[2024-01-01 00:00:00Z]
      assert :ok = Validate.validate(~U[2024-01-01 00:00:00Z], :datetime, {:min, min_dt}, [])
      assert :ok = Validate.validate(~U[2024-02-01 00:00:00Z], :datetime, {:min, min_dt}, [])
      assert {:error, msg} = Validate.validate(~U[2023-12-31 23:59:59Z], :datetime, {:min, min_dt}, [])
      assert msg =~ "after or equal to"
    end

    test "validates maximum datetime" do
      max_dt = ~U[2024-12-31 23:59:59Z]
      assert :ok = Validate.validate(~U[2024-12-31 23:59:59Z], :datetime, {:max, max_dt}, [])
      assert :ok = Validate.validate(~U[2024-01-01 00:00:00Z], :datetime, {:max, max_dt}, [])
      assert {:error, msg} = Validate.validate(~U[2025-01-01 00:00:00Z], :datetime, {:max, max_dt}, [])
      assert msg =~ "before or equal to"
    end
  end

  describe "validate/4 - list validators" do
    test "validates minimum length" do
      assert :ok = Validate.validate([1, 2, 3], :list, {:min, 3}, [])
      assert :ok = Validate.validate([1, 2, 3, 4], :list, {:min, 3}, [])
      assert {:error, msg} = Validate.validate([1, 2], :list, {:min, 3}, [])
      assert msg =~ "at least 3 items"
    end

    test "validates maximum length" do
      assert :ok = Validate.validate([1, 2, 3], :list, {:max, 3}, [])
      assert :ok = Validate.validate([1, 2], :list, {:max, 3}, [])
      assert {:error, msg} = Validate.validate([1, 2, 3, 4], :list, {:max, 3}, [])
      assert msg =~ "at most 3 items"
    end

    test "validates exact length" do
      assert :ok = Validate.validate([1, 2, 3], :list, {:length, 3}, [])
      assert {:error, msg} = Validate.validate([1, 2], :list, {:length, 3}, [])
      assert msg =~ "exactly 3 items"
    end

    test "validates uniqueness" do
      assert :ok = Validate.validate([1, 2, 3], :list, {:unique, true}, [])
      assert {:error, msg} = Validate.validate([1, 2, 2, 3], :list, {:unique, true}, [])
      assert msg =~ "unique values"
    end

    test "validates non-empty" do
      assert :ok = Validate.validate([1], :list, {:non_empty, true}, [])
      assert {:error, msg} = Validate.validate([], :list, {:non_empty, true}, [])
      assert msg =~ "must not be empty"
    end

    test "validates all items in allowed list" do
      assert :ok = Validate.validate([1, 2], :list, {:in, [1, 2, 3]}, [])
      assert {:error, msg} = Validate.validate([1, 4], :list, {:in, [1, 2, 3]}, [])
      assert msg =~ "invalid value in list"
    end
  end

  describe "validate/4 - general validators" do
    test "validates value is in list" do
      assert :ok = Validate.validate("red", :string, {:in, ["red", "green", "blue"]}, [])
      assert :ok = Validate.validate(2, :integer, {:in, [1, 2, 3]}, [])
      assert {:error, msg} = Validate.validate("yellow", :string, {:in, ["red", "green", "blue"]}, [])
      assert msg =~ "must be one of"
    end
  end
end
