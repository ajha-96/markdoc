# Technical Requirements

## Technology Stack

### Backend
- **Elixir** 1.15+
- **Phoenix Framework** 1.7+
- **Phoenix LiveView** for real-time UI updates
- **Phoenix PubSub** for message broadcasting
- **Phoenix Channels** for WebSocket connections
- **GenServer** processes for document management

### Frontend
- **Phoenix LiveView** with server-rendered HTML
- **Alpine.js** for client-side interactivity
- **JavaScript** for editor functionality and cursor tracking
- **CSS/Tailwind** for responsive styling

### Storage & Infrastructure
- **File System** for document persistence (no database required)
- **Local directory structure** under `docs/` folder
- **Elixir File module** for I/O operations

## System Requirements

### Performance Specifications
- **Real-time Updates**: < 100ms latency for text synchronization
- **Concurrent Users**: Support 10+ users per document
- **Auto-save Interval**: 10 seconds (configurable)
- **Memory Usage**: < 50MB per active document process
- **File I/O**: Async writes to prevent blocking

### Scalability Targets
- **Documents**: Handle 1000+ concurrent documents
- **Users**: Support 100+ simultaneous connections
- **Document Size**: Up to 1MB markdown files
- **Storage**: Unlimited documents (disk space permitting)

## Core Components

### 1. DocumentManager (GenServer)
```elixir
defmodule Markdoc.Documents.DocumentManager do
  use GenServer
  
  @auto_save_interval 10_000  # 10 seconds
  
  # State management
  # - Document content
  # - Active users
  # - Cursor positions
  # - Auto-save timer
  
  # Operations
  # - Text insertions/deletions
  # - Cursor position updates  
  # - User presence tracking
  # - Periodic file flushing
end
```

**Responsibilities:**
- Maintain document state in memory
- Apply operational transforms
- Broadcast changes to users
- Periodic file persistence
- User session management

### 2. Phoenix LiveView Editor
```elixir
defmodule MarkdocWeb.DocumentLive.Edit do
  use MarkdocWeb, :live_view
  
  # Real-time document editing interface
  # - Text editor component
  # - User presence display
  # - Cursor position tracking
  # - Auto-save status
end
```

**Features:**
- Server-rendered markdown editor
- Real-time text synchronization
- Visual cursor overlays
- User presence indicators
- Save status display

### 3. Phoenix Channels for Low-Latency Updates
```elixir
defmodule MarkdocWeb.DocumentChannel do
  use Phoenix.Channel
  
  # Handle WebSocket events:
  # - "text_change" - content updates
  # - "cursor_move" - cursor position changes
  # - "user_typing" - typing indicators
end
```

**Event Types:**
- Text insertion/deletion operations
- Cursor position broadcasts
- User join/leave notifications
- Typing activity indicators

### 4. File Storage System
```elixir
defmodule Markdoc.Storage.FileStore do
  # Document file operations
  # - Create document directories
  # - Read/write markdown files
  # - Handle file system errors
  # - Ensure atomic writes
end
```

**File Structure:**
```
docs/
├── {document-uuid}/
│   └── document.md
├── {another-uuid}/
│   └── document.md
```

## Data Structures

### Document State
```elixir
%{
  id: binary(),                    # Document UUID
  content: binary(),               # Markdown content  
  users: %{session_id() => user_state()},
  version: integer(),              # Operation version
  last_saved: DateTime.t(),
  dirty: boolean()                 # Needs saving
}
```

### User State
```elixir
%{
  session_id: binary(),           # Unique session identifier
  name: binary(),                 # User display name
  color: binary(),                # Hex color code
  cursor_position: integer(),     # Character offset in document
  selection: selection() | nil,   # Text selection range
  last_activity: DateTime.t(),
  typing: boolean()
}
```

### Selection Range
```elixir
%{
  start: integer(),               # Selection start position
  end: integer()                  # Selection end position  
}
```

### Text Operations
```elixir
%{
  type: :insert | :delete | :retain,
  position: integer(),            # Character position
  content: binary(),              # Text content (for inserts)
  length: integer(),              # Length (for deletes)
  user_id: binary(),
  timestamp: DateTime.t()
}
```

## Real-time Synchronization

### Operational Transform Algorithm
```elixir
def transform_operation(op1, op2) do
  # Transform two concurrent operations
  # Ensure commutativity: transform(op1, op2) + op2 = transform(op2, op1) + op1
  case {op1.type, op2.type} do
    {:insert, :insert} -> handle_concurrent_inserts(op1, op2)
    {:insert, :delete} -> handle_insert_delete(op1, op2)
    {:delete, :insert} -> handle_delete_insert(op1, op2)
    {:delete, :delete} -> handle_concurrent_deletes(op1, op2)
  end
end
```

### Cursor Position Management
```elixir
def adjust_cursor_position(cursor_pos, operation) do
  case operation do
    %{type: :insert, position: pos, content: text} ->
      if cursor_pos > pos do
        cursor_pos + String.length(text)
      else
        cursor_pos
      end
    
    %{type: :delete, position: pos, length: len} ->
      cond do
        cursor_pos > pos + len -> cursor_pos - len
        cursor_pos > pos -> pos
        true -> cursor_pos
      end
  end
end
```

## User Interface Requirements

### Editor Component
- **Responsive textarea** with markdown syntax awareness
- **Real-time text synchronization** with conflict resolution
- **Cursor position tracking** via JavaScript selection API
- **Smooth scrolling** and viewport management

### Visual Indicators
```css
/* User cursor styles */
.user-cursor {
  position: absolute;
  width: 2px;
  background-color: var(--user-color);
  animation: blink 1s infinite;
}

/* Selection highlight */
.user-selection {
  background-color: var(--user-color);
  opacity: 0.3;
  border-radius: 2px;
}

/* User name label */
.user-label {
  position: absolute;
  background: var(--user-color);
  color: white;
  padding: 2px 6px;
  border-radius: 3px;
  font-size: 12px;
}
```

### User Colors
```elixir
@user_colors [
  "#FF6B6B",  # Coral Red
  "#4ECDC4",  # Turquoise  
  "#45B7D1",  # Sky Blue
  "#96CEB4",  # Sage Green
  "#FFEAA7",  # Cream Yellow
  "#DDA0DD",  # Plum Purple
  "#98D8C8",  # Mint Green
  "#F7DC6F"   # Golden Yellow
]
```

## Error Handling

### File System Errors
- **Disk full**: Graceful degradation, notify users
- **Permission errors**: Fallback to memory-only mode
- **Corruption**: Auto-recovery from last known good state

### Network Issues
- **Connection drops**: Automatic reconnection with state sync
- **Partial updates**: Conflict resolution and repair
- **High latency**: Optimistic updates with rollback capability

### Memory Management
- **Document cleanup**: Remove inactive documents from memory
- **User session expiry**: Clean up disconnected users
- **Resource limits**: Prevent memory exhaustion

## Security Considerations

### Input Validation
- **Sanitize user names**: Prevent XSS and injection
- **Limit document size**: Prevent storage exhaustion  
- **Rate limiting**: Prevent operation flooding
- **Content filtering**: Block malicious markdown

### Access Control
- **UUID-based access**: No authentication but secure sharing
- **Session validation**: Verify user sessions
- **Document ownership**: Basic access controls via URL knowledge

## Deployment Requirements

### System Dependencies
- **Elixir/OTP** 25+ with Phoenix framework
- **File system** with read/write permissions
- **Network** connectivity for WebSocket support

### Configuration
```elixir
config :markdoc, Markdoc.Documents,
  storage_path: "docs/",
  auto_save_interval: 10_000,
  max_document_size: 1_000_000,
  max_users_per_document: 50

config :markdoc, MarkdocWeb.Endpoint,
  live_view: [signing_salt: "secret"],
  pubsub_server: Markdoc.PubSub
```

### Monitoring
- **Document activity**: Track active documents and users
- **File I/O metrics**: Monitor save performance
- **Memory usage**: Track GenServer memory consumption
- **Error rates**: Monitor operation failures and conflicts
