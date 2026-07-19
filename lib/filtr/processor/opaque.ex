defmodule Filtr.Processor.Opaque do
  @moduledoc false

  @opaque_types [:__none__, nil]

  defguard is_opaque(value) when value in @opaque_types
end
