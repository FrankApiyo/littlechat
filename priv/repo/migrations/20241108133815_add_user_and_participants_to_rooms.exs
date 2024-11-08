defmodule Littlechat.Repo.Migrations.AddUserAndParticipantsToRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :user_id, references(:users, on_delete: :nothing)
    end

    # for quick lookup by user_id
    create index(:rooms, [:user_id])
  end
end
