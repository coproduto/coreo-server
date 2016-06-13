defmodule CoreoServer.V1.AdminController do
  use CoreoServer.Web, :controller

  def lock_new_words(conn, _params) do
    CoreoServer.ConfigManager.toggle(CoreoServer.ConfigManager, :lock_new_words)
    send_resp(conn, :no_content, "")
  end
end
