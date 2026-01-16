#!/usr/bin/env bash

# Installation script for Cursor Rules
# This script combines all RULE.md files and installs them as user rules in Cursor

set -euo pipefail

# Ensure we're running with bash (not sh)
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: This script requires bash. Please run it with: bash install.sh" >&2
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_DIR="${SCRIPT_DIR}/rules"

# Cursor database path for macOS
DB_PATH="${HOME}/Library/Application Support/Cursor/User/globalStorage/state.vscdb"

# Function to print colored messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if sqlite3 is available
if ! command -v sqlite3 &> /dev/null; then
    error "sqlite3 is not installed. Please install it first."
    error "On macOS, you can install it via: brew install sqlite"
    exit 1
fi

# Check if rules directory exists
if [ ! -d "$RULES_DIR" ]; then
    error "Rules directory not found: $RULES_DIR"
    exit 1
fi

# Check if Cursor database exists
if [ ! -f "$DB_PATH" ]; then
    error "Cursor state database not found at: $DB_PATH"
    error "Make sure Cursor has been launched at least once."
    exit 1
fi

# Function to strip frontmatter from markdown files
strip_frontmatter() {
    local file="$1"
    # Remove frontmatter (lines between --- markers at the start)
    awk '
        BEGIN { in_frontmatter = 0; frontmatter_started = 0 }
        /^---$/ && !frontmatter_started { 
            in_frontmatter = 1
            frontmatter_started = 1
            next
        }
        /^---$/ && in_frontmatter { 
            in_frontmatter = 0
            next
        }
        !in_frontmatter { print }
    ' "$file"
}

# Function to combine all RULE.md files
combine_rules() {
    local combined_rules=""
    local rule_count=0
    
    info "Scanning for RULE.md files..." >&2
    
    # Find all RULE.md files and process them
    # Use a temporary file to avoid process substitution issues
    local temp_file
    temp_file=$(mktemp)
    find "$RULES_DIR" -name "RULE.md" -type f | sort > "$temp_file"
    
    while IFS= read -r rule_file; do
        [ -z "$rule_file" ] && continue
        rule_count=$((rule_count + 1))
        rule_name=$(basename "$(dirname "$rule_file")")
        info "  Found: $rule_name" >&2
        
        # Add separator and rule name
        combined_rules+="\n\n# Rule: ${rule_name}\n\n"
        
        # Strip frontmatter and add content
        combined_rules+="$(strip_frontmatter "$rule_file")"
        combined_rules+="\n"
    done < "$temp_file"
    
    rm -f "$temp_file"
    
    if [ $rule_count -eq 0 ]; then
        error "No RULE.md files found in $RULES_DIR" >&2
        exit 1
    fi
    
    info "Found $rule_count rule file(s)" >&2
    
    # Remove leading newlines
    combined_rules="${combined_rules#\\n\\n}"
    
    echo -e "$combined_rules"
}

# Backup the database before making changes
backup_database() {
    local backup_path="${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    info "Creating backup of Cursor database..."
    cp "$DB_PATH" "$backup_path"
    info "Backup created: $backup_path"
}

# Install rules to Cursor database
install_rules() {
    local rules_text="$1"
    
    info "Installing rules to Cursor database..."
    
    # Use Python to generate the SQL file with proper escaping
    # Write rules to temp file first, then have Python read it
    local rules_file
    rules_file=$(mktemp)
    local sql_file
    sql_file=$(mktemp)
    
    # Write rules text to temp file
    printf '%s' "$rules_text" > "$rules_file"
    
    # Use Python to escape and generate SQL
    python3 <<PYTHON_SCRIPT
import sys

# Read rules text from file
with open('$rules_file', 'r') as f:
    rules_text = f.read()

# Escape single quotes for SQL (double them)
escaped_text = rules_text.replace("'", "''")

# Generate SQL
sql = f"""BEGIN TRANSACTION;
INSERT OR REPLACE INTO ItemTable (key, value)
  VALUES ('aicontext.personalContext', '{escaped_text}');
COMMIT;
"""

# Write SQL file
with open('$sql_file', 'w') as f:
    f.write(sql)
PYTHON_SCRIPT
    
    sqlite3 "$DB_PATH" < "$sql_file"
    local exit_code=$?
    rm -f "$sql_file" "$rules_file"
    
    if [ $exit_code -eq 0 ]; then
        info "Rules successfully installed!"
    else
        error "Failed to install rules to database"
        exit 1
    fi
}

# Main execution
main() {
    info "Starting Cursor Rules installation..."
    info "Rules directory: $RULES_DIR"
    info "Database path: $DB_PATH"
    echo ""
    
    # Combine all rules
    combined_rules=$(combine_rules)
    
    # Backup database
    backup_database
    echo ""
    
    # Install rules
    install_rules "$combined_rules"
    echo ""
    
    info "Installation complete!"
    warn "Please restart Cursor for the rules to take effect."
    echo ""
    info "To restart Cursor, run:"
    echo "  osascript -e 'tell application \"Cursor\" to quit' && open -a \"Cursor\""
}

# Run main function
main
