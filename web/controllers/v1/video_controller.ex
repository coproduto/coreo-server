defmodule CoreoServer.V1.VideoController do
  use CoreoServer.Web, :controller

  def get_video(conn, _params) do
    video = CoreoServer.ConfigManager.get(CoreoServer.ConfigManager, :video)

    case video do
      {:ok, nil} ->
	conn
	|> put_resp_content_type("application/json")
	|> send_resp(200, "{ \"data\": {\"code\": \"\"} }")
      {:ok, str} when is_binary(str) ->
	conn
	|> put_resp_content_type("application/json")
	|> send_resp(200, "{ \"data\": {\"code\": #{str}} }")
      _ ->
	conn
	|> put_resp_content_type("application/json")
	|> send_resp(500, "{ \"data\": \"Internal server error\" }")
    end
  end
end
