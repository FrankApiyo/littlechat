defmodule Littlechat.Repo.Migrations.AddRoomIdToUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :room_id, references(:rooms, on_delete: :nothing)
    end

    create index(:users, [:room_id])
  end
end
