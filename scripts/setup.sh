#!/usr/bin/env bash
set -euo pipefail

# ILG Project Setup Script
# Usage: bash scripts/setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== ILG Project Setup ==="
echo "Project root: $PROJECT_ROOT"

# 1. Check prerequisites
echo ""
echo "--- Checking prerequisites ---"
command -v node >/dev/null 2>&1 || { echo "ERROR: Node.js not found. Install via 'brew install node'"; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "ERROR: npm not found"; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "ERROR: sqlite3 not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 not found"; exit 1; }

echo "Node.js: $(node --version)"
echo "npm: $(npm --version)"
echo "SQLite: $(sqlite3 --version | head -c 20)"
echo "Python: $(python3 --version)"

# Check Docker (warning only — needed for n8n but not for initial setup)
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
    echo "WARNING: Docker not available. Install Docker Desktop for n8n support."
    echo "         Setup will continue without Docker."
fi

# 2. Create directories (idempotent)
echo ""
echo "--- Ensuring directories exist ---"
mkdir -p "$PROJECT_ROOT"/{.claude,claude-skills,claude-agents}
mkdir -p "$PROJECT_ROOT"/mcp-servers/{reddit-mcp,twitter-mcp,linkedin-mcp}
mkdir -p "$PROJECT_ROOT"/{n8n-workflows,db/migrations,db/seeds,config/default-verticals}
mkdir -p "$PROJECT_ROOT"/{scripts,docs,logs,exports}
echo "Directories OK."

# 3. Initialize database
echo ""
echo "--- Initializing SQLite database ---"
cd "$PROJECT_ROOT/db"
if [ ! -f "package.json" ]; then
    echo "ERROR: db/package.json not found. Ensure project files are in place."
    exit 1
fi
npm install --silent 2>/dev/null
node init.js
echo ""

# 4. Copy .env.example if .env doesn't exist
echo "--- Environment configuration ---"
if [ ! -f "$PROJECT_ROOT/config/.env" ]; then
    if [ -f "$PROJECT_ROOT/config/.env.example" ]; then
        cp "$PROJECT_ROOT/config/.env.example" "$PROJECT_ROOT/config/.env"
        echo "Created config/.env from template. Edit it with your API keys."
    fi
else
    echo "config/.env already exists. Skipping."
fi

# 5. Seed default vertical configs into database
echo ""
echo "--- Seeding default vertical configs ---"
for config_file in "$PROJECT_ROOT"/config/default-verticals/*.json; do
    if [ -f "$config_file" ]; then
        vertical_id=$(python3 -c "import json; print(json.load(open('$config_file'))['vertical_id'])")
        vertical_name=$(python3 -c "import json; print(json.load(open('$config_file'))['vertical_name'])")
        # Use python to safely escape the JSON for SQL insertion
        python3 -c "
import json, sqlite3, sys
config = json.load(open('$config_file'))
conn = sqlite3.connect('$PROJECT_ROOT/db/ilg.db')
conn.execute(
    'INSERT OR REPLACE INTO vertical_configs (vertical_id, vertical_name, config_json, updated_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)',
    (config['vertical_id'], config['vertical_name'], json.dumps(config))
)
conn.commit()
conn.close()
"
        echo "  Seeded: $vertical_id"
    fi
done

# 6. Summary
echo ""
echo "=== Setup Complete ==="
echo ""
echo "Database: $PROJECT_ROOT/db/ilg.db"
VERTICAL_COUNT=$(sqlite3 "$PROJECT_ROOT/db/ilg.db" "SELECT COUNT(*) FROM vertical_configs;")
echo "Verticals loaded: $VERTICAL_COUNT"
echo ""
echo "Next steps:"
echo "  1. Edit config/.env with your API keys"
echo "  2. Install Docker Desktop for n8n (brew install --cask docker)"
echo "  3. Run 'docker compose up -d' to start n8n"
echo "  4. Open Claude Code and try: 'Show me all configured verticals'"
