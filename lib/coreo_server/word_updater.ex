defmodule CoreoServer.WordUpdater do
  use Supervisor

  alias CoreoServer.NewWord
  alias CoreoServer.Word

  import Ecto
  import Ecto.Changeset
  import Ecto.Query

  @interval 30000

  def start_link do
    IO.puts "Word updater started!"
    Supervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(Task, [fn -> __MODULE__.update_words(@interval) end])
    ]

    opts = [strategy: :one_for_one]
    
    IO.puts "Starting supervision!"
    supervise(children, opts)
  end

  #Every X seconds, get the most voted word
  #Add the most voted word to "words"
  #Clear all votes
  def update_words(wait) do
    :timer.sleep(wait)

    result = CoreoServer.Repo.transaction(fn ->
      greatest_query = from nw in CoreoServer.NewWord,
      select: max(nw.votes)

      greatest_value = CoreoServer.Repo.all(greatest_query)

      case greatest_value do
	[ greatest | _ ] ->
	  query = from nw in CoreoServer.NewWord,
          where: nw.votes == ^greatest,
	  select: nw.name
	  
	  chosen_word = CoreoServer.Repo.all(query)

	  add_to_words(chosen_word)

	_ ->
	  :no_op
      end
    end)

    case result do
      {:ok, word} ->
	CoreoServer.UpdateChannel.broadcast_all_invalidate
      {:error, changeset} ->
	IO.puts "Word update failed with changeset #{changeset}"
      :no_op ->
	IO.puts "Word update: No op"
    end
  end

  def add_to_words(word?) do
    case word? do
      [ word | _ ] ->
	params = %{"name" => word, "votes" => 0}
	changeset = Word.changeset(%Word{}, params)
	CoreoServer.Repo.insert!(changeset)

      _ -> 
	:no_op
    end
  end
end
