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
      resources "/words", WordController, except: [:edit, :new]
      post "/words/increment/:id", WordController, :increment
      post "/words/decrement/:id", WordController, :decrement

      resources "/new_words", NewWordController, except: [:edit, :new]
      post "/new_words/increment/:id", NewWordController, :increment
      post "/new_words/decrement/:id", NewWordController, :decrement
    end
  end
end
