defmodule Filtr.Processor.OpaqueTest do
  use ExUnit.Case, async: true

  import Filtr.Processor.Opaque, only: [is_opaque: 1]

  defp opaque?(value) when is_opaque(value), do: true
  defp opaque?(_value), do: false

  describe "is_opaque/1" do
    test "matches :__none__ and nil" do
      assert opaque?(:__none__)
      assert opaque?(nil)
    end

    test "does not match other values" do
      refute opaque?(:string)
      refute opaque?("")
      refute opaque?(false)
      refute opaque?(%{})
      refute opaque?([])
    end

    test "works in a guard at compile time" do
      assert is_opaque(nil)
      refute is_opaque(:integer)
    end
  end
end
