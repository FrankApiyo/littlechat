defmodule LittlechatWeb.Room.ShowLive do
  use LittlechatWeb, :live_view

  alias Littlechat.Organizer

  def mount(%{"slug" => slug}, _session, socket) do
    case Organizer.get_room(slug) do
      nil ->
        # If a room is not, redirect or show an error message
        {:ok, push_navigate(socket, to: "/404")}

      room ->
        {:ok, assign(socket, room: room)}
    end
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1><%= @room.title %></h1>
      <p>Slug: <%= @room.slug %></p>
    </div>
    """
  end
end
