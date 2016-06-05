defmodule CoreoServer.V1.NewWordView do
  use CoreoServer.Web, :view

  def render("index.json", %{new_words: new_words}) do
    %{data: render_many(new_words, CoreoServer.V1.NewWordView, "new_word.json")}
  end

  def render("show.json", %{new_word: new_word}) do
    %{data: render_one(new_word, CoreoServer.V1.NewWordView, "new_word.json")}
  end

  def render("new_word.json", %{new_word: new_word}) do
    %{id: new_word.id,
      name: new_word.name,
      votes: new_word.votes}
  end
end
