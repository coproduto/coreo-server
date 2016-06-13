defmodule CoreoServer.ConfigTest do
  use CoreoServer.ModelCase

  alias CoreoServer.Config

  @valid_attrs %{is_active: true, lock_new_words: true}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Config.changeset(%Config{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Config.changeset(%Config{}, @invalid_attrs)
    refute changeset.valid?
  end
end
