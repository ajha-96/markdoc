# Markdoc Project Documentation

This folder contains the complete project documentation for the collaborative markdown editor.

## Documentation Files

### 📋 [Design Document](./design-document.md)
Complete project overview including:
- Project vision and core features
- Architecture diagrams and system design
- User interface mockups and flow
- Data models and technical decisions

### 🔧 [Technical Requirements](./technical-requirements.md)
Detailed technical specifications covering:
- Technology stack and dependencies
- Performance and scalability requirements
- Core component specifications
- Data structures and API designs

### 🚀 [Implementation Plan](./implementation-plan.md)  
Step-by-step development roadmap including:
- 4-week phased implementation approach
- File structure and code organization
- Testing strategy and deployment considerations
- Success criteria and deliverables

## Project Overview

**Goal**: Build a real-time collaborative markdown editor using Elixir and Phoenix - think "Google Docs for Markdown" with no authentication required.

**Key Features**:
- 🔗 UUID-based document sharing (no login required)
- 👥 Real-time collaborative editing with visual cursors
- 💾 File-based storage with auto-save
- 📱 Mobile responsive design  
- 👀 Live markdown preview
- 🎨 Color-coded user presence

**Technology Stack**:
- **Backend**: Elixir, Phoenix, LiveView, Channels
- **Storage**: File system (no database)
- **Frontend**: Phoenix LiveView, Alpine.js, Tailwind CSS
- **Real-time**: WebSockets with operational transforms

## Quick Start

1. Read the [Design Document](./design-document.md) for project overview
2. Review [Technical Requirements](./technical-requirements.md) for specifications  
3. Follow [Implementation Plan](./implementation-plan.md) for development phases

## Architecture Summary

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Phoenix       │    │  DocumentManager │    │  File Storage   │
│   LiveView      │◄──►│   (GenServer)    │◄──►│  docs/{uuid}/   │
│                 │    │                  │    │  document.md    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│ Phoenix Channels│    │   User Presence  │
│  (WebSockets)   │    │    & Cursors     │
└─────────────────┘    └──────────────────┘
```

Ready to build the future of collaborative markdown editing! 🚀
