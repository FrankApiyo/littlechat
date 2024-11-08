defmodule Littlechat.Organizer.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :title, :string
    field :slug, :string
    belongs_to :user, Littlechat.Accounts.User
    has_many :participants, Littlechat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @fields [:title, :slug]

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, @fields ++ [:user_id])
    |> validate_required(@fields)
    |> format_slug()
    |> unique_constraint(:slug)
  end

  defp format_slug(%Ecto.Changeset{changes: %{slug: _}} = changeset) do
    changeset
    |> update_change(:slug, fn slug ->
      slug
      |> String.downcase()
      |> String.replace(" ", "-")
    end)
  end

  defp format_slug(changeset), do: changeset
end
