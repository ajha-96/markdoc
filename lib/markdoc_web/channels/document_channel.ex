defmodule MarkdocWeb.DocumentChannel do
  @moduledoc """
  Phoenix Channel for real-time document collaboration.

  Handles:
  - User joining/leaving documents
  - Text change operations with conflict resolution
  - Cursor position and selection updates
  - Typing indicators and user presence
  """

  use MarkdocWeb, :channel

  require Logger

  alias Markdoc.Documents
  alias Markdoc.Documents.Operations

  @impl true
  def join("document:" <> document_id, payload, socket) do
    user_name = payload["user_name"]
    session_id = payload["session_id"]

    Logger.info("User #{user_name} joining document #{document_id} via channel")

    # Assign user info to socket
    socket =
      socket
      |> assign(:user_name, user_name)
      |> assign(:session_id, session_id)

    # Ensure document exists and user can join
    case Documents.sync_document_from_disk(document_id) do
      {:ok, _document} ->
        # Join the user to the document with existing session_id
        case Documents.join_document(document_id, user_name, session_id) do
          {:ok, updated_document, assigned_session_id} ->
            socket =
              socket
              |> assign(:document_id, document_id)
              # Use assigned session ID
              |> assign(:session_id, assigned_session_id)

            # Get current document state to send to joining user
            current_state = %{
              content: updated_document.content,
              version: updated_document.version,
              users: updated_document.users,
              cursor_positions: get_cursor_positions(updated_document)
            }

            # Schedule broadcast after join completes
            send(
              self(),
              {:after_join, assigned_session_id, updated_document.users[assigned_session_id]}
            )

            {:ok, current_state, socket}

          {:error, reason} ->
            Logger.error("Failed to join document: #{inspect(reason)}")
            {:error, %{reason: "Failed to join document"}}
        end

      {:error, :not_found} ->
        {:error, %{reason: "Document not found"}}

      {:error, reason} ->
        Logger.error("Error accessing document: #{inspect(reason)}")
        {:error, %{reason: "Document unavailable"}}
    end
  end

  @impl true
  def handle_in("text_operation", %{"operation" => operation}, socket) do
    %{document_id: document_id, session_id: session_id} = socket.assigns

    # Apply the text operation
    case apply_text_operation(document_id, session_id, operation) do
      {:ok, transformed_op, new_version} ->
        # Broadcast the transformed operation to all other users
        Logger.debug("🔥 Broadcasting text_operation: #{inspect(transformed_op)} to other users")

        broadcast_from(socket, "text_operation", %{
          operation: transformed_op,
          session_id: session_id,
          version: new_version
        })

        Logger.debug("✅ Broadcasted successfully")

        {:reply, {:ok, %{version: new_version, operation: transformed_op}}, socket}

      {:error, reason} ->
        Logger.error("Text operation failed: #{inspect(reason)}")
        {:reply, {:error, %{reason: "Operation failed"}}, socket}
    end
  end

  @impl true
  def handle_in("cursor_update", %{"position" => position, "selection" => selection}, socket) do
    %{document_id: document_id, session_id: session_id} = socket.assigns

    # Update cursor position in document manager
    :ok = Documents.update_cursor_position(document_id, session_id, position, selection)

    # Broadcast cursor update to other users
    broadcast_from(socket, "cursor_update", %{
      session_id: session_id,
      position: position,
      selection: selection
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("typing_status", %{"typing" => typing}, socket) do
    %{document_id: document_id, session_id: session_id} = socket.assigns

    # Update typing status
    :ok = Documents.update_typing_status(document_id, session_id, typing)

    # Broadcast typing status to other users
    broadcast_from(socket, "typing_status", %{
      session_id: session_id,
      typing: typing
    })

    {:noreply, socket}
  end

  @impl true
  def handle_in("request_sync", _payload, socket) do
    %{document_id: document_id} = socket.assigns

    # Send current document state for sync (no disk reload needed)
    case Documents.get_document(document_id) do
      {:ok, document} ->
        current_state = %{
          content: document.content,
          version: document.version,
          users: document.users,
          cursor_positions: get_cursor_positions(document)
        }

        {:reply, {:ok, current_state}, socket}

      {:error, _reason} ->
        {:reply, {:error, %{reason: "Sync failed"}}, socket}
    end
  end

  @impl true
  def handle_info({:after_join, session_id, user}, socket) do
    # Broadcast user joined to other users after the socket has joined
    broadcast_from(socket, "user_joined", %{
      session_id: session_id,
      user: user
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_left, session_id}, socket) do
    # Handle user leaving from DocumentManager
    broadcast_from(socket, "user_left", %{session_id: session_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:user_joined, session_id, user}, socket) do
    # Handle user joining from DocumentManager
    broadcast_from(socket, "user_joined", %{
      session_id: session_id,
      user: user
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:cursor_updated, session_id, position, selection}, socket) do
    # Handle cursor updates from DocumentManager
    broadcast_from(socket, "cursor_update", %{
      session_id: session_id,
      position: position,
      selection: selection
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:typing_updated, session_id, typing}, socket) do
    # Handle typing status updates from DocumentManager
    broadcast_from(socket, "typing_status", %{
      session_id: session_id,
      typing: typing
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:content_updated, content, version}, socket) do
    # Handle content updates from DocumentManager
    broadcast_from(socket, "content_updated", %{
      content: content,
      version: version
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:save_status, status, timestamp}, socket) do
    # Handle save status updates from DocumentManager
    broadcast_from(socket, "save_status", %{
      status: status,
      timestamp: timestamp
    })

    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    # User disconnected - remove from document
    if socket.assigns[:document_id] && socket.assigns[:session_id] do
      Documents.leave_document(socket.assigns.document_id, socket.assigns.session_id)

      # Broadcast user left
      broadcast_from(socket, "user_left", %{
        session_id: socket.assigns.session_id
      })
    end

    Logger.info("User disconnected from document: #{inspect(reason)}")
    :ok
  end

  # Private helper functions

  defp apply_text_operation(document_id, _session_id, operation) do
    # Pure in-memory operation application for better performance

    with {:ok, document} <- Documents.get_document(document_id) do
      # Parse the operation
      case parse_operation(operation) do
        {:ok, parsed_op} ->
          Logger.debug(
            "📝 Applying #{parsed_op.type} at pos #{parsed_op.position} - content len: #{String.length(document.content)}"
          )

          # Apply operation to document content
          case Operations.apply_operation(document.content, parsed_op) do
            {:ok, new_content} ->
              Logger.debug("✅ Operation success - new len: #{String.length(new_content)}")

              # Update document in memory only (no disk sync during active editing)
              :ok = Documents.update_document_content(document_id, new_content)

              # Return success with new version
              {:ok, parsed_op, document.version + 1}

            {:error, reason} ->
              Logger.error(
                "❌ Operation failed: #{inspect(reason)} for #{parsed_op.type} at #{parsed_op.position}"
              )

              {:error, reason}
          end

        {:error, reason} ->
          Logger.error("❌ Operation parse failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp parse_operation(%{
         "type" => type,
         "position" => position,
         "content" => content,
         "length" => length
       })
       when type in ["insert", "delete", "retain"] do
    {:ok,
     %{
       type: String.to_atom(type),
       position: position,
       content: content,
       length: length,
       timestamp: DateTime.utc_now()
     }}
  end

  defp parse_operation(%{
         "type" => "replace",
         "position" => position,
         "content" => content,
         "length" => length,
         "deletedLength" => deleted_length
       }) do
    {:ok,
     %{
       type: :replace,
       position: position,
       content: content,
       length: length,
       deleted_length: deleted_length,
       timestamp: DateTime.utc_now()
     }}
  end

  defp parse_operation(_invalid_operation) do
    {:error, :invalid_operation}
  end

  defp get_cursor_positions(document) do
    document.users
    |> Map.values()
    |> Enum.map(fn user ->
      %{
        session_id: user.session_id,
        name: user.name,
        color: user.color,
        position: user.cursor_position,
        selection: user.selection,
        typing: user.typing
      }
    end)
  end
end
