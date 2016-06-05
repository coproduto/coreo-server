defmodule CoreoServer.V1.NewWordControllerTest do
  use CoreoServer.ConnCase

  alias CoreoServer.NewWord
  @valid_attrs %{name: "some content", votes: 42}
  @invalid_attrs %{}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  test "lists all entries on index", %{conn: conn} do
    conn = get conn, v1_new_word_path(conn, :index)
    assert json_response(conn, 200)["data"] == []
  end

  test "shows chosen resource", %{conn: conn} do
    new_word = Repo.insert! %NewWord{}
    conn = get conn, v1_new_word_path(conn, :show, new_word)
    assert json_response(conn, 200)["data"] == %{"id" => new_word.id,
      "name" => new_word.name,
      "votes" => new_word.votes}
  end

  test "does not show resource and instead throw error when id is nonexistent", %{conn: conn} do
    assert_error_sent 404, fn ->
      get conn, v1_new_word_path(conn, :show, -1)
    end
  end

  test "creates and renders resource when data is valid", %{conn: conn} do
    conn = post conn, v1_new_word_path(conn, :create), new_word: @valid_attrs
    assert json_response(conn, 201)["data"]["id"]
    assert Repo.get_by(NewWord, @valid_attrs)
  end

  test "does not create resource and renders errors when data is invalid", %{conn: conn} do
    conn = post conn, v1_new_word_path(conn, :create), new_word: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "updates and renders chosen resource when data is valid", %{conn: conn} do
    new_word = Repo.insert! %NewWord{}
    conn = put conn, v1_new_word_path(conn, :update, new_word), new_word: @valid_attrs
    assert json_response(conn, 200)["data"]["id"]
    assert Repo.get_by(NewWord, @valid_attrs)
  end

  test "does not update chosen resource and renders errors when data is invalid", %{conn: conn} do
    new_word = Repo.insert! %NewWord{}
    conn = put conn, v1_new_word_path(conn, :update, new_word), new_word: @invalid_attrs
    assert json_response(conn, 422)["errors"] != %{}
  end

  test "deletes chosen resource", %{conn: conn} do
    new_word = Repo.insert! %NewWord{}
    conn = delete conn, v1_new_word_path(conn, :delete, new_word)
    assert response(conn, 204)
    refute Repo.get(NewWord, new_word.id)
  end
end
