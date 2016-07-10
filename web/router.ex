defmodule CoreoServer.Router do
  use CoreoServer.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CoreoServer do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  scope "/api", CoreoServer do
    pipe_through :api

    scope "/v1", V1, as: :v1 do
      get  "/words/lock_state", WordController, :lock_state
      resources "/words", WordController, except: [:edit, :new]
      post "/words/increment/:id", WordController, :increment
      post "/words/decrement/:id", WordController, :decrement
      post "/words/reset", WordController, :reset_votes

      get  "/new_words/lock_state", NewWordController, :lock_state
      resources "/new_words", NewWordController, except: [:edit, :new]
      post "/new_words/increment/:id", NewWordController, :increment
      post "/new_words/decrement/:id", NewWordController, :decrement
      post "/new_words/reset", NewWordController, :reset_votes

      post "/admin/lock_new_words", AdminController, :lock_new_words
      post "/admin/lock_words", AdminController, :lock_words
      post "/admin/set_video", AdminController, :set_video

      get "/video", VideoController, :get_video
    end
  end
end
