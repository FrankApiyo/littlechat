defmodule LittlechatWeb.Room.NewLive do
  use LittlechatWeb, :live_view

  alias Littlechat.Organizer.Room
  alias Littlechat.Organizer

  def mount(_params, _session, socket) do
    change_set = Organizer.change_room(%Room{})
    form = to_form(change_set)
    {:ok, assign(socket, title: "", form: form)}
  end

  def render(assigns) do
    ~H"""
    <.simple_form for={@form} phx-change="validate" phx-submit="save">
      <.input
        type="text"
        label="Title"
        field={@form[:title]}
        placeholder="Room title"
        autofocus
        autocomplete="off"
      />
      <.input type="text" label="slug" field={@form[:slug]} placeholder="Room slug" readonly />
      <.button phx-disable-with="saving...">Save</.button>
    </.simple_form>
    """
  end

  def handle_event("validate", %{"room" => %{"title" => title}}, socket) do
    slug = String.downcase(title)

    form =
      %Room{}
      |> Organizer.change_room(%{slug: slug, title: slug})
      |> Map.put(:action, :validate)
      |> IO.inspect()
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"room" => room_params}, socket) do
    %{current_user: current_user} = socket.assigns
    IO.inspect(inspect(current_user), label: "current_user")

    case(Organizer.create_room(current_user, room_params)) do
      {:ok, room} ->
        form = Organizer.change_room(%Room{}) |> to_form
        socket = push_navigate(socket, to: "/room/view/#{room.slug}")
        {:noreply, assign(socket, form: form)}

      {:error, changeset} ->
        form = to_form(changeset)
        socket = assign(socket, form: form)
        {:noreply, socket}
    end
  end
end
