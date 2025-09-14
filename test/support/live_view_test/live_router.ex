defmodule Pex.LiveViewTest.LiveRouter do
  @moduledoc false

  use Phoenix.Router

  import Phoenix.LiveView.Router

  alias Pex.LiveViewTest.FallbackLive
  alias Pex.LiveViewTest.StrictLive
  alias Pex.LiveViewTest.RaiseLive

  live_session :pex do
    live("/fallback", FallbackLive)
    live("/strict", StrictLive)
    live("/raise", RaiseLive)
  end

  def session(%Plug.Conn{}, extra), do: Map.merge(extra, %{"called" => true})
end
