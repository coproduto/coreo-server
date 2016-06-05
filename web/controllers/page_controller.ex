defmodule CoreoServer.PageController do
  use CoreoServer.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
