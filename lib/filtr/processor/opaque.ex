defmodule Filtr.Processor.Opaque do
  @moduledoc """
  Guard for the values that skip casting.

  `:__none__` marks a param that was never sent, and `nil` marks a key typed as
  passthrough. Both reach the result untouched. Internal module, the API may
  change between releases.
  """

  @opaque_types [:__none__, nil]

  defguard is_opaque(value) when value in @opaque_types
end
