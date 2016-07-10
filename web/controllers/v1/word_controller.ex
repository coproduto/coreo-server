defmodule CoreoServer.V1.WordController do
  use CoreoServer.Web, :controller

  alias CoreoServer.Word

  plug :scrub_params, "word" when action in [:create, :update]

  def index(conn, _params) do
    words = Repo.all(Word)
    render(conn, "index.json", words: words)
  end

  def lock_state(conn, _params) do
    result = CoreoServer.ConfigManager.get(CoreoServer.ConfigManager, :lock_words)

    case result do
      {:ok, state} when is_boolean(state) ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, "{ \"data\": { \"state\": #{state} } }")

      _ ->
        send_resp(conn, 500, "")
    end
  end

  def create(conn, %{"word" => word_params}) do
    changeset = Word.changeset(%Word{}, word_params)

    case Repo.insert(changeset) do
      {:ok, word} ->
	CoreoServer.UpdateChannel.broadcast_words_invalidate

        conn
        |> put_status(:created)
        |> put_resp_header("location", v1_word_path(conn, :show, word))
        |> render("show.json", word: word)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def show(conn, %{"id" => id}) do
    word = Repo.get!(Word, id)
    render(conn, "show.json", word: word)
  end

  def update(conn, %{"id" => id, "word" => word_params}) do
    word = Repo.get!(Word, id)
    changeset = Word.changeset(word, word_params)

    case Repo.update(changeset) do
      {:ok, word} ->
        render(conn, "show.json", word: word)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def increment(conn, %{"id" => id}) do
    result = Repo.transaction(fn ->
      word = Repo.get!(Word, id)
      params = %{"votes" => word.votes + 1}
      changeset = Word.changeset(word, params)

      Repo.update!(changeset)
    end)
    case result do
      {:ok, word} ->
	CoreoServer.UpdateChannel.broadcast_word(word)
	render(conn, "show.json", word: word)
      {:error, changeset} ->
	conn
	|> put_status(:unprocessable_entity)
	|> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
    end
  end
  
  def decrement(conn, %{"id" => id}) do
    result = Repo.transaction(fn ->
      word = Repo.get!(Word, id)
      params = %{"votes" => word.votes - 1}
      changeset = Word.changeset(word, params)

      Repo.update!(changeset)
    end)
    case result do
      {:ok, word} ->
	CoreoServer.UpdateChannel.broadcast_word(word)
	render(conn, "show.json", word: word)
      {:error, changeset} ->
	conn
	|> put_status(:unprocessable_entity)
	|> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
    end
  end
    

  def delete(conn, %{"id" => id}) do
    word = Repo.get!(Word, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(word)
    CoreoServer.UpdateChannel.broadcast_words_invalidate

    send_resp(conn, :no_content, "")
  end

  def reset_votes(conn, _params) do
    result = Repo.transaction(fn ->
      Repo.update_all(Word, set: [votes: 0])
    end)
    case result do
      {rows, _return} ->
	CoreoServer.UpdateChannel.broadcast_words_invalidate(true)
	words = Repo.all(Word)
	render(conn, "index.json", words: words)
    end
  end
end
