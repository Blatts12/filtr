defmodule Pex.ValidatorsTest do
  use ExUnit.Case
  doctest Pex.Validators

  alias Pex.Validators

  describe "positive/1" do
    test "accepts positive numbers" do
      assert {:ok, 5} = Validators.positive(5)
      assert {:ok, 1} = Validators.positive(1)
      assert {:ok, 100.5} = Validators.positive(100.5)
    end

    test "rejects non-positive numbers" do
      assert {:error, "must be positive"} = Validators.positive(0)
      assert {:error, "must be positive"} = Validators.positive(-1)
      assert {:error, "must be positive"} = Validators.positive(-0.5)
    end
  end

  describe "range/3" do
    test "accepts values within range" do
      assert {:ok, 5} = Validators.range(5, 1, 10)
      assert {:ok, 1} = Validators.range(1, 1, 10)
      assert {:ok, 10} = Validators.range(10, 1, 10)
    end

    test "rejects values outside range" do
      assert {:error, "must be between 1 and 10"} = Validators.range(0, 1, 10)
      assert {:error, "must be between 1 and 10"} = Validators.range(11, 1, 10)
      assert {:error, "must be between 5 and 15"} = Validators.range(4, 5, 15)
    end
  end

  describe "min_length/2" do
    test "accepts strings with sufficient length" do
      assert {:ok, "hello"} = Validators.min_length("hello", 3)
      assert {:ok, "abc"} = Validators.min_length("abc", 3)
    end

    test "rejects strings that are too short" do
      assert {:error, "must be at least 3 characters long"} = Validators.min_length("hi", 3)
      assert {:error, "must be at least 5 characters long"} = Validators.min_length("test", 5)
    end
  end

  describe "max_length/2" do
    test "accepts strings within length limit" do
      assert {:ok, "hello"} = Validators.max_length("hello", 10)
      assert {:ok, "test"} = Validators.max_length("test", 4)
    end

    test "rejects strings that are too long" do
      assert {:error, "must be at most 5 characters long"} = 
        Validators.max_length("too long", 5)
      assert {:error, "must be at most 3 characters long"} = 
        Validators.max_length("test", 3)
    end
  end

  describe "one_of/2" do
    test "accepts values from the allowed list" do
      options = ["red", "green", "blue"]
      assert {:ok, "red"} = Validators.one_of("red", options)
      assert {:ok, "blue"} = Validators.one_of("blue", options)
    end

    test "rejects values not in the allowed list" do
      options = ["red", "green", "blue"]
      assert {:error, "must be one of: red, green, blue"} = 
        Validators.one_of("yellow", options)
      assert {:error, "must be one of: a, b"} = 
        Validators.one_of("c", ["a", "b"])
    end
  end

  describe "format/2" do
    test "accepts strings matching the regex" do
      email_regex = ~r/^[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}$/
      assert {:ok, "user@example.com"} = Validators.format("user@example.com", email_regex)
      assert {:ok, "test.email+tag@domain.org"} = 
        Validators.format("test.email+tag@domain.org", email_regex)
    end

    test "rejects strings not matching the regex" do
      email_regex = ~r/^[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}$/
      assert {:error, "invalid format"} = Validators.format("invalid-email", email_regex)
      assert {:error, "invalid format"} = Validators.format("@domain.com", email_regex)
    end

    test "rejects non-string values" do
      regex = ~r/test/
      assert {:error, "invalid format"} = Validators.format(123, regex)
      assert {:error, "invalid format"} = Validators.format(nil, regex)
    end
  end

  describe "not_empty/1" do
    test "accepts non-empty lists" do
      assert {:ok, ["a", "b"]} = Validators.not_empty(["a", "b"])
      assert {:ok, [1]} = Validators.not_empty([1])
    end

    test "rejects empty lists" do
      assert {:error, "cannot be empty"} = Validators.not_empty([])
    end

    test "rejects non-list values" do
      assert {:error, "must be a list"} = Validators.not_empty("string")
      assert {:error, "must be a list"} = Validators.not_empty(123)
    end
  end

  describe "length/2" do
    test "accepts lists with correct length" do
      assert {:ok, ["a", "b"]} = Validators.length(["a", "b"], 2)
      assert {:ok, [1]} = Validators.length([1], 1)
      assert {:ok, []} = Validators.length([], 0)
    end

    test "rejects lists with incorrect length" do
      assert {:error, "must have exactly 2 items"} = Validators.length(["a"], 2)
      assert {:error, "must have exactly 1 items"} = Validators.length(["a", "b"], 1)
    end

    test "rejects non-list values" do
      assert {:error, "must be a list"} = Validators.length("string", 1)
      assert {:error, "must be a list"} = Validators.length(123, 1)
    end
  end
end