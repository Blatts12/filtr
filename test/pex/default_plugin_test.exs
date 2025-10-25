defmodule Pex.DefaultPluginTest do
  use ExUnit.Case, async: true

  alias Pex.DefaultPlugin

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

  describe "validate/4" do
    test "delegates to Validate module" do
      assert :ok == DefaultPlugin.validate("test", :string, {:min, 2}, [])
      assert {:error, _} = DefaultPlugin.validate("", :string, {:min, 2}, [])
    end
  end

  describe "cast/3" do
    test "delegates to Cast module" do
      assert {:ok, "test"} = DefaultPlugin.cast("test", :string, [])
      assert {:ok, 42} = DefaultPlugin.cast("42", :integer, [])
    end
  end
end
