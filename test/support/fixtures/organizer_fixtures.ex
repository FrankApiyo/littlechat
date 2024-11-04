defmodule Littlechat.OrganizerFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Littlechat.Organizer` context.
  """

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    {:ok, room} =
      attrs
      |> Enum.into(%{
        slug: "some slug",
        title: "some title"
      })
      |> Littlechat.Organizer.create_room()

    room
  end
end
