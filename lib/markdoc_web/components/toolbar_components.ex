defmodule MarkdocWeb.ToolbarComponents do
  @moduledoc """
  Toolbar components for markdown editing interface.
  
  Provides reusable toolbar buttons and formatting controls for the markdown editor.
  """
  
  use Phoenix.Component
  
  import MarkdocWeb.CoreComponents, only: [icon: 1]
  
  @doc """
  Renders a markdown formatting toolbar with common formatting options.
  
  ## Examples
  
      <.markdown_toolbar target_id="editor" />
  """
  attr :target_id, :string, required: true, doc: "ID of the textarea element to target"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  
  def markdown_toolbar(assigns) do
    ~H"""
    <div class={[
      "markdown-toolbar flex flex-wrap items-center gap-1 p-2 bg-gray-50 border border-gray-200 rounded-t-lg",
      @class
    ]}>
      <!-- Text Formatting Group -->
      <div class="flex items-center gap-1 mr-2">
        <.toolbar_button
          icon="hero-bold"
          title="Bold (Ctrl+B)"
          action="bold"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-italic"
          title="Italic (Ctrl+I)"
          action="italic"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-strikethrough"
          title="Strikethrough"
          action="strikethrough"
          target={@target_id}
        />
      </div>
      
      <!-- Separator -->
      <div class="w-px h-6 bg-gray-300 mr-2"></div>
      
      <!-- Lists Group -->
      <div class="flex items-center gap-1 mr-2">
        <.toolbar_button
          icon="hero-list-bullet"
          title="Bullet List"
          action="unordered_list"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-numbered-list"
          title="Numbered List"
          action="ordered_list"
          target={@target_id}
        />
      </div>
      
      <!-- Separator -->
      <div class="w-px h-6 bg-gray-300 mr-2"></div>
      
      <!-- Content Group -->
      <div class="flex items-center gap-1 mr-2">
        <.toolbar_button
          icon="hero-chat-bubble-left-ellipsis"
          title="Quote"
          action="blockquote"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-code-bracket"
          title="Code Block"
          action="code_block"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-table-cells"
          title="Insert Table"
          action="table"
          target={@target_id}
        />
      </div>
      
      <!-- Separator -->
      <div class="w-px h-6 bg-gray-300 mr-2"></div>
      
      <!-- Media Group -->
      <div class="flex items-center gap-1 mr-2">
        <.toolbar_button
          icon="hero-link"
          title="Insert Link (Ctrl+K)"
          action="link"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-photo"
          title="Insert Image"
          action="image"
          target={@target_id}
        />
      </div>
      
      <!-- Separator -->
      <div class="w-px h-6 bg-gray-300 mr-2"></div>
      
      <!-- Additional Tools -->
      <div class="flex items-center gap-1">
        <.toolbar_button
          icon="hero-minus"
          title="Horizontal Rule"
          action="horizontal_rule"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-arrow-uturn-left"
          title="Undo (Ctrl+Z)"
          action="undo"
          target={@target_id}
        />
        <.toolbar_button
          icon="hero-arrow-uturn-right"
          title="Redo (Ctrl+Y)"
          action="redo"
          target={@target_id}
        />
      </div>
    </div>
    """
  end
  
  @doc """
  Renders a single toolbar button.
  
  ## Examples
  
      <.toolbar_button icon="hero-bold" title="Bold" action="bold" target="editor" />
  """
  attr :icon, :string, required: true, doc: "Heroicon name"
  attr :title, :string, required: true, doc: "Button title/tooltip"
  attr :action, :string, required: true, doc: "Formatting action to perform"
  attr :target, :string, required: true, doc: "Target element ID"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  attr :disabled, :boolean, default: false, doc: "Whether button is disabled"
  
  def toolbar_button(assigns) do
    assigns = assign_new(assigns, :id, fn -> "toolbar-btn-#{assigns.action}-#{:rand.uniform(10000)}" end)
    
    ~H"""
    <button
      type="button"
      id={@id}
      class={[
        "toolbar-btn flex items-center justify-center w-8 h-8 rounded-md border border-transparent transition-all duration-150",
        "hover:bg-gray-200 hover:border-gray-300 active:bg-gray-300",
        "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1",
        "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent",
        @class
      ]}
      title={@title}
      data-action={@action}
      data-target={@target}
      disabled={@disabled}
      phx-hook="MarkdownToolbar"
    >
      <.icon name={@icon} class="w-4 h-4 text-gray-600" />
    </button>
    """
  end
  
  @doc """
  Renders a compact markdown toolbar for mobile/small screens.
  
  ## Examples
  
      <.compact_toolbar target_id="editor" />
  """
  attr :target_id, :string, required: true, doc: "ID of the textarea element to target"
  attr :class, :string, default: "", doc: "Additional CSS classes"
  
  def compact_toolbar(assigns) do
    ~H"""
    <div class={[
      "compact-markdown-toolbar flex items-center gap-2 p-2 bg-gray-50 border border-gray-200 rounded-t-lg md:hidden",
      @class
    ]}>
      <!-- Most essential tools only -->
      <.toolbar_button
        icon="hero-bold"
        title="Bold"
        action="bold"
        target={@target_id}
      />
      <.toolbar_button
        icon="hero-italic"
        title="Italic"
        action="italic"
        target={@target_id}
      />
      <.toolbar_button
        icon="hero-list-bullet"
        title="List"
        action="unordered_list"
        target={@target_id}
      />
      <.toolbar_button
        icon="hero-link"
        title="Link"
        action="link"
        target={@target_id}
      />
      
      <!-- Overflow menu button for additional tools -->
      <div class="relative ml-auto">
        <.toolbar_button
          icon="hero-ellipsis-horizontal"
          title="More options"
          action="toggle_menu"
          target={@target_id}
          class="more-options-btn"
        />
        
        <!-- Hidden overflow menu (will be shown via JS) -->
        <div class="absolute right-0 top-full mt-1 bg-white border border-gray-200 rounded-md shadow-lg p-1 z-50 hidden more-options-menu">
          <div class="flex flex-col gap-1">
            <.toolbar_button
              icon="hero-strikethrough"
              title="Strikethrough"
              action="strikethrough"
              target={@target_id}
              class="w-full justify-start px-3 py-2 text-sm"
            />
            <.toolbar_button
              icon="hero-numbered-list"
              title="Numbered List"
              action="ordered_list"
              target={@target_id}
              class="w-full justify-start px-3 py-2 text-sm"
            />
            <.toolbar_button
              icon="hero-chat-bubble-left-ellipsis"
              title="Quote"
              action="blockquote"
              target={@target_id}
              class="w-full justify-start px-3 py-2 text-sm"
            />
            <.toolbar_button
              icon="hero-code-bracket"
              title="Code"
              action="code_block"
              target={@target_id}
              class="w-full justify-start px-3 py-2 text-sm"
            />
            <.toolbar_button
              icon="hero-table-cells"
              title="Table"
              action="table"
              target={@target_id}
              class="w-full justify-start px-3 py-2 text-sm"
            />
            <.toolbar_button
              icon="hero-photo"
              title="Image"
              action="image"
              target={@target_id}
              class="w-full justify-start px-3 py-2 text-sm"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
  
  @doc """
  Renders toolbar for dark theme.
  
  ## Examples
  
      <.dark_toolbar target_id="editor" />
  """
  attr :target_id, :string, required: true
  attr :class, :string, default: ""
  
  def dark_toolbar(assigns) do
    assigns = assign(assigns, :class, [
      "bg-gray-800 border-gray-700",
      assigns.class
    ] |> Enum.join(" "))
    
    ~H"""
    <div class={[
      "markdown-toolbar flex flex-wrap items-center gap-1 p-2 rounded-t-lg",
      @class
    ]}>
      <!-- Same structure as light toolbar but with dark theme classes -->
      <div class="flex items-center gap-1 mr-2">
        <.dark_toolbar_button
          icon="hero-bold"
          title="Bold (Ctrl+B)"
          action="bold"
          target={@target_id}
        />
        <.dark_toolbar_button
          icon="hero-italic"
          title="Italic (Ctrl+I)"
          action="italic"
          target={@target_id}
        />
        <.dark_toolbar_button
          icon="hero-strikethrough"
          title="Strikethrough"
          action="strikethrough"
          target={@target_id}
        />
      </div>
      
      <div class="w-px h-6 bg-gray-600 mr-2"></div>
      
      <div class="flex items-center gap-1 mr-2">
        <.dark_toolbar_button
          icon="hero-list-bullet"
          title="Bullet List"
          action="unordered_list"
          target={@target_id}
        />
        <.dark_toolbar_button
          icon="hero-numbered-list"
          title="Numbered List"
          action="ordered_list"
          target={@target_id}
        />
      </div>
      
      <div class="w-px h-6 bg-gray-600 mr-2"></div>
      
      <div class="flex items-center gap-1 mr-2">
        <.dark_toolbar_button
          icon="hero-chat-bubble-left-ellipsis"
          title="Quote"
          action="blockquote"
          target={@target_id}
        />
        <.dark_toolbar_button
          icon="hero-code-bracket"
          title="Code Block"
          action="code_block"
          target={@target_id}
        />
        <.dark_toolbar_button
          icon="hero-table-cells"
          title="Insert Table"
          action="table"
          target={@target_id}
        />
      </div>
      
      <div class="w-px h-6 bg-gray-600 mr-2"></div>
      
      <div class="flex items-center gap-1 mr-2">
        <.dark_toolbar_button
          icon="hero-link"
          title="Insert Link (Ctrl+K)"
          action="link"
          target={@target_id}
        />
        <.dark_toolbar_button
          icon="hero-photo"
          title="Insert Image"
          action="image"
          target={@target_id}
        />
      </div>
    </div>
    """
  end
  
  @doc """
  Dark theme toolbar button variant.
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :action, :string, required: true
  attr :target, :string, required: true
  attr :class, :string, default: ""
  attr :disabled, :boolean, default: false
  
  def dark_toolbar_button(assigns) do
    assigns = assign_new(assigns, :id, fn -> "toolbar-btn-dark-#{assigns.action}-#{:rand.uniform(10000)}" end)
    
    ~H"""
    <button
      type="button"
      id={@id}
      class={[
        "toolbar-btn flex items-center justify-center w-8 h-8 rounded-md border border-transparent transition-all duration-150",
        "hover:bg-gray-700 hover:border-gray-600 active:bg-gray-600",
        "focus:outline-none focus:ring-2 focus:ring-blue-400 focus:ring-offset-1 focus:ring-offset-gray-800",
        "disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:bg-transparent",
        @class
      ]}
      title={@title}
      data-action={@action}
      data-target={@target}
      disabled={@disabled}
      phx-hook="MarkdownToolbar"
    >
      <.icon name={@icon} class="w-4 h-4 text-gray-300" />
    </button>
    """
  end
end