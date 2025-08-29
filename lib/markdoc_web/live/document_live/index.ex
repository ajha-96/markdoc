defmodule MarkdocWeb.DocumentLive.Index do
  @moduledoc """
  Landing page LiveView for creating and joining documents.

  Users can:
  - Enter their name and create a new document
  - Enter their name and join an existing document via URL
  """

  use MarkdocWeb, :live_view

  alias Markdoc.Documents

  def mount(_params, _session, socket) do
    {:ok, assign(socket, user_name: "", creating: false, error_message: nil)}
  end

  def handle_params(%{"id" => document_id}, _url, socket) do
    # User is trying to join an existing document
    socket =
      assign(socket,
        document_id: document_id,
        page_title: "Join Document",
        mode: :join
      )

    # Check if document exists
    if Documents.document_exists?(document_id) do
      {:noreply, socket}
    else
      socket =
        assign(socket,
          error_message:
            "Document not found. The document may have been deleted or the link is invalid."
        )

      {:noreply, socket}
    end
  end

  def handle_params(_params, _url, socket) do
    # User is on the landing page to create a new document
    socket =
      assign(socket,
        document_id: nil,
        page_title: "Markdoc - Collaborative Markdown Editor",
        mode: :create
      )

    {:noreply, socket}
  end

  def handle_event("validate", %{"user_name" => user_name}, socket) do
    {:noreply, assign(socket, user_name: String.trim(user_name), error_message: nil)}
  end

  def handle_event("create_document", %{"user_name" => user_name}, socket) do
    user_name = String.trim(user_name)

    if valid_user_name?(user_name) do
      # Create new document
      document_id = Documents.create_document()

      socket = assign(socket, creating: true)

      # Join the document
      case Documents.join_document(document_id, user_name) do
        {:ok, _document, session_id} ->
          socket =
            socket
            |> push_navigate(
              to:
                ~p"/documents/#{document_id}/edit?session_id=#{session_id}&user_name=#{URI.encode(user_name)}"
            )

          {:noreply, socket}

        {:error, reason} ->
          socket =
            assign(socket,
              creating: false,
              error_message: "Failed to create document: #{inspect(reason)}"
            )

          {:noreply, socket}
      end
    else
      socket = assign(socket, error_message: "Please enter a valid name (2-50 characters)")
      {:noreply, socket}
    end
  end

  def handle_event("join_document", %{"user_name" => user_name}, socket) do
    user_name = String.trim(user_name)
    document_id = socket.assigns.document_id

    if valid_user_name?(user_name) do
      case Documents.join_document(document_id, user_name) do
        {:ok, _document, session_id} ->
          socket =
            socket
            |> push_navigate(
              to:
                ~p"/documents/#{document_id}/edit?session_id=#{session_id}&user_name=#{URI.encode(user_name)}"
            )

          {:noreply, socket}

        {:error, reason} ->
          socket =
            assign(socket,
              error_message: "Failed to join document: #{inspect(reason)}"
            )

          {:noreply, socket}
      end
    else
      socket = assign(socket, error_message: "Please enter a valid name (2-50 characters)")
      {:noreply, socket}
    end
  end

  defp valid_user_name?(name) do
    String.length(name) >= 2 and String.length(name) <= 50
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center p-4">
      <div class="max-w-md w-full">
        <!-- Logo and Title -->
        <div class="text-center mb-8">
          <h1 class="text-4xl font-bold text-gray-900 mb-2">Markdoc</h1>
          <p class="text-gray-600">Collaborative Markdown Editor</p>
          <p class="text-sm text-gray-500 mt-2">Write together in real-time</p>
        </div>

    <!-- Main Card -->
        <div class="bg-white rounded-lg shadow-lg p-6">
          <%= if @mode == :create do %>
            <h2 class="text-2xl font-semibold text-gray-900 mb-4">Start Writing</h2>
            <p class="text-gray-600 mb-6">
              Enter your name to create a new document and get a shareable link.
            </p>
          <% else %>
            <h2 class="text-2xl font-semibold text-gray-900 mb-4">Join Document</h2>
            <p class="text-gray-600 mb-6">Enter your name to join this collaborative document.</p>
          <% end %>

    <!-- Error Message -->
          <%= if @error_message do %>
            <div class="mb-4 p-3 bg-red-50 border border-red-200 rounded-md">
              <p class="text-sm text-red-600">{@error_message}</p>
            </div>
          <% end %>

    <!-- Form -->
          <.form
            for={%{}}
            as={:user}
            phx-change="validate"
            phx-submit={if @mode == :create, do: "create_document", else: "join_document"}
            class="space-y-4"
          >
            <div>
              <label for="user_name" class="block text-sm font-medium text-gray-700 mb-2">
                Your Name
              </label>
              <input
                type="text"
                name="user_name"
                id="user_name"
                value={@user_name}
                placeholder="Enter your name..."
                class="w-full text-gray-900 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                maxlength="50"
                required
              />
            </div>

            <button
              type="submit"
              disabled={@creating or String.length(@user_name) < 2}
              class="w-full bg-blue-600 text-white py-2 px-4 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:bg-gray-300 disabled:cursor-not-allowed transition-colors"
            >
              <%= if @creating do %>
                <div class="flex items-center justify-center">
                  <svg
                    class="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
                    xmlns="http://www.w3.org/2000/svg"
                    fill="none"
                    viewBox="0 0 24 24"
                  >
                    <circle
                      class="opacity-25"
                      cx="12"
                      cy="12"
                      r="10"
                      stroke="currentColor"
                      stroke-width="4"
                    >
                    </circle>
                    <path
                      class="opacity-75"
                      fill="currentColor"
                      d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                    >
                    </path>
                  </svg>
                  Creating...
                </div>
              <% else %>
                {if @mode == :create, do: "Create New Document", else: "Join Document"}
              <% end %>
            </button>
          </.form>

    <!-- Additional Info -->
          <div class="mt-6 pt-6 border-t border-gray-200">
            <%= if @mode == :create do %>
              <div class="text-sm text-gray-500 space-y-2">
                <p class="flex items-center">
                  <.icon name="hero-users" class="w-4 h-4 mr-2" />
                  Share the link with others to collaborate
                </p>
                <p class="flex items-center">
                  <.icon name="hero-pencil" class="w-4 h-4 mr-2" />
                  Real-time editing with live cursors
                </p>
                <p class="flex items-center">
                  <.icon name="hero-cloud-arrow-down" class="w-4 h-4 mr-2" />
                  Auto-save every 10 seconds
                </p>
              </div>
            <% else %>
              <div class="text-sm text-gray-500">
                <p>You'll be able to see other users' cursors and edits in real-time.</p>
              </div>
            <% end %>
          </div>
        </div>

    <!-- Footer -->
        <div class="text-center mt-8 text-sm text-gray-500">
          <p>No accounts required • No data tracking • Just write</p>
        </div>
      </div>
    </div>
    """
  end
end
