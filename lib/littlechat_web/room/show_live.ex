defmodule LittlechatWeb.Room.ShowLive do
  use LittlechatWeb, :live_view

  alias Littlechat.Organizer
  alias LittlechatWeb.Presence

  @topic "users:video"

  def mount(%{"slug" => slug}, _session, socket) do
    %{current_user: current_user} = socket.assigns

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Littlechat.PubSub, @topic)

      Phoenix.PubSub.subscribe(
        Littlechat.PubSub,
        "room: " <> slug <> ":" <> user_to_username(current_user)
      )

      {:ok, _} =
        Presence.track(self(), @topic, current_user.id, %{
          username: current_user |> user_to_username
        })
    end

    case Organizer.get_room(slug) do
      nil ->
        # If a room is not, redirect or show an error message
        {:ok, push_navigate(socket, to: "/404")}

      room ->
        presences = Presence.list(@topic)

        {:ok,
         socket
         |> assign(room: room)
         |> assign(:offer_requests, [])
         |> assign(:ice_candidate_offers, [])
         |> assign(:sdp_offers, [])
         |> assign(:answers, [])
         |> assign(:presences, simple_presence_map(presences))}
    end
  end

  def send_direct_message(slug, to_user, event, payload) do
    LittlechatWeb.Endpoint.broadcast_from(
      self(),
      "room: " <> slug <> ":" <> to_user,
      event,
      payload
    )
  end

  def user_to_username(user) do
    user.email |> String.split("@") |> hd()
  end

  def simple_presence_map(presences) do
    Enum.into(presences, %{}, fn {user_id, %{metas: [meta | _]}} -> {user_id, meta} end)
  end

  def all_users_but_me(all_users, current_user) do
    Enum.filter(all_users, fn user_map ->
      {_key, value} = user_map
      value.username != user_to_username(current_user)
    end)
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

      <hr />

      <div class="streams">
        <video id="local-video" playsinline autoplay muted width="600" style="border: 2px solid red;">
        </video>

        <hr />
        <video
          :for={{_user_id, meta} <- all_users_but_me(@presences, @current_user)}
          data-username={meta.username}
          id={"video-remote-#{meta.username}"}
          phx-hook="InitUser"
          playsinline
          autoplay
          muted
          width="600"
          style="border: 2px solid green;"
        >
        </video>
      </div>

      <button class="button" phx-hook="JoinCall" id="join-call">Join Call</button>

      <div id="offer-requests">
        <%= for request <- @offer_requests do %>
          <span
            id={"offer-request-from-#{request.from_user}"}
            phx-hook="HandleOfferRequest"
            data-from-username={request.from_user}
          >
          </span>
        <% end %>
      </div>

      <div id="sdp-offers">
        <%= for sdp_offer <- @sdp_offers do %>
          <span
            id={"sdp-offer-#{sdp_offer["from_user"]}"}
            phx-hook="HandleSdpOffer"
            data-from-username={sdp_offer["from_user"]}
            data-sdp={sdp_offer["description"]["sdp"]}
          >
          </span>
        <% end %>
      </div>

      <div id="sdp-answers">
        <%= for answer <- @answers do %>
          <span
            id={"sdp-offer-#{answer["from_user"]}"}
            phx-hook="HandleAnswer"
            data-from-username={answer["from_user"]}
            data-sdp={answer["description"]["sdp"]}
          >
          </span>
        <% end %>
      </div>

      <div id="ice-candidates">
        <%= for ice_candidate_offer <- @ice_candidate_offers do %>
          <span
            id={"sdp-offer-#{ice_candidate_offer["from_user"]}"}
            phx-hook="HandleIceCandidateOffer"
            data-from-username={ice_candidate_offer["from_user"]}
            data-ice-candidate={ice_candidate_offer["description"]}
          >
          </span>
        <% end %>
      </div>
    </div>
    """
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    socket =
      socket |> remove_presences(diff.leaves) |> add_presences(diff.joins)

    {:noreply, socket}
  end

  def handle_info(%{event: "request_offers", payload: request}, socket) do
    {:noreply, socket |> assign(:offer_requests, socket.assigns.offer_requests ++ [request])}
  end

  def handle_info(%{event: "new_ice_candidate", payload: payload}, socket) do
    {:noreply,
     socket |> assign(:ice_candidate_offers, socket.assigns.ice_candidate_offers ++ [payload])}
  end

  def handle_info(%{event: "new_sdp_offer", payload: payload}, socket) do
    {:noreply, socket |> assign(:sdp_offers, socket.assigns.new_sdp_offer ++ [payload])}
  end

  def handle_info(%{event: "new_answer", payload: payload}, socket) do
    {:noreply, socket |> assign(:answers, socket.assigns.answers ++ [payload])}
  end

  def remove_presences(socket, leaves) do
    user_ids = Enum.map(leaves, fn {user_id, _} -> user_id end)
    presences = Map.drop(socket.assigns.presences, user_ids)
    assign(socket, :presences, presences)
  end

  defp add_presences(socket, joins) do
    presences =
      Map.merge(
        socket.assigns.presences,
        simple_presence_map(joins)
      )

    assign(socket, :presences, presences)
  end

  def handle_event(
        "join_call",
        _params,
        %{
          assigns: %{
            presences: presences,
            current_user: current_user,
            room: %{slug: slug}
          }
        } = socket
      ) do
    for {_user_id, meta} <-
          all_users_but_me(presences, current_user) do
      send_direct_message(
        slug,
        meta.username,
        "request_offers",
        %{
          from_user: user_to_username(current_user)
        }
      )
    end

    {:noreply, socket}
  end

  def handle_event(
        "new_ice_candidate",
        payload,
        %{
          assigns: %{
            current_user: current_user,
            room: %{slug: slug}
          }
        } = socket
      ) do
    payload = Map.merge(payload, %{"from_user" => user_to_username(current_user)})

    send_direct_message(slug, payload["toUser"], "new_ice_candidate", payload)
    {:noreply, socket}
  end

  def handle_event(
        "new_sdp_offer",
        payload,
        %{
          assigns: %{
            current_user: current_user,
            room: %{slug: slug}
          }
        } = socket
      ) do
    payload = Map.merge(payload, %{"from_user" => user_to_username(current_user)})
    send_direct_message(slug, payload["toUser"], "new_sdp_offer", payload)
    {:noreply, socket}
  end

  def handle_event(
        "new_answer",
        payload,
        %{
          assigns: %{
            current_user: current_user,
            room: %{slug: slug}
          }
        } = socket
      ) do
    payload = Map.merge(payload, %{"from_user" => user_to_username(current_user)})
    send_direct_message(slug, payload["toUser"], "new_answer", payload)
    {:noreply, socket}
  end
end
