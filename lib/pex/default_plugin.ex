defmodule Pex.DefaultPlugin do
  @moduledoc false

  use Pex.Plugin

  alias Pex.DefaultPlugin.Cast
  alias Pex.DefaultPlugin.Validate

  @impl Pex.Plugin
  def types do
    [
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

  @impl Pex.Plugin
  def validate(value, type, validator, opts) do
    Validate.validate(value, type, validator, opts)
  end

  @impl Pex.Plugin
  def cast(value, type, opts) do
    Cast.cast(value, type, opts)
  end
end
