defmodule Pex.ValidatorTest do
  use ExUnit.Case
  doctest Pex.Validator

  alias Pex.Validator

  describe "run/2" do
    test "returns ok tuple for valid value with no constraints" do
      assert Validator.run("hello", :string) == {:ok, "hello"}
      assert Validator.run(42, :integer) == {:ok, 42}
      assert Validator.run(3.14, :float) == {:ok, 3.14}
    end

    test "returns ok tuple when no validation options provided" do
      assert Validator.run("test", :string, []) == {:ok, "test"}
    end

    test "ignores unsupported options for given type" do
      assert Validator.run("hello", :string, unknown_option: true) == {:ok, "hello"}
    end

    test "raises with unsupported type" do
      assert_raise RuntimeError, ~r/Unsupported type/, fn ->
        Validator.run("test", :unknown_type, [])
      end
    end
  end

  describe "required validation" do
    test "passes when value is present and required: true" do
      assert Validator.run("hello", :string, required: true) == {:ok, "hello"}
      assert Validator.run(42, :integer, required: true) == {:ok, 42}
    end

    test "passes when value is present and required: false" do
      assert Validator.run("hello", :string, required: false) == {:ok, "hello"}
    end

    test "passes when value is present and required not specified" do
      assert Validator.run("hello", :string) == {:ok, "hello"}
    end

    test "fails when value is nil and required: true" do
      assert Validator.run(nil, :string, required: true) == {:error, "required"}
    end

    test "fails when value is empty string and required: true" do
      assert Validator.run("", :string, required: true) == {:error, "required"}
    end

    test "passes when value is nil and required: false" do
      assert Validator.run(nil, :string, required: false) == {:ok, nil}
    end

    test "passes when value is empty string and required: false" do
      assert Validator.run("", :string, required: false) == {:ok, ""}
    end
  end

  describe "string validation" do
    test "min length validation" do
      assert Validator.run("hello", :string, min: 3) == {:ok, "hello"}

      assert Validator.run("hi", :string, min: 3) ==
               {:error, ["must be at least 3 characters long"]}

      assert Validator.run("abc", :string, min: 3) == {:ok, "abc"}
    end

    test "max length validation" do
      assert Validator.run("hi", :string, max: 5) == {:ok, "hi"}

      assert Validator.run("hello world", :string, max: 5) ==
               {:error, ["must be at most 5 characters long"]}

      assert Validator.run("hello", :string, max: 5) == {:ok, "hello"}
    end

    test "pattern validation" do
      email_pattern = ~r/@/

      assert Validator.run("test@example.com", :string, pattern: email_pattern) ==
               {:ok, "test@example.com"}

      assert Validator.run("invalid-email", :string, pattern: email_pattern) ==
               {:error, ["does not match pattern"]}
    end

    test "starts_with validation" do
      assert Validator.run("hello world", :string, starts_with: "hello") == {:ok, "hello world"}

      assert Validator.run("hi world", :string, starts_with: "hello") ==
               {:error, ["does not start with hello"]}
    end

    test "ends_with validation" do
      assert Validator.run("hello world", :string, ends_with: "world") == {:ok, "hello world"}

      assert Validator.run("hello universe", :string, ends_with: "world") ==
               {:error, ["does not end with world"]}
    end

    test "in validation for strings" do
      options = ["red", "green", "blue"]
      assert Validator.run("red", :string, in: options) == {:ok, "red"}
      assert Validator.run("yellow", :string, in: options) == {:error, ["value not in list"]}
    end

    test "multiple string validations" do
      opts = [min: 5, max: 10, pattern: ~r/@/]

      assert Validator.run("test@example.com", :string, opts) ==
               {:error, ["must be at most 10 characters long"]}

      assert Validator.run("a@b", :string, opts) ==
               {:error, ["must be at least 5 characters long"]}

      assert Validator.run("test@", :string, opts) == {:ok, "test@"}
    end
  end

  describe "integer validation" do
    test "min value validation" do
      assert Validator.run(25, :integer, min: 18) == {:ok, 25}
      assert Validator.run(15, :integer, min: 18) == {:error, ["must be at least 18"]}
      assert Validator.run(18, :integer, min: 18) == {:ok, 18}
    end

    test "max value validation" do
      assert Validator.run(25, :integer, max: 65) == {:ok, 25}
      assert Validator.run(70, :integer, max: 65) == {:error, ["must be at most 65"]}
      assert Validator.run(65, :integer, max: 65) == {:ok, 65}
    end

    test "in validation for integers" do
      options = [1, 2, 3, 5, 8]
      assert Validator.run(3, :integer, in: options) == {:ok, 3}
      assert Validator.run(4, :integer, in: options) == {:error, ["value not in list"]}
    end

    test "multiple integer validations" do
      opts = [min: 18, max: 65]
      assert Validator.run(25, :integer, opts) == {:ok, 25}
      assert Validator.run(15, :integer, opts) == {:error, ["must be at least 18"]}
      assert Validator.run(70, :integer, opts) == {:error, ["must be at most 65"]}
    end
  end

  describe "float validation" do
    test "min value validation" do
      assert Validator.run(3.5, :float, min: 2.0) == {:ok, 3.5}
      assert Validator.run(1.5, :float, min: 2.0) == {:error, ["must be at least 2.0"]}
      assert Validator.run(2.0, :float, min: 2.0) == {:ok, 2.0}
    end

    test "max value validation" do
      assert Validator.run(3.5, :float, max: 5.0) == {:ok, 3.5}
      assert Validator.run(6.0, :float, max: 5.0) == {:error, ["must be at most 5.0"]}
      assert Validator.run(5.0, :float, max: 5.0) == {:ok, 5.0}
    end

    test "in validation for floats" do
      options = [1.0, 2.5, 3.14]
      assert Validator.run(2.5, :float, in: options) == {:ok, 2.5}
      assert Validator.run(2.6, :float, in: options) == {:error, ["value not in list"]}
    end
  end

  describe "date validation" do
    test "min date validation" do
      min_date = ~D[2020-01-01]
      assert Validator.run(~D[2023-06-15], :date, min: min_date) == {:ok, ~D[2023-06-15]}

      assert Validator.run(~D[2019-12-31], :date, min: min_date) ==
               {:error, ["must be after or equal to 2020-01-01"]}

      assert Validator.run(~D[2020-01-01], :date, min: min_date) == {:ok, ~D[2020-01-01]}
    end

    test "max date validation" do
      max_date = ~D[2025-12-31]
      assert Validator.run(~D[2023-06-15], :date, max: max_date) == {:ok, ~D[2023-06-15]}

      assert Validator.run(~D[2026-01-01], :date, max: max_date) ==
               {:error, ["must be before or equal to 2025-12-31"]}

      assert Validator.run(~D[2025-12-31], :date, max: max_date) == {:ok, ~D[2025-12-31]}
    end

    test "in validation for dates" do
      options = [~D[2023-01-01], ~D[2023-06-15], ~D[2023-12-31]]
      assert Validator.run(~D[2023-06-15], :date, in: options) == {:ok, ~D[2023-06-15]}
      assert Validator.run(~D[2023-07-01], :date, in: options) == {:error, ["value not in list"]}
    end
  end

  describe "datetime validation" do
    test "min datetime validation" do
      min_datetime = ~U[2020-01-01 00:00:00Z]

      assert Validator.run(~U[2023-06-15 12:00:00Z], :datetime, min: min_datetime) ==
               {:ok, ~U[2023-06-15 12:00:00Z]}

      assert Validator.run(~U[2019-12-31 23:59:59Z], :datetime, min: min_datetime) ==
               {:error, ["must be after or equal to 2020-01-01 00:00:00Z"]}

      assert Validator.run(~U[2020-01-01 00:00:00Z], :datetime, min: min_datetime) ==
               {:ok, ~U[2020-01-01 00:00:00Z]}
    end

    test "max datetime validation" do
      max_datetime = ~U[2025-12-31 23:59:59Z]

      assert Validator.run(~U[2023-06-15 12:00:00Z], :datetime, max: max_datetime) ==
               {:ok, ~U[2023-06-15 12:00:00Z]}

      assert Validator.run(~U[2026-01-01 00:00:00Z], :datetime, max: max_datetime) ==
               {:error, ["must be before or equal to 2025-12-31 23:59:59Z"]}

      assert Validator.run(~U[2025-12-31 23:59:59Z], :datetime, max: max_datetime) ==
               {:ok, ~U[2025-12-31 23:59:59Z]}
    end

    test "in validation for datetimes" do
      options = [~U[2023-01-01 00:00:00Z], ~U[2023-06-15 12:00:00Z], ~U[2023-12-31 23:59:59Z]]

      assert Validator.run(~U[2023-06-15 12:00:00Z], :datetime, in: options) ==
               {:ok, ~U[2023-06-15 12:00:00Z]}

      assert Validator.run(~U[2023-07-01 12:00:00Z], :datetime, in: options) ==
               {:error, ["value not in list"]}
    end
  end

  describe "list validation" do
    test "min length validation" do
      assert Validator.run(["a", "b", "c"], :list, min: 2) == {:ok, ["a", "b", "c"]}
      assert Validator.run(["a"], :list, min: 2) == {:error, ["must be at least 2 items long"]}
      assert Validator.run(["a", "b"], :list, min: 2) == {:ok, ["a", "b"]}
    end

    test "max length validation" do
      assert Validator.run(["a", "b"], :list, max: 3) == {:ok, ["a", "b"]}

      assert Validator.run(["a", "b", "c", "d"], :list, max: 3) ==
               {:error, ["must be at most 3 items long"]}

      assert Validator.run(["a", "b", "c"], :list, max: 3) == {:ok, ["a", "b", "c"]}
    end

    test "exact length validation" do
      assert Validator.run(["a", "b", "c"], :list, length: 3) == {:ok, ["a", "b", "c"]}

      assert Validator.run(["a", "b"], :list, length: 3) ==
               {:error, ["must be exactly 3 items long"]}

      assert Validator.run(["a", "b", "c", "d"], :list, length: 3) ==
               {:error, ["must be exactly 3 items long"]}
    end

    test "in validation" do
      assert Validator.run(["red", "yellow"], :list, in: ["red", "green"]) ==
               {:error, ["invalid value in list"]}

      assert Validator.run(["purple", "yellow"], :list, in: ["purple", "yellow"]) ==
               {:ok, ["purple", "yellow"]}
    end
  end

  describe "custom validation" do
    test "custom validation function returning :ok" do
      validator = fn value ->
        if String.length(value) > 5, do: :ok, else: {:error, "too short"}
      end

      assert Validator.run("hello world", :string, validate: validator) == {:ok, "hello world"}
      assert Validator.run("hi", :string, validate: validator) == {:error, ["too short"]}
    end

    test "custom validation function returning {:ok, value}" do
      validator = fn value -> {:ok, value} end

      assert Validator.run("test", :string, validate: validator) == {:ok, "test"}
    end

    test "custom validation function returning :error" do
      validator = fn _value -> :error end

      assert Validator.run("test", :string, validate: validator) == :error
    end

    test "custom validation function returning {:error, message}" do
      validator = fn _value -> {:error, "custom error"} end

      assert Validator.run("test", :string, validate: validator) == {:error, ["custom error"]}
    end

    test "custom validation function returning false" do
      validator = fn _value -> false end

      assert Validator.run("test", :string, validate: validator) ==
               {:error, ["validation failed"]}
    end

    test "custom validation function returning truthy value" do
      validator = fn _value -> "some truthy value" end

      assert Validator.run("test", :string, validate: validator) == {:ok, "test"}
    end

    test "combines custom validation with other validations" do
      email_validator = fn email ->
        if String.contains?(email, "@") and String.contains?(email, ".") do
          :ok
        else
          {:error, "invalid email"}
        end
      end

      opts = [min: 6, validate: email_validator]

      assert Validator.run("a@b.c", :string, opts) ==
               {:error, ["must be at least 6 characters long"]}

      assert Validator.run("test@example.com", :string, opts) == {:ok, "test@example.com"}

      assert Validator.run("bad", :string, opts) ==
               {:error, ["must be at least 6 characters long", "invalid email"]}
    end
  end

  describe "multiple validation errors" do
    test "collects multiple validation errors" do
      # Impossible constraint to trigger both errors
      opts = [min: 10, max: 5]
      result = Validator.run("hello", :string, opts)

      assert match?({:error, _errors}, result)
      {:error, errors} = result
      assert "must be at least 10 characters long" in errors
    end

    test "combines validation errors with custom validation" do
      always_fail = fn _value -> {:error, "custom failure"} end
      opts = [min: 10, validate: always_fail]

      result = Validator.run("short", :string, opts)
      assert {:error, errors} = result
      assert "must be at least 10 characters long" in errors
      assert "custom failure" in errors
    end
  end

  describe "edge cases" do
    test "handles empty options list" do
      assert Validator.run("test", :string, []) == {:ok, "test"}
    end

    test "filters unsupported options for type" do
      # Trying to use string options on integer type
      assert Validator.run(42, :integer, pattern: ~r/\d+/, starts_with: "1") == {:ok, 42}
    end

    test "handles nil values appropriately" do
      assert Validator.run(nil, :string, []) == {:ok, nil}
      assert Validator.run(nil, :integer, []) == {:ok, nil}
    end
  end

  describe "advanced string validations" do
    test "contains validation" do
      assert Validator.run("hello world", :string, contains: "world") == {:ok, "hello world"}

      assert Validator.run("hello universe", :string, contains: "world") ==
               {:error, ["must contain 'world'"]}
    end

    test "contains validation with nil value" do
      assert Validator.run(nil, :string, contains: "test") ==
               {:error, ["must contain 'test'"]}
    end

    test "length validation" do
      assert Validator.run("hello", :string, length: 5) == {:ok, "hello"}

      assert Validator.run("hi", :string, length: 5) ==
               {:error, ["must be exactly 5 characters long"]}
    end

    test "length validation with nil value" do
      assert Validator.run(nil, :string, length: 5) ==
               {:error, ["must be exactly 5 characters long"]}
    end

    test "alphanumeric validation" do
      assert Validator.run("hello123", :string, alphanumeric: true) == {:ok, "hello123"}

      assert Validator.run("hello-world", :string, alphanumeric: true) ==
               {:error, ["must contain only letters and numbers"]}
    end

    test "alphanumeric validation with nil value" do
      assert Validator.run(nil, :string, alphanumeric: true) ==
               {:error, ["must contain only letters and numbers"]}
    end

    test "pattern validation with nil value" do
      assert Validator.run(nil, :string, pattern: ~r/@/) ==
               {:error, ["does not match pattern"]}
    end

    test "starts_with validation with nil value" do
      assert Validator.run(nil, :string, starts_with: "hello") ==
               {:error, ["does not start with hello"]}
    end

    test "ends_with validation with nil value" do
      assert Validator.run(nil, :string, ends_with: "world") ==
               {:error, ["does not end with world"]}
    end
  end

  describe "numeric validations" do
    test "positive validation for integers" do
      assert Validator.run(5, :integer, positive: true) == {:ok, 5}
      assert Validator.run(-5, :integer, positive: true) == {:error, ["must be positive"]}
      assert Validator.run(0, :integer, positive: true) == {:error, ["must be positive"]}
    end

    test "positive validation for floats" do
      assert Validator.run(5.5, :float, positive: true) == {:ok, 5.5}
      assert Validator.run(-5.5, :float, positive: true) == {:error, ["must be positive"]}
      assert Validator.run(0.0, :float, positive: true) == {:error, ["must be positive"]}
    end

    test "negative validation for integers" do
      assert Validator.run(-5, :integer, negative: true) == {:ok, -5}
      assert Validator.run(5, :integer, negative: true) == {:error, ["must be negative"]}
      assert Validator.run(0, :integer, negative: true) == {:error, ["must be negative"]}
    end

    test "negative validation for floats" do
      assert Validator.run(-5.5, :float, negative: true) == {:ok, -5.5}
      assert Validator.run(5.5, :float, negative: true) == {:error, ["must be negative"]}
      assert Validator.run(0.0, :float, negative: true) == {:error, ["must be negative"]}
    end
  end

  describe "list validations" do
    test "unique validation" do
      assert Validator.run([1, 2, 3], :list, unique: true) == {:ok, [1, 2, 3]}

      assert Validator.run([1, 2, 2, 3], :list, unique: true) ==
               {:error, ["must contain unique values"]}
    end

    test "non_empty validation" do
      assert Validator.run([1, 2, 3], :list, non_empty: true) == {:ok, [1, 2, 3]}
      assert Validator.run([], :list, non_empty: true) == {:error, ["must not be empty"]}
    end
  end

  describe "not_nil validation" do
    test "passes when value is not nil" do
      assert Validator.run("hello", :string, not_nil: true) == {:ok, "hello"}
      assert Validator.run("", :string, not_nil: true) == {:ok, ""}
      assert Validator.run(0, :integer, not_nil: true) == {:ok, 0}
    end

    test "fails when value is nil" do
      assert Validator.run(nil, :string, not_nil: true) == {:error, ["must not be nil"]}
      assert Validator.run(nil, :integer, not_nil: true) == {:error, ["must not be nil"]}
    end
  end

  describe "validation for nil values" do
    test "handles nil values in validations properly" do
      assert Validator.run(nil, :string, []) == {:ok, nil}
      assert Validator.run(nil, :integer, []) == {:ok, nil}
      assert Validator.run(nil, :float, []) == {:ok, nil}
      assert Validator.run(nil, :date, []) == {:ok, nil}
      assert Validator.run(nil, :datetime, []) == {:ok, nil}
      assert Validator.run(nil, :list, []) == {:ok, nil}
    end
  end

  describe "unsupported validation error" do
    test "filters out unsupported validation options" do
      # The validator should filter out unsupported options and not raise
      # Test that it works correctly by providing an unsupported option
      result = Validator.run("test", :string, unsupported_for_string: true)
      assert result == {:ok, "test"}
    end

    test "validates __none__ type with no validation options" do
      # Test that __none__ type works correctly with empty validation options
      result = Validator.run("test", :__none__, [])
      assert result == {:ok, "test"}
    end
  end
end
