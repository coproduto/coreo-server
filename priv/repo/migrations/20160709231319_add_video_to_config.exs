defmodule CoreoServer.Repo.Migrations.AddVideoToConfig do
  use Ecto.Migration

  def change do
    alter table(:configs) do
      add :video, :string
    end
  end
end
