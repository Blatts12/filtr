defmodule Filtr.DefaultPlugin do
  @moduledoc false

  use Filtr.Plugin

  alias Filtr.DefaultPlugin.Cast
  alias Filtr.DefaultPlugin.Validate

  @impl Filtr.Plugin
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

  @impl Filtr.Plugin
  def validate(value, type, validator, opts) do
    Validate.validate(value, type, validator, opts)
  end

  @impl Filtr.Plugin
  def cast(value, type, opts) do
    Cast.cast(value, type, opts)
  end
end
