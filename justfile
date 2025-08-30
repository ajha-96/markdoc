# Markdoc Build Commands
# ======================

# Default recipe - setup and build everything
default: setup build

# Setup all dependencies
setup:
    mix deps.get
    mix assets.setup
    cd assets && npm install

# Build everything (development)
build: compile assets-build

# Build everything for production
build-prod: compile assets-deploy

# Compile Elixir code
compile:
    mix compile

# Build frontend assets (development)
assets-build:
    mix assets.build

# Build and deploy frontend assets (production)
assets-deploy:
    mix assets.deploy

# Build individual asset types
css:
    mix tailwind markdoc

js:
    mix esbuild markdoc

# Build minified assets for production
css-prod:
    mix tailwind markdoc --minify

js-prod:
    mix esbuild markdoc --minify

# Collect and digest static assets
digest:
    mix phx.digest

# Development server
server:
    mix phx.server

# Run tests
test:
    mix test

# Format code
format:
    mix format

# Run precommit checks
precommit:
    mix precommit

# Clean build artifacts
clean:
    mix clean
    rm -rf _build
    rm -rf deps
    rm -rf assets/node_modules
    rm -rf priv/static

# Install tools (if missing)
install-tools:
    mix tailwind.install --if-missing
    mix esbuild.install --if-missing

# Full clean and rebuild
rebuild: clean setup build

# Watch for file changes and rebuild
watch:
    mix phx.server