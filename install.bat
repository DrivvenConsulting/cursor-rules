@echo off
setlocal enabledelayedexpansion

REM Installation script for Cursor Rules (Windows)
REM This script combines all RULE.md files and installs them as user rules in Cursor

REM Colors for output (using ANSI escape codes if supported)
set "GREEN=[92m"
set "YELLOW=[93m"
set "RED=[91m"
set "NC=[0m"

REM Script directory (where this script is located)
set "SCRIPT_DIR=%~dp0"
set "RULES_DIR=%SCRIPT_DIR%rules"

REM Cursor database path for Windows
set "DB_PATH=%APPDATA%\Cursor\User\globalStorage\state.vscdb"

REM Function to print colored messages
goto :main

:info
echo [INFO] %~1
goto :eof

:warn
echo [WARN] %~1
goto :eof

:error
echo [ERROR] %~1
goto :eof

:main
call :info "Starting Cursor Rules installation..."
call :info "Rules directory: %RULES_DIR%"
call :info "Database path: %DB_PATH%"
echo.

REM Check if Python is available
where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :error "Python is not installed or not in PATH."
    call :error "Please install Python 3 from: https://www.python.org/downloads/"
    exit /b 1
)

REM Check if sqlite3 is available
where sqlite3 >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    call :error "sqlite3 is not installed. Please install it first."
    call :error "You can download it from: https://www.sqlite.org/download.html"
    call :error "Or install via chocolatey: choco install sqlite"
    exit /b 1
)

REM Check if rules directory exists
if not exist "%RULES_DIR%" (
    call :error "Rules directory not found: %RULES_DIR%"
    exit /b 1
)

REM Check if Cursor database exists
if not exist "%DB_PATH%" (
    call :error "Cursor state database not found at: %DB_PATH%"
    call :error "Make sure Cursor has been launched at least once."
    exit /b 1
)

REM Create temporary files
set "TEMP_RULES=%TEMP%\cursor_rules_%RANDOM%.txt"
set "TEMP_SQL=%TEMP%\cursor_rules_%RANDOM%.sql"

REM Combine all RULE.md files
call :info "Scanning for RULE.md files..."

REM Use PowerShell to find and process RULE.md files
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop';" ^
    "try {" ^
    "    $rules = @();" ^
    "    $ruleFiles = Get-ChildItem -Path '%RULES_DIR%' -Filter 'RULE.md' -Recurse -File -ErrorAction SilentlyContinue | Sort-Object FullName;" ^
    "    if (-not $ruleFiles) { Write-Host '[ERROR] No RULE.md files found in %RULES_DIR%' -ForegroundColor Red; exit 1; };" ^
    "    foreach ($file in $ruleFiles) {" ^
    "        $dirName = $file.Directory.Name;" ^
    "        Write-Host \"  Found: $dirName\" -ForegroundColor Green;" ^
    "        $content = Get-Content $file.FullName -Raw -Encoding UTF8;" ^
    "        $content = $content -replace '(?s)^---.*?---\r?\n', '';" ^
    "        $rules += \"`n`n# Rule: $dirName`n`n$content`n\";" ^
    "    };" ^
    "    Write-Host \"[INFO] Found $($rules.Count) rule file(s)\" -ForegroundColor Green;" ^
    "    $combined = $rules -join '';" ^
    "    $combined = $combined.TrimStart();" ^
    "    [System.IO.File]::WriteAllText('%TEMP_RULES%', $combined, [System.Text.Encoding]::UTF8);" ^
    "    Write-Host '[INFO] Rules combined successfully' -ForegroundColor Green;" ^
    "} catch {" ^
    "    Write-Host \"[ERROR] Failed to combine rules: $_\" -ForegroundColor Red; exit 1;" ^
    "}"

if %ERRORLEVEL% NEQ 0 (
    call :error "Failed to combine rules"
    exit /b 1
)

REM Backup the database before making changes
call :info "Creating backup of Cursor database..."
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "DATETIME=%%I"
set "BACKUP_PATH=%DB_PATH%.backup.%DATETIME:~0,8%_%DATETIME:~8,6%"
copy "%DB_PATH%" "!BACKUP_PATH!" >nul
if %ERRORLEVEL% EQU 0 (
    call :info "Backup created: !BACKUP_PATH!"
) else (
    call :error "Failed to create backup"
    exit /b 1
)
echo.

REM Install rules to Cursor database
call :info "Installing rules to Cursor database..."

REM Use Python to escape and generate SQL
python -c ^
    "import sys;" ^
    "try:" ^
    "    with open(r'%TEMP_RULES%', 'r', encoding='utf-8') as f:" ^
    "        rules_text = f.read();" ^
    "    escaped_text = rules_text.replace(\"'\", \"''\");" ^
    "    sql = \"\"\"BEGIN TRANSACTION;\nINSERT OR REPLACE INTO ItemTable (key, value)\n  VALUES ('aicontext.personalContext', '{}');\nCOMMIT;\n\"\"\".format(escaped_text);" ^
    "    with open(r'%TEMP_SQL%', 'w', encoding='utf-8') as f:" ^
    "        f.write(sql);" ^
    "except Exception as e:" ^
    "    print(f'[ERROR] Failed to generate SQL: {e}', file=sys.stderr);" ^
    "    sys.exit(1);"

if %ERRORLEVEL% NEQ 0 (
    call :error "Failed to generate SQL"
    goto :cleanup
)

REM Execute SQL
sqlite3 "%DB_PATH%" < "%TEMP_SQL%"
if %ERRORLEVEL% EQU 0 (
    call :info "Rules successfully installed!"
) else (
    call :error "Failed to install rules to database"
    goto :cleanup
)

echo.
call :info "Installation complete!"
call :warn "Please restart Cursor for the rules to take effect."
echo.
call :info "To restart Cursor, close and reopen the application manually."

:cleanup
REM Clean up temporary files
if exist "%TEMP_RULES%" del "%TEMP_RULES%" >nul 2>&1
if exist "%TEMP_SQL%" del "%TEMP_SQL%" >nul 2>&1

endlocal
exit /b %ERRORLEVEL%
