defmodule CoreoServer.V1.NewWordController do
  use CoreoServer.Web, :controller

  alias CoreoServer.NewWord

  plug :scrub_params, "new_word" when action in [:create, :update]

  def index(conn, _params) do
    new_words = Repo.all(NewWord)
    render(conn, "index.json", new_words: new_words)
  end

  def create(conn, %{"new_word" => new_word_params}) do
    {_, is_locked} = CoreoServer.ConfigManager.get(CoreoServer.ConfigManager, :lock_new_words)

    if not is_locked do
      changeset = NewWord.changeset(%NewWord{}, new_word_params)

      case Repo.insert(changeset) do
	{:ok, new_word} ->
	  CoreoServer.UpdateChannel.broadcast_new_words_invalidate

          conn
          |> put_status(:created)
          |> put_resp_header("location", v1_new_word_path(conn, :show, new_word))
          |> render("show.json", new_word: new_word)
	{:error, changeset} ->
          conn
          |> put_status(:unprocessable_entity)
          |> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
      end
    else
      render(conn, "error.json", error: "403 Forbidden")
    end
  end

  def show(conn, %{"id" => id}) do
    new_word = Repo.get!(NewWord, id)
    render(conn, "show.json", new_word: new_word)
  end

  def update(conn, %{"id" => id, "new_word" => new_word_params}) do
    new_word = Repo.get!(NewWord, id)
    changeset = NewWord.changeset(new_word, new_word_params)

    case Repo.update(changeset) do
      {:ok, new_word} ->
	CoreoServer.UpdateChannel.broadcast_new_word(new_word)
        render(conn, "show.json", new_word: new_word)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def increment(conn, %{"id" => id}) do
    result = Repo.transaction(fn ->
      new_word = Repo.get!(NewWord, id)
      params = %{"votes" => new_word.votes + 1}
      changeset = NewWord.changeset(new_word, params)

      Repo.update!(changeset)
    end)
    case result do
      {:ok, new_word} ->
	CoreoServer.UpdateChannel.broadcast_new_word(new_word)
	render(conn, "show.json", new_word: new_word)
      {:error, changeset} ->
	conn
	|> put_status(:unprocessable_entity)
	|> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
    end
  end
  
  def decrement(conn, %{"id" => id}) do
    result = Repo.transaction(fn ->
      new_word = Repo.get!(NewWord, id)
      params = %{"votes" => new_word.votes - 1}
      changeset = NewWord.changeset(new_word, params)

      Repo.update!(changeset)
    end)
    case result do
      {:ok, new_word} ->
	CoreoServer.UpdateChannel.broadcast_new_word(new_word)
	render(conn, "show.json", new_word: new_word)
      {:error, changeset} ->
	conn
	|> put_status(:unprocessable_entity)
	|> render(CoreoServer.ChangesetView, "error.json", changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    new_word = Repo.get!(NewWord, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(new_word)

    send_resp(conn, :no_content, "")
  end

  def reset_votes(conn, _params) do
    result = Repo.transaction(fn ->
      Repo.update_all(NewWord, set: [votes: 0])
    end)
    case result do
      {rows, _return} ->
	CoreoServer.UpdateChannel.broadcast_new_words_invalidate
	new_words = Repo.all(NewWord)
	render(conn, "index.json", new_words: new_words)
    end
  end
end
