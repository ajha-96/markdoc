defmodule Markdoc.Storage.FileStore do
  @moduledoc """
  Handles file system operations for markdown documents.

  Documents are stored as individual markdown files in the structure:
  storage/docs/{document_id}/document.md
  """

  require Logger

  @storage_path Application.compile_env(:markdoc, :storage_path, "storage/docs")

  @doc """
  Creates a new document file with the given ID and initial content.
  """
  @spec create_document(binary(), binary()) :: :ok | {:error, term()}
  def create_document(document_id, initial_content \\ "# New Document\n\nStart writing...") do
    document_dir = document_directory(document_id)
    document_path = document_file_path(document_id)

    with :ok <- File.mkdir_p(document_dir),
         :ok <- File.write(document_path, initial_content) do
      Logger.info("Created new document: #{document_id}")
      :ok
    else
      {:error, reason} = error ->
        Logger.error("Failed to create document #{document_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Loads a document's content from the file system.
  """
  @spec load_document(binary()) :: {:ok, binary()} | {:error, :not_found} | {:error, term()}
  def load_document(document_id) do
    document_path = document_file_path(document_id)

    case File.read(document_path) do
      {:ok, content} ->
        Logger.debug("Loaded document: #{document_id}")
        {:ok, content}

      {:error, :enoent} ->
        Logger.debug("Document not found: #{document_id}")
        {:error, :not_found}

      {:error, reason} = error ->
        Logger.error("Failed to load document #{document_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Saves a document's content to the file system.
  """
  @spec save_document(binary(), binary()) :: :ok | {:error, term()}
  def save_document(document_id, content) do
    document_path = document_file_path(document_id)

    case File.write(document_path, content) do
      :ok ->
        Logger.debug("Saved document: #{document_id}")
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to save document #{document_id}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Checks if a document exists on the file system.
  """
  @spec document_exists?(binary()) :: boolean()
  def document_exists?(document_id) do
    document_id
    |> document_file_path()
    |> File.exists?()
  end

  @doc """
  Deletes a document and its directory from the file system.
  """
  @spec delete_document(binary()) :: :ok | {:error, term()}
  def delete_document(document_id) do
    document_dir = document_directory(document_id)

    case File.rm_rf(document_dir) do
      {:ok, _files_and_dirs} ->
        Logger.info("Deleted document: #{document_id}")
        :ok

      {:error, reason, _path} ->
        Logger.error("Failed to delete document #{document_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Lists all document IDs in the storage directory.
  """
  @spec list_documents() :: {:ok, [binary()]} | {:error, term()}
  def list_documents do
    case File.ls(@storage_path) do
      {:ok, dirs} ->
        document_ids =
          dirs
          |> Enum.filter(fn dir ->
            File.dir?(Path.join(@storage_path, dir)) and
              File.exists?(Path.join([@storage_path, dir, "document.md"]))
          end)

        {:ok, document_ids}

      {:error, reason} = error ->
        Logger.error("Failed to list documents: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Gets file information for a document.
  """
  @spec document_info(binary()) :: {:ok, File.Stat.t()} | {:error, term()}
  def document_info(document_id) do
    document_path = document_file_path(document_id)
    File.stat(document_path)
  end

  @doc """
  Ensures the storage directory exists.
  """
  @spec ensure_storage_directory() :: :ok | {:error, term()}
  def ensure_storage_directory do
    case File.mkdir_p(@storage_path) do
      :ok ->
        Logger.info("Storage directory ready: #{@storage_path}")
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to create storage directory: #{inspect(reason)}")
        error
    end
  end

  # Private functions

  defp document_directory(document_id) do
    Path.join(@storage_path, document_id)
  end

  @doc """
  Gets the file path for a document's markdown file.
  """
  @spec document_file_path(binary()) :: Path.t()
  def document_file_path(document_id) do
    Path.join([document_directory(document_id), "document.md"])
  end

  @doc """
  Gets the configured storage path.
  """
  @spec storage_path() :: binary()
  def storage_path, do: @storage_path
end
