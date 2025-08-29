defmodule Markdoc.Documents.DocumentManager do
  @moduledoc """
  GenServer that manages a single document's state in memory.

  Each document gets its own DocumentManager process that:
  - Maintains document content and user state
  - Handles text operations and cursor updates
  - Periodically saves to disk
  - Broadcasts changes to subscribed users
  """

  use GenServer

  require Logger

  alias Markdoc.Documents.Document
  alias Markdoc.Storage.FileStore

  @auto_save_interval Application.compile_env(:markdoc, :auto_save_interval, 10_000)
  # 30 minutes
  @inactive_shutdown_time 30 * 60 * 1000

  # Client API

  @doc """
  Starts a DocumentManager for the given document ID.
  """
  @spec start_link(binary()) :: GenServer.on_start()
  def start_link(document_id) do
    GenServer.start_link(__MODULE__, document_id, name: via_tuple(document_id))
  end

  @doc """
  Gets the current document state.
  """
  @spec get_document(binary()) :: Document.t()
  def get_document(document_id) do
    GenServer.call(via_tuple(document_id), :get_document)
  end

  @doc """
  Explicitly syncs document from disk.
  """
  @spec sync_from_disk(binary()) :: Document.t()
  def sync_from_disk(document_id) do
    GenServer.call(via_tuple(document_id), :sync_from_disk)
  end

  @doc """
  Adds a user to the document.
  """
  @spec add_user(binary(), binary(), binary(), binary()) :: :ok
  def add_user(document_id, session_id, name, color) do
    GenServer.call(via_tuple(document_id), {:add_user, session_id, name, color})
  end

  @doc """
  Removes a user from the document.
  """
  @spec remove_user(binary(), binary()) :: :ok
  def remove_user(document_id, session_id) do
    GenServer.call(via_tuple(document_id), {:remove_user, session_id})
  end

  @doc """
  Updates a user's cursor position.
  """
  @spec update_cursor(binary(), binary(), integer(), map() | nil) :: :ok
  def update_cursor(document_id, session_id, position, selection \\ nil) do
    GenServer.cast(via_tuple(document_id), {:update_cursor, session_id, position, selection})
  end

  @doc """
  Updates a user's typing status.
  """
  @spec update_typing(binary(), binary(), boolean()) :: :ok
  def update_typing(document_id, session_id, typing) do
    GenServer.cast(via_tuple(document_id), {:update_typing, session_id, typing})
  end

  @doc """
  Updates the document content.
  """
  @spec update_content(binary(), binary()) :: :ok
  def update_content(document_id, new_content) do
    GenServer.call(via_tuple(document_id), {:update_content, new_content})
  end

  @doc """
  Forces an immediate save to disk.
  """
  @spec save_now(binary()) :: :ok | {:error, term()}
  def save_now(document_id) do
    GenServer.call(via_tuple(document_id), :save_now)
  end

  @doc """
  Checks if a DocumentManager is running for the given document ID.
  """
  @spec running?(binary()) :: boolean()
  def running?(document_id) do
    case GenServer.whereis(via_tuple(document_id)) do
      nil -> false
      _pid -> true
    end
  end

  @doc """
  Starts a DocumentManager if one isn't already running.
  """
  @spec ensure_started(binary()) :: :ok | {:error, term()}
  def ensure_started(document_id) do
    case running?(document_id) do
      true ->
        :ok

      false ->
        case start_link(document_id) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # GenServer callbacks

  @impl true
  def init(document_id) do
    Logger.info("Starting DocumentManager for document: #{document_id}")

    # Load document from file system or create new one
    document =
      case FileStore.load_document(document_id) do
        {:ok, content} ->
          Document.new(document_id, content)

        {:error, :not_found} ->
          # Create new document
          initial_content = "# New Document\n\nStart writing..."

          case FileStore.create_document(document_id, initial_content) do
            :ok ->
              Document.new(document_id, initial_content)

            {:error, reason} ->
              Logger.error("Failed to create document file: #{inspect(reason)}")
              Document.new(document_id, initial_content)
          end

        {:error, reason} ->
          Logger.error("Failed to load document: #{inspect(reason)}")
          Document.new(document_id)
      end

    # Schedule periodic tasks
    schedule_auto_save()
    schedule_inactivity_check()

    {:ok, document}
  end

  @impl true
  def handle_call(:get_document, _from, document) do
    # Return current document state without disk reload during active editing
    {:reply, document, document}
  end

  @impl true
  def handle_call(:sync_from_disk, _from, document) do
    # Explicit sync from disk when requested
    updated_document =
      case reload_from_disk(document) do
        {:ok, fresh_document} ->
          Logger.debug("Synced document #{document.id} from disk")
          # Don't broadcast content changes - Phoenix Channels handle sync
          # Disk changes should be rare anyway (external edits)
          fresh_document

        {:error, reason} ->
          Logger.warning("Failed to sync document #{document.id} from disk: #{inspect(reason)}")
          document
      end

    {:reply, updated_document, updated_document}
  end

  @impl true
  def handle_call({:add_user, session_id, name, color}, _from, document) do
    updated_document = Document.add_user(document, session_id, name, color)
    broadcast_user_joined(updated_document, session_id)
    {:reply, :ok, updated_document}
  end

  @impl true
  def handle_call({:remove_user, session_id}, _from, document) do
    updated_document = Document.remove_user(document, session_id)
    broadcast_user_left(updated_document, session_id)
    {:reply, :ok, updated_document}
  end

  @impl true
  def handle_call({:update_content, new_content}, _from, document) do
    updated_document = Document.update_content(document, new_content)
    # Content updates are handled exclusively by Phoenix Channels
    # No PubSub broadcasts for content changes to avoid conflicts
    {:reply, :ok, updated_document}
  end

  @impl true
  def handle_call(:save_now, _from, document) do
    case save_to_disk(document) do
      :ok ->
        updated_document = Document.mark_saved(document)
        broadcast_save_status(updated_document, "saved")
        {:reply, :ok, updated_document}

      {:error, reason} = error ->
        Logger.error("Failed to save document #{document.id}: #{inspect(reason)}")
        broadcast_save_status(document, "error")
        {:reply, error, document}
    end
  end

  @impl true
  def handle_cast({:remove_user, session_id}, document) do
    updated_document = Document.remove_user(document, session_id)
    broadcast_user_left(updated_document, session_id)
    {:noreply, updated_document}
  end

  @impl true
  def handle_cast({:update_cursor, session_id, position, selection}, document) do
    updated_document = Document.update_cursor(document, session_id, position, selection)
    broadcast_cursor_updated(updated_document, session_id)
    {:noreply, updated_document}
  end

  @impl true
  def handle_cast({:update_typing, session_id, typing}, document) do
    updated_document = Document.update_typing(document, session_id, typing)
    broadcast_typing_updated(updated_document, session_id, typing)
    {:noreply, updated_document}
  end

  @impl true
  def handle_info(:auto_save, document) do
    updated_document =
      if document.dirty do
        Logger.info(
          "💾 Auto-saving document #{document.id} - content: #{String.length(document.content)} chars"
        )

        case save_to_disk(document) do
          :ok ->
            Logger.info("✅ Auto-saved document: #{document.id}")
            saved_document = Document.mark_saved(document)
            broadcast_save_status(saved_document, "saved")
            saved_document

          {:error, reason} ->
            Logger.error("❌ Auto-save failed for document #{document.id}: #{inspect(reason)}")
            broadcast_save_status(document, "error")
            document
        end
      else
        # Document is clean, no need to save
        Logger.debug("⏭️ Skipping auto-save for #{document.id} - no changes")
        document
      end

    schedule_auto_save()
    {:noreply, updated_document}
  end

  @impl true
  def handle_info(:inactivity_check, document) do
    # 30 minutes
    active_users = Document.active_users(document, 30)

    if Enum.empty?(active_users) do
      Logger.info("Shutting down inactive DocumentManager: #{document.id}")
      {:stop, :normal, document}
    else
      schedule_inactivity_check()
      {:noreply, document}
    end
  end

  @impl true
  def terminate(reason, document) do
    Logger.info("DocumentManager terminating for #{document.id}: #{inspect(reason)}")

    # Final save if dirty
    if document.dirty do
      case save_to_disk(document) do
        :ok ->
          Logger.info("Final save completed for #{document.id}")

        {:error, reason} ->
          Logger.error("Final save failed for #{document.id}: #{inspect(reason)}")
      end
    end

    :ok
  end

  # Private functions

  defp via_tuple(document_id) do
    {:via, Registry, {Markdoc.DocumentRegistry, document_id}}
  end

  defp schedule_auto_save do
    Process.send_after(self(), :auto_save, @auto_save_interval)
  end

  defp schedule_inactivity_check do
    Process.send_after(self(), :inactivity_check, @inactive_shutdown_time)
  end

  defp save_to_disk(document) do
    FileStore.save_document(document.id, document.content)
  end

  defp reload_from_disk(document) do
    case FileStore.load_document(document.id) do
      {:ok, content} ->
        # Preserve user state but update content from disk
        fresh_document = %{
          document
          | content: content,
            dirty: false,
            last_saved: get_file_modified_time(document.id)
        }

        {:ok, fresh_document}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_file_modified_time(document_id) do
    case File.stat(FileStore.document_file_path(document_id)) do
      {:ok, %File.Stat{mtime: mtime}} ->
        # mtime is an Erlang datetime tuple, convert to DateTime
        mtime
        |> NaiveDateTime.from_erl!()
        |> DateTime.from_naive!("Etc/UTC")

      {:error, _} ->
        DateTime.utc_now()
    end
  end

  # Broadcasting functions (to be implemented with Phoenix PubSub)

  defp broadcast_user_joined(document, session_id) do
    Phoenix.PubSub.broadcast(
      Markdoc.PubSub,
      "document:#{document.id}",
      {:user_joined, session_id, document.users[session_id]}
    )
  end

  defp broadcast_user_left(document, session_id) do
    Phoenix.PubSub.broadcast(
      Markdoc.PubSub,
      "document:#{document.id}",
      {:user_left, session_id}
    )
  end

  # Content updates handled exclusively by Phoenix Channels - no PubSub broadcasts

  defp broadcast_cursor_updated(document, session_id) do
    case document.users[session_id] do
      nil ->
        # User no longer exists, skip broadcast
        :ok

      user_state ->
        Phoenix.PubSub.broadcast(
          Markdoc.PubSub,
          "document:#{document.id}",
          {:cursor_updated, session_id, user_state.cursor_position, user_state.selection}
        )
    end
  end

  defp broadcast_typing_updated(document, session_id, typing) do
    Phoenix.PubSub.broadcast(
      Markdoc.PubSub,
      "document:#{document.id}",
      {:typing_updated, session_id, typing}
    )
  end

  defp broadcast_save_status(document, status) do
    Phoenix.PubSub.broadcast(
      Markdoc.PubSub,
      "document:#{document.id}",
      {:save_status, status, document.last_saved}
    )
  end
end
