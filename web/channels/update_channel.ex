defmodule CoreoServer.UpdateChannel do
  use CoreoServer.Web, :channel

  @channel_topic "updates:lobby"

  def broadcast_word(word) do
    payload = %{
      "name"  => word.name,
      "votes" => word.votes,
      "id"    => word.id
    }

    CoreoServer.Endpoint.broadcast(@channel_topic, "update:word", payload)
  end

  def broadcast_new_word(new_word) do
    payload = %{
      "name"  => new_word.name,
      "votes" => new_word.votes,
      "id"    => new_word.id
    }

    CoreoServer.Endpoint.broadcast(@channel_topic, "update:new_word", payload)
  end

  def broadcast_all_invalidate do
    CoreoServer.Endpoint.broadcast(@channel_topic, "update:invalidate_all", %{})
  end

  def broadcast_words_invalidate do
    CoreoServer.Endpoint.broadcast(@channel_topic, "update:invalidate_words", %{})
  end

  def broadcast_new_words_invalidate do
    CoreoServer.Endpoint.broadcast(@channel_topic, "update:invalidate_new_words", %{})
  end

  def join("updates:lobby", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, %{}}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (updates:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # This is invoked every time a notification is being broadcast
  # to the client. The default implementation is just to push it
  # downstream but one could filter or change the event.
  def handle_out(event, payload, socket) do
    push socket, event, payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
