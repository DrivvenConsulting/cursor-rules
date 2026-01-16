# Cursor Rules Installation

This repository contains Cursor IDE rules organized by category. Use the installation script to install all rules as user rules in Cursor.

## Installation

### Prerequisites

- macOS (the script is designed for macOS)
- Cursor IDE installed and launched at least once
- `sqlite3` command-line tool (usually pre-installed on macOS)

### Quick Start

Run the installation script:

```bash
./install.sh
```

The script will:
1. Scan all `RULE.md` files in the `rules/` directory
2. Combine them into a single ruleset
3. Create a backup of your Cursor database
4. Install the combined rules as user rules in Cursor
5. Prompt you to restart Cursor

### Manual Restart

After installation, restart Cursor to apply the rules:

```bash
osascript -e 'tell application "Cursor" to quit' && open -a "Cursor"
```

Or simply quit and reopen Cursor manually.

## How It Works

The installation script:
- Finds all `RULE.md` files in subdirectories of `rules/`
- Strips the frontmatter (YAML metadata) from each file
- Combines all rules into a single text document
- Updates the Cursor SQLite database at:
  ```
  ~/Library/Application Support/Cursor/User/globalStorage/state.vscdb
  ```
- Stores the rules under the key `aicontext.personalContext`

## Rules Structure

Each rule is stored in its own directory under `rules/` with a `RULE.md` file:

```
rules/
  ├── architecture-decoupling/
  │   └── RULE.md
  ├── aws-cognito/
  │   └── RULE.md
  ├── code-quality-python/
  │   └── RULE.md
  └── ...
```

## Backup

The script automatically creates a backup of your Cursor database before making changes. Backups are stored in the same directory with a timestamp:

```
state.vscdb.backup.20240101_120000
```

## Troubleshooting

### Error: sqlite3 not found
Install sqlite3 via Homebrew:
```bash
brew install sqlite
```

### Error: Database not found
Make sure Cursor has been launched at least once. The database is created on first launch.

### Rules not appearing in Cursor
1. Make sure you've restarted Cursor after installation
2. Check Cursor Settings → Rules → User Rules to verify the rules are there
3. If rules are missing, restore from the backup and try again

## Uninstalling

To remove the installed rules, you can:
1. Manually clear the User Rules in Cursor Settings → Rules → User Rules
2. Or restore the database from a backup:
   ```bash
   cp "${HOME}/Library/Application Support/Cursor/User/globalStorage/state.vscdb.backup.TIMESTAMP" \
      "${HOME}/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
   ```
