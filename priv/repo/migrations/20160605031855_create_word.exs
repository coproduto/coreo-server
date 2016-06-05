defmodule CoreoServer.Repo.Migrations.CreateWord do
  use Ecto.Migration

  def change do
    create table(:words) do
      add :name, :string
      add :votes, :integer

      timestamps
    end

  end
end
