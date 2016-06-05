defmodule CoreoServer.Repo.Migrations.CreateNewWord do
  use Ecto.Migration

  def change do
    create table(:new_words) do
      add :name, :string
      add :votes, :integer

      timestamps
    end

  end
end
