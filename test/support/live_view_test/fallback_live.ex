defmodule Pex.LiveViewTest.FallbackLive do
  @moduledoc false
  use Phoenix.LiveView, namespace: Pex

  use Pex.LiveView,
    error_mode: :fallback,
    schema: %{
      query: [type: :string, required: true],
      limit: [type: :integer, min: 5, default: 10]
    }

  @impl true
  def render(assigns) do
    ~H"""
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_call({:run, func}, _, socket), do: func.(socket)

  @impl true
  def handle_info({:run, func}, socket), do: func.(socket)

  def run(lv, func) do
    GenServer.call(lv.pid, {:run, func})
  end
end
