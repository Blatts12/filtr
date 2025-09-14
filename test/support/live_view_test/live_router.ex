defmodule Pex.LiveViewTest.LiveRouter do
  @moduledoc false

  use Phoenix.Router

  import Phoenix.LiveView.Router

  alias Pex.LiveViewTest.DefaultLive
  alias Pex.LiveViewTest.FallbackLive
  alias Pex.LiveViewTest.RaiseLive
  alias Pex.LiveViewTest.StrictLive

  live_session :pex do
    live("/fallback", FallbackLive)
    live("/strict", StrictLive)
    live("/raise", RaiseLive)
    live("/default", DefaultLive)
  end

  def session(%Plug.Conn{}, extra), do: Map.put(extra, "called", true)
end
