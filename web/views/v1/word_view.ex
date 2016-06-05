defmodule CoreoServer.V1.WordView do
  use CoreoServer.Web, :view

  def render("index.json", %{words: words}) do
    %{data: render_many(words, CoreoServer.V1.WordView, "word.json")}
  end

  def render("show.json", %{word: word}) do
    %{data: render_one(word, CoreoServer.V1.WordView, "word.json")}
  end

  def render("word.json", %{word: word}) do
    %{id: word.id,
      name: word.name,
      votes: word.votes}
  end
end
