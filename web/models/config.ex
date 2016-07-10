defmodule CoreoServer.Config do
  use CoreoServer.Web, :model

  schema "configs" do
    field :is_active, :boolean, default: false
    field :lock_new_words, :boolean, default: false
    field :video, :string, default: ""

    timestamps
  end

  @required_fields ~w(is_active lock_new_words video)
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
