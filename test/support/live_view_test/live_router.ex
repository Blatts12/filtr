defmodule Filtr.LiveViewTest.LiveRouter do
  @moduledoc false

  use Phoenix.Router

  import Phoenix.LiveView.Router

  alias Filtr.LiveViewTest.DefaultLive
  alias Filtr.LiveViewTest.DoubleNestedLive
  alias Filtr.LiveViewTest.EmptyNestedLive
  alias Filtr.LiveViewTest.FallbackLive
  alias Filtr.LiveViewTest.MixedLive
  alias Filtr.LiveViewTest.NestedLive
  alias Filtr.LiveViewTest.RaiseLive
  alias Filtr.LiveViewTest.StrictLive

  live_session :filtr do
    live("/fallback", FallbackLive)
    live("/strict", StrictLive)
    live("/raise", RaiseLive)
    live("/default", DefaultLive)
    live("/nested", NestedLive)
    live("/mixed", MixedLive)
    live("/double_nested", DoubleNestedLive)
    live("/empty_nested", EmptyNestedLive)
  end

  def session(%Plug.Conn{}, extra), do: Map.put(extra, "called", true)
end
