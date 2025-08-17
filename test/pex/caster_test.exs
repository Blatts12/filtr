defmodule Pex.CasterTest do
  use ExUnit.Case
  doctest Pex.Caster

  alias Pex.Caster

  describe "run/2 and run/3" do
    test "returns ok tuple for successful casting" do
      assert Caster.run("hello", :string) == {:ok, "hello"}
      assert Caster.run("42", :integer) == {:ok, 42}
    end

    test "returns error tuple for failed casting" do
      assert Caster.run("not_a_number", :integer) == {:error, "invalid integer"}
      assert Caster.run("not_a_float", :float) == {:error, "invalid float"}
    end
  end

  describe "empty and nil values" do
    test "passes through empty strings unchanged" do
      assert Caster.run("", :string) == {:ok, ""}
      assert Caster.run("", :integer) == {:ok, ""}
      assert Caster.run("", :float) == {:ok, ""}
      assert Caster.run("", :boolean) == {:ok, ""}
      assert Caster.run("", :date) == {:ok, ""}
      assert Caster.run("", :datetime) == {:ok, ""}
      assert Caster.run("", :list) == {:ok, ""}
    end

    test "passes through nil values unchanged" do
      assert Caster.run(nil, :string) == {:ok, nil}
      assert Caster.run(nil, :integer) == {:ok, nil}
      assert Caster.run(nil, :float) == {:ok, nil}
      assert Caster.run(nil, :boolean) == {:ok, nil}
      assert Caster.run(nil, :date) == {:ok, nil}
      assert Caster.run(nil, :datetime) == {:ok, nil}
      assert Caster.run(nil, :list) == {:ok, nil}
    end
  end

  describe "string casting" do
    test "validates string input" do
      assert Caster.run("hello", :string) == {:ok, "hello"}
      assert Caster.run("", :string) == {:ok, ""}
      assert Caster.run("with spaces", :string) == {:ok, "with spaces"}
    end

    test "rejects non-string input" do
      assert Caster.run(123, :string) == {:error, "invalid string"}
      assert Caster.run([], :string) == {:error, "invalid string"}
      assert Caster.run(%{}, :string) == {:error, "invalid string"}
    end
  end

  describe "integer casting" do
    test "casts string integers" do
      assert Caster.run("42", :integer) == {:ok, 42}
      assert Caster.run("0", :integer) == {:ok, 0}
      assert Caster.run("-42", :integer) == {:ok, -42}
      assert Caster.run("999999", :integer) == {:ok, 999999}
    end

    test "passes through integer values" do
      assert Caster.run(42, :integer) == {:ok, 42}
      assert Caster.run(0, :integer) == {:ok, 0}
      assert Caster.run(-42, :integer) == {:ok, -42}
    end

    test "handles partial integer parsing" do
      assert Caster.run("42abc", :integer) == {:ok, 42}
      assert Caster.run("123.45", :integer) == {:ok, 123}
    end

    test "rejects invalid integer strings" do
      assert Caster.run("not_a_number", :integer) == {:error, "invalid integer"}
      assert Caster.run("abc123", :integer) == {:error, "invalid integer"}
    end
  end

  describe "float casting" do
    test "casts string floats" do
      assert Caster.run("3.14", :float) == {:ok, 3.14}
      assert Caster.run("0.0", :float) == {:ok, 0.0}
      assert Caster.run("-2.5", :float) == {:ok, -2.5}
      assert Caster.run("42", :float) == {:ok, 42.0}
    end

    test "passes through float values" do
      assert Caster.run(3.14, :float) == {:ok, 3.14}
      assert Caster.run(0.0, :float) == {:ok, 0.0}
      assert Caster.run(-2.5, :float) == {:ok, -2.5}
    end

    test "handles partial float parsing" do
      assert Caster.run("3.14abc", :float) == {:ok, 3.14}
    end

    test "rejects invalid float strings" do
      assert Caster.run("not_a_number", :float) == {:error, "invalid float"}
      assert Caster.run("abc3.14", :float) == {:error, "invalid float"}
    end
  end

  describe "boolean casting" do
    test "passes through boolean values" do
      assert Caster.run(true, :boolean) == {:ok, true}
      assert Caster.run(false, :boolean) == {:ok, false}
    end

    test "casts true-like strings" do
      assert Caster.run("true", :boolean) == {:ok, true}
      assert Caster.run("TRUE", :boolean) == {:ok, true}
      assert Caster.run("True", :boolean) == {:ok, true}
      assert Caster.run("1", :boolean) == {:ok, true}
      assert Caster.run("yes", :boolean) == {:ok, true}
      assert Caster.run("YES", :boolean) == {:ok, true}
    end

    test "casts false-like strings" do
      assert Caster.run("false", :boolean) == {:ok, false}
      assert Caster.run("FALSE", :boolean) == {:ok, false}
      assert Caster.run("False", :boolean) == {:ok, false}
      assert Caster.run("0", :boolean) == {:ok, false}
      assert Caster.run("no", :boolean) == {:ok, false}
      assert Caster.run("NO", :boolean) == {:ok, false}
    end

    test "rejects invalid boolean strings" do
      assert Caster.run("maybe", :boolean) == {:error, "invalid boolean"}
      assert Caster.run("2", :boolean) == {:error, "invalid boolean"}
      assert Caster.run("on", :boolean) == {:error, "invalid boolean"}
    end
  end

  describe "date casting" do
    test "passes through Date values" do
      date = ~D[2023-06-15]
      assert Caster.run(date, :date) == {:ok, date}
    end

    test "casts ISO8601 date strings" do
      assert Caster.run("2023-06-15", :date) == {:ok, ~D[2023-06-15]}
      assert Caster.run("2023-12-31", :date) == {:ok, ~D[2023-12-31]}
      assert Caster.run("2023-01-01", :date) == {:ok, ~D[2023-01-01]}
    end

    test "rejects invalid date strings" do
      assert Caster.run("not-a-date", :date) == {:error, "invalid date"}
      assert Caster.run("2023-13-01", :date) == {:error, "invalid date"}
      assert Caster.run("2023-06-32", :date) == {:error, "invalid date"}
      assert Caster.run("06/15/2023", :date) == {:error, "invalid date"}
    end
  end

  describe "datetime casting" do
    test "passes through DateTime values" do
      datetime = ~U[2023-06-15 12:30:45Z]
      assert Caster.run(datetime, :datetime) == {:ok, datetime}
    end

    test "casts ISO8601 datetime strings" do
      assert Caster.run("2023-06-15T12:30:45Z", :datetime) == {:ok, ~U[2023-06-15 12:30:45Z]}
      assert Caster.run("2023-12-31T23:59:59Z", :datetime) == {:ok, ~U[2023-12-31 23:59:59Z]}
    end

    test "casts datetime strings with offset" do
      result = Caster.run("2023-06-15T12:30:45+02:00", :datetime)
      assert match?({:ok, %DateTime{}}, result)
    end

    test "rejects invalid datetime strings" do
      assert Caster.run("not-a-datetime", :datetime) == {:error, "invalid datetime"}
      assert Caster.run("2023-13-01T25:00:00Z", :datetime) == {:error, "invalid datetime"}
      assert Caster.run("06/15/2023 12:30:45", :datetime) == {:error, "invalid datetime"}
    end
  end

  describe "list casting" do
    test "passes through list values" do
      list = ["a", "b", "c"]
      assert Caster.run(list, :list) == {:ok, list}
    end

    test "casts comma-separated strings to lists" do
      assert Caster.run("a,b,c", :list) == {:ok, ["a", "b", "c"]}
      assert Caster.run("apple,banana,orange", :list) == {:ok, ["apple", "banana", "orange"]}
      assert Caster.run("one", :list) == {:ok, ["one"]}
    end

    test "handles empty strings and spaces in list casting" do
      assert Caster.run("a,,c", :list) == {:ok, ["a", "c"]}  # trim: true removes empty strings
      assert Caster.run("  a  ,  b  ,  c  ", :list) == {:ok, ["  a  ", "  b  ", "  c  "]}  # spaces preserved in elements
    end

    test "handles empty string for list" do
      assert Caster.run("", :list) == {:ok, ""}  # empty string passes through unchanged
    end

    test "rejects non-string, non-list values" do
      assert Caster.run(123, :list) == {:error, "invalid list"}
      assert Caster.run(%{}, :list) == {:error, "invalid list"}
    end
  end

  describe "typed list casting" do
    test "casts lists of integers" do
      assert Caster.run(["1", "2", "3"], {:list, :integer}) == {:ok, [1, 2, 3]}
      assert Caster.run([1, 2, 3], {:list, :integer}) == {:ok, [1, 2, 3]}
    end

    test "casts comma-separated strings to typed lists" do
      assert Caster.run("1,2,3", {:list, :integer}) == {:ok, [1, 2, 3]}
      assert Caster.run("1.5,2.5,3.5", {:list, :float}) == {:ok, [1.5, 2.5, 3.5]}
      assert Caster.run("true,false,true", {:list, :boolean}) == {:ok, [true, false, true]}
    end

    test "handles mixed valid and invalid values in typed lists" do
      result = Caster.run(["1", "invalid", "3"], {:list, :integer})
      assert {:error, errors} = result
      assert "invalid integer" in errors
    end

    test "collects unique errors from typed list casting" do
      result = Caster.run(["invalid", "also_invalid", "invalid"], {:list, :integer})
      assert {:error, ["invalid integer"]} = result  # Errors are deduplicated
    end

    test "casts string to typed list" do
      assert Caster.run("1,2,3", {:list, :integer}) == {:ok, [1, 2, 3]}
      assert Caster.run("true,false", {:list, :boolean}) == {:ok, [true, false]}
    end

    test "rejects non-string, non-list values for typed lists" do
      assert Caster.run(123, {:list, :integer}) == {:error, "invalid list"}
      assert Caster.run(%{}, {:list, :string}) == {:error, "invalid list"}
    end
  end

  describe "custom casting functions" do
    test "uses custom 1-arity casting function" do
      upcase_cast = fn value -> {:ok, String.upcase(value)} end
      result = Caster.run("hello", :string, [cast: upcase_cast])
      assert result == {:ok, "HELLO"}
    end

    test "uses custom 2-arity casting function" do
      type_aware_cast = fn value, type -> 
        {:ok, "#{value}_#{type}"}
      end
      result = Caster.run("test", :string, [cast: type_aware_cast])
      assert result == {:ok, "test_string"}
    end

    test "uses custom 3-arity casting function" do
      context_cast = fn value, type, opts ->
        prefix = Keyword.get(opts, :prefix, "")
        {:ok, "#{prefix}#{value}_#{type}"}
      end
      result = Caster.run("test", :string, [cast: context_cast, prefix: "custom_"])
      assert result == {:ok, "custom_test_string"}
    end

    test "handles custom casting function errors" do
      error_cast = fn _value -> {:error, "custom error"} end
      result = Caster.run("test", :string, [cast: error_cast])
      assert result == {:error, "custom error"}
    end

    test "raises error for invalid cast function" do
      assert_raise RuntimeError, "invalid cast function provided", fn ->
        Caster.run("test", :string, [cast: "not_a_function"])
      end
    end
  end

  describe "function type casting" do
    test "calls function when type is a function" do
      cast_fn = fn value -> {:ok, String.upcase(value)} end
      assert Caster.run("hello", cast_fn) == {:ok, "HELLO"}
    end

    test "handles function type casting errors" do
      error_fn = fn _value -> {:error, "function failed"} end
      assert Caster.run("test", error_fn) == {:error, "function failed"}
    end
  end

  describe "special type values" do
    test "handles :__none__ type" do
      assert Caster.run("anything", :__none__) == {:ok, "anything"}
      assert Caster.run(42, :__none__) == {:ok, 42}
    end

    test "handles nil type" do
      assert Caster.run("anything", nil) == {:ok, "anything"}
      assert Caster.run(42, nil) == {:ok, 42}
    end

    test "rejects unsupported types" do
      assert Caster.run("test", :unsupported_type) == {:error, "unsupported type"}
      assert Caster.run("test", :atom) == {:error, "unsupported type"}
    end
  end

  describe "edge cases" do
    test "handles empty options list" do
      assert Caster.run("42", :integer, []) == {:ok, 42}
    end

    test "ignores irrelevant options" do
      assert Caster.run("42", :integer, [irrelevant: true]) == {:ok, 42}
    end

    test "casting with no options defaults to built-in casting" do
      assert Caster.run("42", :integer) == {:ok, 42}
    end
  end
end