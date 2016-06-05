defmodule CoreoServer.NewWord do
  use CoreoServer.Web, :model

  schema "new_words" do
    field :name, :string
    field :votes, :integer

    timestamps
  end

  @required_fields ~w(name votes)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, @required_fields, @optional_fields)
  end
end
