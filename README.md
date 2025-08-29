# Markdoc - Real-time Collaborative Markdown Editor

A real-time collaborative markdown editor built with Elixir and Phoenix. Think "Google Docs for Markdown" with no authentication required - just share a link and start writing together!

## ✨ Features

- 🔗 **UUID-based document sharing** - No login required, just share the link
- 👥 **Real-time collaborative editing** - Multiple users can write simultaneously  
- 💾 **Auto-save with file-based storage** - Your work is automatically saved
- 📱 **Mobile responsive design** - Works great on all devices
- 👀 **Live markdown preview** - See your formatted content in real-time
- 🎨 **Color-coded user presence** - Visual cursors show where everyone is typing

## 🚀 Quick Start

### Prerequisites

- Elixir 1.15+ 
- Node.js (for asset compilation)

### Setup

1. **Install dependencies**
   ```bash
   mix setup
   ```

2. **Start the server**
   ```bash
   mix phx.server
   ```

3. **Visit the app**
   Open [`localhost:4000`](http://localhost:4000) in your browser

That's it! Create a new document, enter your name, and start writing. Share the link with others to collaborate in real-time.

## 🏗️ Architecture

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

## 🛠️ Technology Stack

- **Backend**: Elixir, Phoenix Framework, LiveView
- **Real-time**: Phoenix Channels (WebSockets)
- **Frontend**: Phoenix LiveView, Alpine.js, Tailwind CSS  
- **Storage**: File system (no database required)
- **Markdown**: Earmark parser for live preview

## 📖 Documentation

Complete project documentation is available in the [`docs/`](./docs/) folder:

- 📋 [Design Document](./docs/design-document.md) - Project vision and architecture
- 🔧 [Technical Requirements](./docs/technical-requirements.md) - Detailed specifications  
- 🚀 [Implementation Plan](./docs/implementation-plan.md) - Development roadmap

## 🧪 Development

### Running Tests
```bash
mix test
```

### Code Quality
```bash
mix precommit  # Runs compile, format, and tests
```

### Asset Development
```bash
# Setup assets (run once)
mix assets.setup

# Build assets for development  
mix assets.build

# Build and watch assets
mix phx.server
```

## 📁 Project Structure

```
markdoc/
├── docs/                    # Project documentation
├── lib/
│   ├── markdoc/            # Core business logic
│   └── markdoc_web/        # Phoenix web layer
├── assets/                 # Frontend assets
├── docs/                   # Document storage (runtime)
└── test/                   # Test files
```

## 🚀 Deployment

Ready to run in production? Check the [Phoenix deployment guides](https://hexdocs.pm/phoenix/deployment.html).

For this project specifically:
1. Ensure the `docs/` directory is writable
2. Set appropriate file permissions for document storage
3. Consider backup strategy for the file-based storage

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `mix precommit` to ensure code quality
5. Submit a pull request

## 📄 License

This project is open source. See the project documentation for more details.
