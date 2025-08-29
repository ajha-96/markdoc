# Collaborative Markdown Editor - Design Document

## Project Overview

A real-time collaborative markdown editor built with Elixir and Phoenix, enabling multiple users to write concurrently without authentication. Think "Google Docs for Markdown" with UUID-based document sharing.

## Core Features

### User Experience
- **No Authentication Required**: Anyone can start writing immediately
- **Simple User Flow**: Enter name → Get document link → Share with others
- **Real-time Collaboration**: Multiple users write simultaneously 
- **Live Cursors & Selections**: See where everyone is typing in real-time
- **Auto-save**: Periodic saves with visual save status indicators
- **Markdown Preview**: Live preview pane showing rendered markdown

### Technical Features
- **UUID-based Documents**: Shareable links with unique document IDs
- **File-based Storage**: Documents stored as markdown files on disk
- **Real-time Sync**: Operational transforms for conflict-free editing
- **User Presence**: Track active users and their cursor positions
- **Mobile Responsive**: Works well on desktop and mobile devices

## Architecture Overview

### Backend (Phoenix/Elixir)
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   LiveView      │    │  DocumentManager │    │  File Storage   │
│  (UI Layer)     │◄──►│   (GenServer)    │◄──►│  docs/{uuid}/   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│ Phoenix Channels│    │   User Presence  │
│  (WebSockets)   │    │    Tracking      │
└─────────────────┘    └──────────────────┘
```

### Frontend Components
- **Editor Component**: Main text editing interface
- **Cursor Overlay**: Visual indicators for user cursors/selections  
- **User Presence Bar**: Shows active users with their colors
- **Preview Pane**: Live markdown rendering
- **Save Status**: Auto-save indicators and timestamps

## User Interface Design

### Layout Structure
```
┌────────────────────────────────────────────────────────────┐
│ 📄 Document Title    [Saving...] 👤User1 👤User2 👤User3   │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  Editor Pane                    │    Preview Pane          │
│                                 │                          │
│  # My Document                  │  # My Document           │
│  This is [User1 selection]     │  This is **some text**   │
│  More content here|User2        │  More content here       │
│                                 │                          │
│  Another paragraph|User3        │  Another paragraph       │
│                                 │                          │
└────────────────────────────────────────────────────────────┘
```

### Visual Elements
- **User Colors**: Each user gets a unique color for cursors/selections
- **Cursor Indicators**: Colored vertical lines with name labels
- **Selection Highlighting**: Semi-transparent colored backgrounds  
- **Typing Indicators**: Subtle animations showing who's actively typing
- **Mobile Adaptations**: Collapsible preview, touch-friendly cursors

## Data Models

### Document State (In-Memory)
```elixir
%{
  id: "550e8400-e29b-41d4-a716-446655440000",
  content: "# Document Title\n\nContent here...",
  users: %{
    "user-session-1" => %{
      name: "Alice",
      color: "#FF6B6B",
      cursor_position: 45,
      selection: %{start: 30, end: 40},
      last_activity: ~U[2024-01-15 10:30:00Z],
      typing: false
    }
  },
  last_saved: ~U[2024-01-15 10:29:45Z],
  dirty: true
}
```

### File Storage Structure
```
docs/
├── 550e8400-e29b-41d4-a716-446655440000/
│   └── document.md
├── another-uuid-here/
│   └── document.md
└── ...
```

## Real-time Collaboration

### Operational Transforms
- **Insert Operations**: Add text at specific positions
- **Delete Operations**: Remove text ranges
- **Cursor Adjustments**: Update cursor positions after operations
- **Conflict Resolution**: Transform concurrent operations

### User Presence System
- **Color Assignment**: 8-10 predefined colors rotated among users
- **Cursor Broadcasting**: Real-time cursor position updates
- **Selection Sync**: Live text selection sharing
- **Activity Tracking**: Typing indicators and last-seen timestamps

## Technical Decisions

### Storage Choice: File System
**Why not PostgreSQL?**
- Simpler setup and deployment
- Easy backup (copy docs folder)
- No database migrations or schemas
- Direct file access for debugging
- Can add database later if needed

### No History Tracking (Initially)
- Single file per document, overwritten on save
- Keeps implementation simple
- Can add version history later as separate feature

### Periodic Auto-save
- DocumentManager flushes to disk every 10 seconds
- UI shows save status: "Saving..." → "All changes saved"
- Prevents data loss without constant disk I/O

## User Experience Flow

### New Document Creation
1. User visits landing page
2. Enters their name
3. System generates UUID and creates document
4. User gets shareable link
5. Can immediately start writing

### Joining Existing Document  
1. User clicks shared link
2. Enters their name
3. Gets assigned unique color
4. Sees current document content
5. Can start writing immediately

### Collaborative Writing
1. Multiple users write simultaneously
2. See real-time text changes from others
3. Visual cursors show where everyone is typing
4. Auto-save keeps everything in sync
5. Export options available (markdown, HTML, PDF)

## Success Metrics

### Technical Performance
- **Sub-100ms latency** for text synchronization
- **Handles 10+ concurrent users** per document
- **99.9% uptime** with automatic crash recovery
- **Mobile responsive** on all devices

### User Experience  
- **Zero learning curve** - immediate productivity
- **Conflict-free editing** - no lost changes
- **Clear visual feedback** - always know what's happening
- **Reliable auto-save** - never lose work
