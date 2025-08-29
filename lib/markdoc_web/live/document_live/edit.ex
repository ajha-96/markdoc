defmodule MarkdocWeb.DocumentLive.Edit do
  @moduledoc """
  Main document editing LiveView.

  This is where the collaborative markdown editing happens with:
  - Real-time text synchronization
  - User presence and cursor tracking
  - Auto-save status indicators
  - Live markdown preview (future)
  """

  use MarkdocWeb, :live_view

  alias Markdoc.Documents
  alias Phoenix.PubSub

  def mount(%{"id" => document_id} = params, _session, socket) do
    user_name = Map.get(params, "user_name")
    session_id = Map.get(params, "session_id")

    # Redirect to landing page if no user session
    if is_nil(user_name) or is_nil(session_id) do
      {:ok, push_navigate(socket, to: ~p"/documents/#{document_id}")}
    else
      # Subscribe to document updates
      PubSub.subscribe(Markdoc.PubSub, "document:#{document_id}")

      # Get or start the document
      case Documents.get_document(document_id) do
        {:ok, document} ->
          # User might already be in the document from previous session
          socket =
            assign(socket,
              document_id: document_id,
              document: document,
              user_name: user_name,
              session_id: session_id,
              page_title: "Editing Document",
              save_status: "saved",
              last_saved: document.last_saved,
              show_share_modal: false,
              share_url: url(socket, ~p"/documents/#{document_id}"),
              # "editor", "split", "preview"
              preview_mode: "editor",
              markdown_html: render_markdown(document.content)
            )

          {:ok, socket}

        {:error, _reason} ->
          socket =
            socket
            |> put_flash(:error, "Document not found or failed to load")
            |> push_navigate(to: ~p"/")

          {:ok, socket}
      end
    end
  end

  # Removed cursor/typing events - Phoenix Channels handle all user interactions

  def handle_event("show_share_modal", _params, socket) do
    {:noreply, assign(socket, show_share_modal: true)}
  end

  def handle_event("hide_share_modal", _params, socket) do
    {:noreply, assign(socket, show_share_modal: false)}
  end

  def handle_event("copy_share_url", _params, socket) do
    # The actual copying happens in JavaScript
    socket = put_flash(socket, :info, "Share link copied to clipboard!")
    {:noreply, socket}
  end

  def handle_event("save_now", _params, socket) do
    document_id = socket.assigns.document_id

    case Documents.save_document(document_id) do
      :ok ->
        socket =
          socket
          |> assign(save_status: "saved", last_saved: DateTime.utc_now())
          |> put_flash(:info, "Document saved successfully")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(save_status: "error")
          |> put_flash(:error, "Failed to save: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def handle_event("toggle_preview", %{"mode" => mode}, socket) do
    # Update markdown HTML when switching to preview modes
    markdown_html =
      if mode in ["split", "preview"] do
        render_markdown(socket.assigns.document.content)
      else
        socket.assigns.markdown_html
      end

    socket =
      socket
      |> assign(preview_mode: mode)
      |> assign(markdown_html: markdown_html)

    {:noreply, socket}
  end

  # Handle PubSub messages
  # Note: Content updates are handled exclusively by Phoenix Channels
  # LiveView only handles UI-specific events (user presence, save status, etc.)

  def handle_info({:user_joined, session_id, user}, socket) do
    # Add user to document state
    document = socket.assigns.document
    updated_users = Map.put(document.users, session_id, user)
    document = %{document | users: updated_users}

    socket = assign(socket, document: document)

    # Notify client
    {:noreply,
     push_event(socket, "user_joined", %{
       session_id: session_id,
       user: user
     })}
  end

  def handle_info({:user_left, session_id}, socket) do
    # Remove user from document state
    document = socket.assigns.document
    updated_users = Map.delete(document.users, session_id)
    document = %{document | users: updated_users}

    socket = assign(socket, document: document)

    # Notify client
    {:noreply, push_event(socket, "user_left", %{session_id: session_id})}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{event: "user_left", payload: %{session_id: session_id}},
        socket
      ) do
    # Handle PubSub broadcast format
    handle_info({:user_left, session_id}, socket)
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "user_joined",
          payload: %{session_id: session_id, user: user}
        },
        socket
      ) do
    # Handle PubSub broadcast format for user joined
    handle_info({:user_joined, session_id, user}, socket)
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "typing_status",
          payload: %{session_id: session_id, typing: typing}
        },
        socket
      ) do
    # Handle PubSub broadcast format for typing status
    handle_info({:typing_updated, session_id, typing}, socket)
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "cursor_update",
          payload: %{session_id: session_id, position: position, selection: selection}
        },
        socket
      ) do
    # Handle PubSub broadcast format for cursor updates
    handle_info({:cursor_updated, session_id, position, selection}, socket)
  end

  # Removed content_updated handler - Phoenix Channels handle all text synchronization

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "save_status",
          payload: %{status: status, timestamp: timestamp}
        },
        socket
      ) do
    # Handle PubSub broadcast format for save status
    handle_info({:save_status, status, timestamp}, socket)
  end

  # Removed text_operation handler - Phoenix Channels handle all text synchronization exclusively

  def handle_info({:cursor_updated, session_id, position, selection}, socket) do
    # Update user cursor position
    document = socket.assigns.document

    case Map.get(document.users, session_id) do
      nil ->
        {:noreply, socket}

      user_state ->
        updated_user = %{user_state | cursor_position: position, selection: selection}
        updated_users = Map.put(document.users, session_id, updated_user)
        document = %{document | users: updated_users}

        socket = assign(socket, document: document)

        # Push cursor update to client
        {:noreply,
         push_event(socket, "cursor_updated", %{
           session_id: session_id,
           position: position,
           selection: selection,
           user: updated_user
         })}
    end
  end

  def handle_info({:typing_updated, session_id, typing}, socket) do
    # Update user typing status
    document = socket.assigns.document

    case Map.get(document.users, session_id) do
      nil ->
        {:noreply, socket}

      user_state ->
        updated_user = %{user_state | typing: typing}
        updated_users = Map.put(document.users, session_id, updated_user)
        document = %{document | users: updated_users}

        socket = assign(socket, document: document)

        # Push typing update to client
        {:noreply,
         push_event(socket, "typing_updated", %{
           session_id: session_id,
           typing: typing,
           user: updated_user
         })}
    end
  end

  def handle_info({:save_status, status, last_saved}, socket) do
    socket = assign(socket, save_status: status, last_saved: last_saved)
    {:noreply, socket}
  end

  # When user leaves the page
  def terminate(_reason, socket) do
    if socket.assigns[:document_id] && socket.assigns[:session_id] do
      Documents.leave_document(socket.assigns.document_id, socket.assigns.session_id)
    end
  end

  # Helper function for relative time display
  defp relative_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "just now"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
      _ -> "#{div(DateTime.diff(DateTime.utc_now(), datetime, :second), 86400)}d ago"
    end
  end

  # Helper function for markdown rendering
  defp render_markdown(content) do
    case Earmark.as_html(content) do
      {:ok, html, _} -> html
      {:error, _html, _errors} -> "<p>Error rendering markdown</p>"
    end
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-white">
      <!-- Header -->
      <header class="bg-white border-b border-gray-200 px-6 py-4 flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <h1 class="text-xl font-semibold text-gray-900">Document</h1>

    <!-- Save Status -->
          <div class="flex items-center space-x-2">
            <%= case @save_status do %>
              <% "saving" -> %>
                <div class="flex items-center text-yellow-600">
                  <svg
                    class="animate-spin h-4 w-4 mr-2"
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
                  <span class="text-sm">Saving...</span>
                </div>
              <% "saved" -> %>
                <div class="flex items-center text-green-600">
                  <.icon name="hero-check-circle" class="h-4 w-4 mr-2" />
                  <span class="text-sm">
                    All changes saved
                    <%= if @last_saved do %>
                      at {Calendar.strftime(@last_saved, "%H:%M")}
                    <% end %>
                  </span>
                </div>
              <% "error" -> %>
                <div class="flex items-center text-red-600">
                  <.icon name="hero-exclamation-triangle" class="h-4 w-4 mr-2" />
                  <span class="text-sm">Save error</span>
                </div>
            <% end %>
          </div>
        </div>

        <div class="flex items-center space-x-4">
          <!-- Active Users -->
          <div class="flex items-center space-x-3">
            <%= for {_session_id, user} <- @document.users do %>
              <div
                class={"group user-presence-indicator flex items-center space-x-2 px-3 py-2 rounded-xl text-xs font-medium transition-all duration-200 hover:scale-105 cursor-pointer relative #{if user.typing, do: "typing", else: ""}"}
                style={"background-color: #{user.color}15; color: #{user.color}; border: 1px solid #{user.color}30"}
                title={"#{user.name} • Last active: #{relative_time(user.last_activity)}"}
              >
                <!-- User Avatar -->
                <div class="relative">
                  <div
                    class="w-3 h-3 rounded-full ring-2 ring-white shadow-sm transition-transform group-hover:scale-110"
                    style={"background-color: #{user.color}"}
                  >
                  </div>
                  <%= if user.typing do %>
                    <div class="absolute -top-1 -right-1 w-2 h-2 bg-green-400 rounded-full animate-pulse ring-1 ring-white">
                    </div>
                  <% end %>
                </div>

    <!-- User Name -->
                <span class="font-medium select-none">{user.name}</span>

    <!-- Typing Indicator -->
                <%= if user.typing do %>
                  <div class="flex items-center space-x-0.5">
                    <div
                      class="w-1 h-1 bg-current rounded-full animate-bounce"
                      style="animation-delay: 0ms;"
                    >
                    </div>
                    <div
                      class="w-1 h-1 bg-current rounded-full animate-bounce"
                      style="animation-delay: 150ms;"
                    >
                    </div>
                    <div
                      class="w-1 h-1 bg-current rounded-full animate-bounce"
                      style="animation-delay: 300ms;"
                    >
                    </div>
                  </div>
                <% else %>
                  <div class="w-2 h-2 rounded-full bg-green-400 opacity-75"></div>
                <% end %>

    <!-- Hover Tooltip Enhancement -->
                <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-2 py-1 bg-gray-800 text-white text-xs rounded opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-50">
                  <div class="flex items-center space-x-2">
                    <div class="w-2 h-2 rounded-full" style={"background-color: #{user.color}"}></div>
                    <span>{user.name}</span>
                    <%= if user.typing do %>
                      <span class="text-green-400">typing...</span>
                    <% else %>
                      <span class="text-gray-400">online</span>
                    <% end %>
                  </div>
                  <div class="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-2 border-r-2 border-t-2 border-transparent border-t-gray-800">
                  </div>
                </div>
              </div>
            <% end %>

    <!-- Users Count (if more than 3) -->
            <%= if length(Map.keys(@document.users)) > 3 do %>
              <div class="px-2 py-1 bg-gray-100 text-gray-600 rounded-lg text-xs font-medium">
                +{length(Map.keys(@document.users)) - 3} more
              </div>
            <% end %>
          </div>

    <!-- Preview Mode Toggle -->
          <div class="flex items-center bg-gray-100 rounded-lg p-1">
            <button
              phx-click="toggle_preview"
              phx-value-mode="editor"
              class={"px-3 py-1 text-sm rounded-md transition-colors duration-200 #{if @preview_mode == "editor", do: "bg-white text-gray-900 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              <.icon name="hero-pencil-square" class="w-4 h-4 inline mr-1" /> Edit
            </button>

            <button
              phx-click="toggle_preview"
              phx-value-mode="split"
              class={"px-3 py-1 text-sm rounded-md transition-colors duration-200 #{if @preview_mode == "split", do: "bg-white text-gray-900 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              <.icon name="hero-squares-2x2" class="w-4 h-4 inline mr-1" /> Split
            </button>

            <button
              phx-click="toggle_preview"
              phx-value-mode="preview"
              class={"px-3 py-1 text-sm rounded-md transition-colors duration-200 #{if @preview_mode == "preview", do: "bg-white text-gray-900 shadow-sm", else: "text-gray-600 hover:text-gray-900"}"}
            >
              <.icon name="hero-eye" class="w-4 h-4 inline mr-1" /> Preview
            </button>
          </div>

    <!-- Action Buttons -->
          <button
            phx-click="save_now"
            class="px-3 py-1 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700"
            title="Save Now (Ctrl+S)"
          >
            Save
          </button>

          <button
            phx-click="show_share_modal"
            class="px-3 py-1 bg-green-600 text-white text-sm rounded-md hover:bg-green-700"
          >
            Share
          </button>
        </div>
      </header>

    <!-- Main Content Area -->
      <div class="flex-1 flex">
        <%= cond do %>
          <% @preview_mode == "editor" -> %>
            <!-- Editor Only Mode -->
            <div class="flex-1 relative">
              <textarea
                id="editor"
                name="content"
                phx-hook="CollaborativeDocumentEditor"
                data-document-id={@document_id}
                data-user-id={@session_id}
                data-user-name={@user_name}
                class="w-full h-full p-6 text-gray-900 resize-none focus:outline-none font-mono text-sm leading-relaxed"
                placeholder="Start writing your markdown here..."
                spellcheck="false"
              ><%= @document.content %></textarea>

    <!-- Cursor Overlays (will be managed by JavaScript) -->
              <div id="cursor-overlays" class="absolute inset-0 pointer-events-none"></div>
            </div>
          <% @preview_mode == "split" -> %>
            <!-- Split Pane Mode -->
            <!-- Editor Pane -->
            <div class="flex-1 relative border-r border-gray-200">
              <div class="absolute top-0 left-0 w-full bg-gray-50 border-b border-gray-200 px-4 py-2 text-xs font-medium text-gray-700 uppercase tracking-wider">
                Markdown Editor
              </div>
              <textarea
                id="editor"
                name="content"
                phx-hook="CollaborativeDocumentEditor"
                data-document-id={@document_id}
                data-user-id={@session_id}
                data-user-name={@user_name}
                class="w-full h-full pt-10 p-6 text-gray-900 resize-none focus:outline-none font-mono text-sm leading-relaxed"
                placeholder="Start writing your markdown here..."
                spellcheck="false"
              ><%= @document.content %></textarea>

    <!-- Cursor Overlays (will be managed by JavaScript) -->
              <div id="cursor-overlays" class="absolute inset-0 mt-10 pointer-events-none"></div>
            </div>

    <!-- Preview Pane -->
            <div class="flex-1 relative bg-gray-50">
              <div class="absolute top-0 left-0 w-full bg-gray-100 border-b border-gray-200 px-4 py-2 text-xs font-medium text-gray-700 uppercase tracking-wider">
                Live Preview
              </div>
              <div class="h-full pt-10 p-6 overflow-y-auto">
                <div class="markdown-preview prose prose-slate max-w-none">
                  {raw(@markdown_html)}
                </div>
              </div>
            </div>
          <% @preview_mode == "preview" -> %>
            <!-- Preview Only Mode -->
            <div class="flex-1 relative bg-gray-50">
              <div class="h-full p-6 overflow-y-auto">
                <div class="markdown-preview prose prose-slate max-w-none mx-auto">
                  {raw(@markdown_html)}
                </div>
              </div>
            </div>
        <% end %>
      </div>

    <!-- Share Modal -->
      <%= if @show_share_modal do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50">
          <div class="bg-white rounded-lg shadow-xl p-6 max-w-md w-full">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Share Document</h3>
            <p class="text-gray-600 mb-4">Anyone with this link can join the document:</p>

            <div class="flex items-center space-x-2 mb-4">
              <input
                type="text"
                id="share-url"
                value={@share_url}
                readonly
                class="flex-1 px-3 py-2 border border-gray-300 rounded-md bg-gray-50 text-sm"
              />
              <button
                id="copy-button"
                phx-click="copy_share_url"
                phx-hook="CopyToClipboard"
                data-target="#share-url"
                class="px-3 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 text-sm"
              >
                Copy
              </button>
            </div>

            <div class="flex justify-end space-x-2">
              <button
                phx-click="hide_share_modal"
                class="px-4 py-2 text-gray-600 hover:text-gray-800"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
