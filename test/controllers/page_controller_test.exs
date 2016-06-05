defmodule CoreoServer.PageControllerTest do
  use CoreoServer.ConnCase

  test "Has elm-container", %{conn: conn} do
    conn = get conn, "/"
    assert html_response(conn, 200) =~ "elm-container"
  end
end
