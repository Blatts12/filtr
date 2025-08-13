defmodule Pex.DecoratorTest do
  use ExUnit.Case

  alias Pex.Decorator

  describe "format_errors/1" do
    test "formats error map with string keys" do
      errors = %{page: "must be positive", limit: "required"}
      
      expected = %{"page" => "must be positive", "limit" => "required"}
      assert ^expected = Decorator.format_errors(errors)
    end

    test "handles empty error map" do
      assert %{} = Decorator.format_errors(%{})
    end

    test "converts atom keys to strings" do
      errors = %{user_id: "invalid", search_term: "too short"}
      
      result = Decorator.format_errors(errors)
      assert Map.has_key?(result, "user_id")
      assert Map.has_key?(result, "search_term")
      assert result["user_id"] == "invalid"
      assert result["search_term"] == "too short"
    end
  end

  # Note: Testing the actual decorator functionality requires a more complex setup
  # with Phoenix controllers, which would be integration tests rather than unit tests.
  # The decorator functionality is better tested in a real Phoenix application context.
end