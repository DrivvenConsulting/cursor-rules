#!/usr/bin/env bash

# Installation script for Cursor Rules
# This script combines all RULE.md files and installs them as user rules in Cursor

set -euo pipefail

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
    
    info "Scanning for RULE.md files..."
    
    # Find all RULE.md files and process them
    while IFS= read -r -d '' rule_file; do
        rule_count=$((rule_count + 1))
        rule_name=$(basename "$(dirname "$rule_file")")
        info "  Found: $rule_name"
        
        # Add separator and rule name
        combined_rules+="\n\n# Rule: ${rule_name}\n\n"
        
        # Strip frontmatter and add content
        combined_rules+="$(strip_frontmatter "$rule_file")"
        combined_rules+="\n"
    done < <(find "$RULES_DIR" -name "RULE.md" -type f -print0 | sort -z)
    
    if [ $rule_count -eq 0 ]; then
        error "No RULE.md files found in $RULES_DIR"
        exit 1
    fi
    
    info "Found $rule_count rule file(s)"
    
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
    
    # Use sqlite3 to update the rules
    # The value needs to be properly escaped for SQL
    sqlite3 "$DB_PATH" <<EOF
BEGIN TRANSACTION;
INSERT INTO ItemTable (key, value)
  VALUES ('aicontext.personalContext', $(printf "%q" "$rules_text"))
  ON CONFLICT(key) DO UPDATE SET
    value = excluded.value;
COMMIT;
EOF
    
    if [ $? -eq 0 ]; then
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
