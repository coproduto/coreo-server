defmodule CoreoServer.V1.AdminController do
  use CoreoServer.Web, :controller

  def lock_new_words(conn, _params) do
    CoreoServer.ConfigManager.toggle(CoreoServer.ConfigManager, :lock_new_words)
    send_resp(conn, 200, "{}")
  end

  def set_video(conn, %{"video" => video_params}) do
    case video_params do
      %{ "code" => code } -> 
	CoreoServer.ConfigManager.set(CoreoServer.ConfigManager, :video, code)
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, "{}")
      _ ->
	IO.puts "Could not update video URL due to malformed request."
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, "")
    end
  end
end
