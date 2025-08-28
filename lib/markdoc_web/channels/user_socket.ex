defmodule MarkdocWeb.UserSocket do
  @moduledoc """
  Socket for real-time document collaboration.

  Handles WebSocket connections for:
  - Document text changes
  - Cursor position updates
  - User presence tracking
  - Typing indicators
  """

  use Phoenix.Socket

  # Channels
  channel "document:*", MarkdocWeb.DocumentChannel

  @impl true
  def connect(params, socket, _connect_info) do
    # Accept connection and let the channel handle user authentication
    {:ok, socket}
  end

  @impl true
  def id(socket),
    do:
      "user_socket:#{socket.assigns[:session_id] || :crypto.strong_rand_bytes(8) |> Base.encode16()}"
end
