defmodule CoreoServer.V1.AdminController do
  use CoreoServer.Web, :controller

  def most_voted do
    {:ok, words} = Repo.transaction(fn ->
      Repo.all(CoreoServer.Word)
    end)

    sorted = Enum.sort_by(words, fn(word) -> -word.votes end)
    IO.inspect sorted

    first = List.first(sorted)
    
    first.name
  end

  def lock_new_words(conn, _params) do
    CoreoServer.ConfigManager.toggle(CoreoServer.ConfigManager, :lock_new_words)

    lock_result = CoreoServer.ConfigManager.get(CoreoServer.ConfigManager, :lock_new_words)

    case lock_result do
      {:ok, lock_state} ->
        CoreoServer.UpdateChannel.broadcast_lock_state(lock_state)
        send_resp(conn, 200, "{}")
      _ ->
        send_resp(conn, 500, "{}")
    end
  end

  def lock_words(conn, _params) do
    CoreoServer.ConfigManager.toggle(CoreoServer.ConfigManager, :lock_words)

    lock_result = CoreoServer.ConfigManager.get(CoreoServer.ConfigManager, :lock_words)

    case lock_result do
      {:ok, lock_state} ->
        if lock_state do
	  winner = most_voted

          CoreoServer.UpdateChannel.broadcast_end_voting(winner)
          Repo.transaction(fn ->
            Repo.update_all(CoreoServer.Word, set: [votes: 0])
          end)
          CoreoServer.UpdateChannel.broadcast_words_invalidate
        else
          CoreoServer.UpdateChannel.broadcast_start_voting
        end
        send_resp(conn, 200, "{}")
      _ ->
        send_resp(conn, 500, "{}")
    end
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
