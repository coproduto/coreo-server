defmodule CoreoServer.Repo.Migrations.CreateConfig do
  use Ecto.Migration

  def change do
    create table(:configs) do
      add :is_active, :boolean, default: false
      add :lock_new_words, :boolean, default: false
      add :lock_words, :boolean, default: false
      add :video, :string, default: ""

      timestamps
    end

  end
end
