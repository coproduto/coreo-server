defmodule CoreoServer.V1.WordController do
  use CoreoServer.Web, :controller

  alias CoreoServer.Word

  plug :scrub_params, "word" when action in [:create, :update]

  def index(conn, _params) do
    words = Repo.all(Word)
    render(conn, "index.json", words: words)
  end

  def create(conn, %{"word" => word_params}) do
    changeset = Word.changeset(%Word{}, word_params)
    IO.puts "#{inspect changeset}"

    case Repo.insert(changeset) do
      {:ok, word} ->
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

  def delete(conn, %{"id" => id}) do
    word = Repo.get!(Word, id)

    # Here we use delete! (with a bang) because we expect
    # it to always work (and if it does not, it will raise).
    Repo.delete!(word)

    send_resp(conn, :no_content, "")
  end
end
