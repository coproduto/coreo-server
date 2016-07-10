defmodule CoreoServer.V1.AdminController do
  use CoreoServer.Web, :controller

  def lock_new_words(conn, _params) do
    CoreoServer.ConfigManager.toggle(CoreoServer.ConfigManager, :lock_new_words)
    send_resp(conn, :no_content, "")
  end

  def set_video(conn, %{"video" => video_params}) do
    case video_params do
      %{ "code" => code } -> 
	CoreoServer.ConfigManager.set(CoreoServer.ConfigManager, :video, code)
      _ ->
	IO.puts "Could not update video URL due to malformed request."
    end
    send_resp(conn, :no_content, "")
  end
end
