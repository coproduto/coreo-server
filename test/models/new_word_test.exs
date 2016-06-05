defmodule CoreoServer.NewWordTest do
  use CoreoServer.ModelCase

  alias CoreoServer.NewWord

  @valid_attrs %{name: "some content", votes: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = NewWord.changeset(%NewWord{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = NewWord.changeset(%NewWord{}, @invalid_attrs)
    refute changeset.valid?
  end
end
