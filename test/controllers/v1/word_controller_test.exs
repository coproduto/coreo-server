defmodule CoreoServer.V1.WordControllerTest do
  use CoreoServer.ConnCase

  alias CoreoServer.Word
  @valid_attrs %{name: "some content", votes: 42}
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, v1_word_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    word = Repo.insert! %Word{}
    conn = get conn, v1_word_path(conn, :show, word)
    assert json_response(conn, 200)["data"] == %{"id" => word.id,
      "name" => word.name,
      "votes" => word.votes}
  end

  test "does not show resource and instead throw error when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, v1_word_path(conn, :show, -1)
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, v1_word_path(conn, :create), word: @valid_attrs
    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get_by(Word, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, v1_word_path(conn, :create), word: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    word = Repo.insert! %Word{}
    conn = put conn, v1_word_path(conn, :update, word), word: @valid_attrs
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(Word, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    word = Repo.insert! %Word{}
    conn = put conn, v1_word_path(conn, :update, word), word: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    word = Repo.insert! %Word{}
    conn = delete conn, v1_word_path(conn, :delete, word)
    assert response(conn, 204)
    refute Repo.get(Word, word.id)
  end
end
