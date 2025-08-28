defmodule Markdoc.Documents do
  @moduledoc """
  Context module for document operations.

  This module provides the public API for working with documents,
  abstracting away the internal GenServer and file storage details.
  """

  alias Markdoc.Documents.{Document, DocumentManager, DocumentSupervisor}
  alias Markdoc.Storage.FileStore

  @user_colors [
    # Coral Red
    "#FF6B6B",
    # Turquoise
    "#4ECDC4",
    # Sky Blue
    "#45B7D1",
    # Sage Green
    "#96CEB4",
    # Cream Yellow
    "#FFEAA7",
    # Plum Purple
    "#DDA0DD",
    # Mint Green
    "#98D8C8",
    # Golden Yellow
    "#F7DC6F"
  ]

  @doc """
  Creates a new document and returns its ID.
  """
  @spec create_document() :: binary()
  def create_document do
    document_id = generate_document_id()

    # Ensure storage directory exists
    FileStore.ensure_storage_directory()

    # Start the document manager (which will create the file)
    case DocumentSupervisor.start_document(document_id) do
      {:ok, _pid} ->
        document_id

      {:error, {:already_started, _pid}} ->
        document_id

      {:error, reason} ->
        raise "Failed to start document: #{inspect(reason)}"
    end
  end

  @doc """
  Gets a document by ID, starting the manager if needed.
  """
  @spec get_document(binary()) :: {:ok, Document.t()} | {:error, :not_found}
  def get_document(document_id) do
    # Validate document ID format
    if valid_document_id?(document_id) do
      case ensure_document_manager(document_id) do
        :ok ->
          document = DocumentManager.get_document(document_id)
          {:ok, document}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :invalid_document_id}
    end
  end

  @doc """
  Syncs a document from disk explicitly.
  """
  @spec sync_document_from_disk(binary()) :: {:ok, Document.t()} | {:error, term()}
  def sync_document_from_disk(document_id) do
    if valid_document_id?(document_id) do
      case ensure_document_manager(document_id) do
        :ok ->
          document = DocumentManager.sync_from_disk(document_id)
          {:ok, document}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :invalid_document_id}
    end
  end

  @doc """
  Joins a user to a document.
  """
  @spec join_document(binary(), binary()) :: {:ok, Document.t(), binary()} | {:error, term()}
  def join_document(document_id, user_name) do
    join_document(document_id, user_name, nil)
  end

  @spec join_document(binary(), binary(), binary() | nil) ::
          {:ok, Document.t(), binary()} | {:error, term()}
  def join_document(document_id, user_name, existing_session_id) do
    with :ok <- ensure_document_manager(document_id) do
      session_id = existing_session_id || generate_session_id()
      color = assign_user_color(document_id)

      :ok = DocumentManager.add_user(document_id, session_id, user_name, color)
      document = DocumentManager.get_document(document_id)

      {:ok, document, session_id}
    end
  end

  @doc """
  Removes a user from a document.
  """
  @spec leave_document(binary(), binary()) :: :ok
  def leave_document(document_id, session_id) do
    if DocumentManager.running?(document_id) do
      DocumentManager.remove_user(document_id, session_id)
    end

    :ok
  end

  @doc """
  Updates a document's content.
  """
  @spec update_document_content(binary(), binary()) :: :ok | {:error, term()}
  def update_document_content(document_id, new_content) do
    if DocumentManager.running?(document_id) do
      DocumentManager.update_content(document_id, new_content)
    else
      {:error, :document_not_active}
    end
  end

  @doc """
  Updates a user's cursor position.
  """
  @spec update_cursor_position(binary(), binary(), integer(), map() | nil) :: :ok
  def update_cursor_position(document_id, session_id, position, selection \\ nil) do
    if DocumentManager.running?(document_id) do
      DocumentManager.update_cursor(document_id, session_id, position, selection)
    end

    :ok
  end

  @doc """
  Updates a user's typing status.
  """
  @spec update_typing_status(binary(), binary(), boolean()) :: :ok
  def update_typing_status(document_id, session_id, typing) do
    if DocumentManager.running?(document_id) do
      DocumentManager.update_typing(document_id, session_id, typing)
    end

    :ok
  end

  @doc """
  Forces an immediate save of a document.
  """
  @spec save_document(binary()) :: :ok | {:error, term()}
  def save_document(document_id) do
    if DocumentManager.running?(document_id) do
      DocumentManager.save_now(document_id)
    else
      {:error, :document_not_active}
    end
  end

  @doc """
  Checks if a document exists (either in memory or on disk).
  """
  @spec document_exists?(binary()) :: boolean()
  def document_exists?(document_id) do
    DocumentManager.running?(document_id) or FileStore.document_exists?(document_id)
  end

  @doc """
  Lists all documents in the system.
  """
  @spec list_documents() :: {:ok, [binary()]} | {:error, term()}
  def list_documents do
    FileStore.list_documents()
  end

  @doc """
  Gets statistics about the document system.
  """
  @spec get_stats() :: map()
  def get_stats do
    %{
      active_documents: DocumentSupervisor.document_count(),
      total_documents:
        case list_documents() do
          {:ok, docs} -> length(docs)
          _ -> 0
        end
    }
  end

  # Private functions

  defp generate_document_id do
    UUID.uuid4()
  end

  defp generate_session_id do
    UUID.uuid4()
  end

  defp valid_document_id?(document_id) do
    # Basic UUID format validation
    String.match?(
      document_id,
      ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    )
  end

  defp ensure_document_manager(document_id) do
    if DocumentManager.running?(document_id) do
      :ok
    else
      # Check if document exists on disk
      if FileStore.document_exists?(document_id) do
        case DocumentSupervisor.start_document(document_id) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> {:error, reason}
        end
      else
        {:error, :not_found}
      end
    end
  end

  defp assign_user_color(document_id) do
    if DocumentManager.running?(document_id) do
      document = DocumentManager.get_document(document_id)

      used_colors =
        document.users
        |> Map.values()
        |> Enum.map(& &1.color)

      @user_colors
      |> Enum.find(&(&1 not in used_colors))
      |> case do
        # All colors taken, pick random
        nil -> Enum.random(@user_colors)
        color -> color
      end
    else
      # Document not running, pick first color
      List.first(@user_colors)
    end
  end
end
