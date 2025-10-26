defmodule Filtr.LiveViewTest.LiveRouter do
  @moduledoc false

  use Phoenix.Router

  import Phoenix.LiveView.Router

  alias Filtr.LiveViewTest.DefaultLive
  alias Filtr.LiveViewTest.FallbackLive
  alias Filtr.LiveViewTest.RaiseLive
  alias Filtr.LiveViewTest.StrictLive

  live_session :filtr do
    live("/fallback", FallbackLive)
    live("/strict", StrictLive)
    live("/raise", RaiseLive)
    live("/default", DefaultLive)
  end

  def session(%Plug.Conn{}, extra), do: Map.put(extra, "called", true)
end
