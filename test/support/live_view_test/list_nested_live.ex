defmodule Filtr.LiveViewTest.ListNestedLive do
  @moduledoc false
  use Phoenix.LiveView, namespace: Filtr
  use Filtr.LiveView

  param :users, :list do
    param :name, :string, required: true
    param :age, :integer, min: 18
  end

  param :tags, :list do
    param :label, :string, default: "default"
    param :color, :string, in: ["red", "blue", "green"], default: "blue"
  end

  param :items, :list do
    param :name, :string, required: true
    param :quantity, :integer, min: 1, default: 1
  end

  @impl true
  def render(assigns) do
    ~H""
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
