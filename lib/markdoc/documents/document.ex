defmodule Markdoc.Documents.Document do
  @moduledoc """
  Represents a markdown document with its metadata and user state.

  This is an in-memory struct (not a database schema) that holds
  the current state of a document being collaboratively edited.
  """

  @type user_state :: %{
          session_id: binary(),
          name: binary(),
          color: binary(),
          cursor_position: integer(),
          selection: %{start: integer(), end: integer()} | nil,
          last_activity: DateTime.t(),
          typing: boolean()
        }

  @type t :: %__MODULE__{
          id: binary(),
          content: binary(),
          users: %{binary() => user_state()},
          version: integer(),
          last_saved: DateTime.t(),
          dirty: boolean()
        }

  defstruct [
    :id,
    content: "# New Document\n\nStart writing...",
    users: %{},
    version: 0,
    last_saved: nil,
    dirty: false
  ]

  @doc """
  Creates a new document with the given ID.
  """
  @spec new(binary()) :: t()
  def new(id) do
    %__MODULE__{
      id: id,
      last_saved: DateTime.utc_now()
    }
  end

  @doc """
  Creates a new document with the given ID and content.
  """
  @spec new(binary(), binary()) :: t()
  def new(id, content) do
    %__MODULE__{
      id: id,
      content: content,
      last_saved: DateTime.utc_now()
    }
  end

  @doc """
  Adds a user to the document.
  """
  @spec add_user(t(), binary(), binary(), binary()) :: t()
  def add_user(%__MODULE__{} = doc, session_id, name, color) do
    user_state = %{
      session_id: session_id,
      name: name,
      color: color,
      cursor_position: 0,
      selection: nil,
      last_activity: DateTime.utc_now(),
      typing: false
    }

    %{doc | users: Map.put(doc.users, session_id, user_state)}
  end

  @doc """
  Removes a user from the document.
  """
  @spec remove_user(t(), binary()) :: t()
  def remove_user(%__MODULE__{} = doc, session_id) do
    %{doc | users: Map.delete(doc.users, session_id)}
  end

  @doc """
  Updates a user's cursor position.
  """
  @spec update_cursor(t(), binary(), integer(), map() | nil) :: t()
  def update_cursor(%__MODULE__{} = doc, session_id, position, selection \\ nil) do
    case Map.get(doc.users, session_id) do
      nil ->
        doc

      user_state ->
        updated_user = %{
          user_state
          | cursor_position: position,
            selection: selection,
            last_activity: DateTime.utc_now()
        }

        %{doc | users: Map.put(doc.users, session_id, updated_user)}
    end
  end

  @doc """
  Updates a user's typing status.
  """
  @spec update_typing(t(), binary(), boolean()) :: t()
  def update_typing(%__MODULE__{} = doc, session_id, typing) do
    case Map.get(doc.users, session_id) do
      nil ->
        doc

      user_state ->
        updated_user = %{user_state | typing: typing, last_activity: DateTime.utc_now()}
        %{doc | users: Map.put(doc.users, session_id, updated_user)}
    end
  end

  @doc """
  Updates the document content and marks it as dirty.
  """
  @spec update_content(t(), binary()) :: t()
  def update_content(%__MODULE__{} = doc, new_content) do
    %{doc | content: new_content, version: doc.version + 1, dirty: true}
  end

  @doc """
  Marks the document as saved (not dirty).
  """
  @spec mark_saved(t()) :: t()
  def mark_saved(%__MODULE__{} = doc) do
    %{doc | dirty: false, last_saved: DateTime.utc_now()}
  end

  @doc """
  Returns a list of active users (those who have been active recently).
  """
  @spec active_users(t(), integer()) :: [user_state()]
  def active_users(%__MODULE__{} = doc, minutes_threshold \\ 10) do
    cutoff = DateTime.add(DateTime.utc_now(), -minutes_threshold * 60, :second)

    doc.users
    |> Map.values()
    |> Enum.filter(fn user -> DateTime.compare(user.last_activity, cutoff) == :gt end)
  end

  @doc """
  Returns the document as a map suitable for JSON serialization.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = doc) do
    %{
      id: doc.id,
      content: doc.content,
      users: doc.users,
      version: doc.version,
      last_saved: doc.last_saved,
      dirty: doc.dirty
    }
  end
end
