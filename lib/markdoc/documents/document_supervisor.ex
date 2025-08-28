defmodule Markdoc.Documents.DocumentSupervisor do
  @moduledoc """
  DynamicSupervisor for managing DocumentManager processes.

  Each active document gets its own DocumentManager process that is
  supervised by this DynamicSupervisor. Documents are started on-demand
  and automatically shut down when inactive.
  """

  use DynamicSupervisor

  alias Markdoc.Documents.DocumentManager

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a DocumentManager for the given document ID.
  """
  @spec start_document(binary()) :: DynamicSupervisor.on_start_child()
  def start_document(document_id) do
    child_spec = %{
      id: DocumentManager,
      start: {DocumentManager, :start_link, [document_id]},
      restart: :transient
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Stops a DocumentManager for the given document ID.
  """
  @spec stop_document(binary()) :: :ok | {:error, :not_found}
  def stop_document(document_id) do
    case Registry.lookup(Markdoc.DocumentRegistry, document_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all currently running document processes.
  """
  @spec list_documents() :: [binary()]
  def list_documents do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.keys(Markdoc.DocumentRegistry, pid) do
        [document_id] -> document_id
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @doc """
  Gets the count of currently running document processes.
  """
  @spec document_count() :: non_neg_integer()
  def document_count do
    DynamicSupervisor.count_children(__MODULE__).active
  end
end
