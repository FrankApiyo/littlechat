defmodule LittlechatWeb.Room.ShowLive do
  use LittlechatWeb, :live_view

  alias Littlechat.Organizer
  alias LittlechatWeb.Presence

  @topic "users:video"

  def mount(%{"slug" => slug}, _session, socket) do
    %{current_user: current_user} = socket.assigns

    if connected?(socket) do
      {:ok, _} =
        Presence.track(self(), @topic, current_user.id, %{
          username: current_user.email |> String.split("@") |> hd()
        })
    end

    presences = Presence.list(@topic)
    socket = assign(socket, :presences, simple_presence_map(presences))

    case Organizer.get_room(slug) do
      nil ->
        # If a room is not, redirect or show an error message
        {:ok, push_navigate(socket, to: "/404")}

      room ->
        {:ok, assign(socket, room: room)}
    end
  end

  def simple_presence_map(presences) do
    Enum.into(presences, %{}, fn {user_id, %{metas: [meta | _]}} -> {user_id, meta} end)
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1><%= @room.title %></h1>
      <p>Slug: <%= @room.slug %></p>
      <ul style="background: beige;">
        <li :for={{_user_id, meta} <- @presences}>
          <%= meta.username %>
        </li>
      </ul>
    </div>
    """
  end
end
