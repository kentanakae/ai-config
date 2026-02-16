#!/bin/sh
set -e

# ai-config setup script
# Usage: curl -sL https://raw.githubusercontent.com/kentanakae/ai-config/main/setup-ai-config.sh | sh
# Or:    sh setup-ai-config.sh [--claude] [--gemini] [--codex] [--dir <path>] [--uninstall]

REPO_URL="https://github.com/kentanakae/ai-config.git"

# --- Argument parsing ---

INSTALL_DIR="."
DO_CLAUDE=false
DO_GEMINI=false
DO_CODEX=false
DO_UNINSTALL=false
DO_DRY_RUN=false
ANY_AGENT=false

show_help() {
  cat <<'HELP'
Usage: setup-ai-config.sh [OPTIONS]

Setup ai-config agent settings in a project directory.

Options:
  --claude      Setup Claude Code settings only
  --gemini      Setup Gemini CLI settings only
  --codex       Setup Codex CLI settings only
  --dir <path>  Install directory (default: current directory)
  --uninstall   Remove agent settings
  --dry-run     Show what would be done without making changes
  --help        Show this help message

No agent flags = setup all agents.
Multiple flags can be combined (e.g. --claude --gemini).

Examples:
  sh setup-ai-config.sh --dir ~/my-project
  sh setup-ai-config.sh --claude --dir ~/my-project
  sh setup-ai-config.sh --uninstall --dir ~/my-project
  sh setup-ai-config.sh --dry-run --dir ~/my-project
HELP
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    --claude)
      DO_CLAUDE=true
      ANY_AGENT=true
      ;;
    --gemini)
      DO_GEMINI=true
      ANY_AGENT=true
      ;;
    --codex)
      DO_CODEX=true
      ANY_AGENT=true
      ;;
    --dir)
      shift
      INSTALL_DIR="$1"
      ;;
    --uninstall)
      DO_UNINSTALL=true
      ;;
    --dry-run)
      DO_DRY_RUN=true
      ;;
    --help)
      show_help
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run 'setup-ai-config.sh --help' for usage information."
      exit 1
      ;;
  esac
  shift
done

# No agent flags = all agents
if [ "$ANY_AGENT" = false ]; then
  DO_CLAUDE=true
  DO_GEMINI=true
  DO_CODEX=true
fi

# Resolve install dir to absolute path
INSTALL_DIR="$(cd "$INSTALL_DIR" 2>/dev/null && pwd)" || {
  echo "Error: directory '$INSTALL_DIR' does not exist."
  exit 1
}

# --- Counters for summary ---

COUNT_COPIED=0
COUNT_SKIPPED=0
COUNT_SYMLINKED=0
COUNT_DELETED=0

# --- Helper functions ---

# Interactive yes/no selector with arrow keys (vertical layout)
# Usage: select_yn "prompt" && echo "yes chosen" || echo "no chosen"
# Controls: up/down to switch, Enter to confirm, y/n for direct input
select_yn() {
  _sy_prompt="$1"
  _sy_sel=1  # 0=Yes, 1=No (default: No)

  # Non-interactive: default Yes
  if [ ! -t 0 ]; then
    return 0
  fi

  _sy_esc=$(printf '\033')
  _sy_old_stty=$(stty -g)
  stty -icanon -echo

  printf '  %s\n' "$_sy_prompt"
  printf '\n\n'  # Reserve 2 lines for options

  while true; do
    # Move up 2 lines and redraw options
    printf '\033[2A'
    if [ "$_sy_sel" -eq 0 ]; then
      printf '\033[K  \033[7m ▸ Yes \033[0m\n'
      printf '\033[K    No \n'
    else
      printf '\033[K    Yes \n'
      printf '\033[K  \033[7m ▸ No  \033[0m\n'
    fi

    _sy_key=$(dd bs=1 count=1 2>/dev/null)

    case "$_sy_key" in
      "$_sy_esc")
        # Arrow key escape sequence: ESC [ A/B/C/D
        _sy_k2=$(dd bs=1 count=1 2>/dev/null)
        _sy_k3=$(dd bs=1 count=1 2>/dev/null)
        case "$_sy_k3" in
          A|D) _sy_sel=0 ;;  # Up/Left → Yes
          B|C) _sy_sel=1 ;;  # Down/Right → No
        esac
        ;;
      y|Y) _sy_sel=0; break ;;
      n|N) _sy_sel=1; break ;;
      "") break ;;  # Enter
    esac
  done

  # Final redraw to show confirmed selection
  printf '\033[2A'
  if [ "$_sy_sel" -eq 0 ]; then
    printf '\033[K  \033[7m ▸ Yes \033[0m\n'
    printf '\033[K    No \n'
  else
    printf '\033[K    Yes \n'
    printf '\033[K  \033[7m ▸ No  \033[0m\n'
  fi

  stty "$_sy_old_stty"
  return "$_sy_sel"
}

confirm_overwrite() {
  _co_file="$1"
  if [ -f "$_co_file" ] && [ ! -L "$_co_file" ]; then
    select_yn "Overwrite '$_co_file'?"
    return $?
  fi
  return 0
}

confirm_delete() {
  _cd_target="$1"
  if [ -e "$_cd_target" ] || [ -L "$_cd_target" ]; then
    select_yn "Delete '$_cd_target'?"
    return $?
  fi
  return 1
}

copy_file() {
  _cf_src="$1"
  _cf_dest="$2"

  if [ "$DO_DRY_RUN" = true ]; then
    if [ -f "$_cf_dest" ] && [ ! -L "$_cf_dest" ]; then
      echo "  [dry-run] Would overwrite: $_cf_dest"
    else
      echo "  [dry-run] Would copy: $_cf_dest"
    fi
    return
  fi

  mkdir -p "$(dirname "$_cf_dest")"

  if confirm_overwrite "$_cf_dest"; then
    cp "$_cf_src" "$_cf_dest"
    echo "  Copied: $_cf_dest"
    COUNT_COPIED=$((COUNT_COPIED + 1))
  else
    echo "  Skipped: $_cf_dest"
    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
  fi
}

copy_dir() {
  _cd_src="$1"
  _cd_dest="$2"

  if [ ! -d "$_cd_src" ]; then
    return
  fi

  # Use temp file to avoid subshell from pipe (preserves counters)
  _cd_tmplist="$(mktemp)"
  find "$_cd_src" -type f > "$_cd_tmplist"
  while read -r _cd_file; do
    _cd_rel="${_cd_file#"$_cd_src"/}"
    copy_file "$_cd_file" "$_cd_dest/$_cd_rel"
  done < "$_cd_tmplist"
  rm -f "$_cd_tmplist"
}

create_symlink() {
  _cs_link="$1"
  _cs_target="$2"

  if [ "$DO_DRY_RUN" = true ]; then
    echo "  [dry-run] Would symlink: $_cs_link -> $_cs_target"
    return
  fi

  mkdir -p "$(dirname "$_cs_link")"

  if [ -L "$_cs_link" ]; then
    rm "$_cs_link"
  elif [ -e "$_cs_link" ]; then
    echo "  Warning: '$_cs_link' exists and is not a symlink. Skipping."
    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    return
  fi

  ln -s "$_cs_target" "$_cs_link"
  echo "  Symlink: $_cs_link -> $_cs_target"
  COUNT_SYMLINKED=$((COUNT_SYMLINKED + 1))
}

# --- Setup functions ---

setup_common() {
  src="$1"
  dest="$INSTALL_DIR"

  echo "Setting up common files..."
  copy_dir "$src/.agents" "$dest/.agents"
}

setup_claude() {
  src="$1"
  dest="$INSTALL_DIR"

  echo "Setting up Claude Code..."
  copy_dir "$src/.claude" "$dest/.claude"
  create_symlink "$dest/.claude/rules" "../.agents/rules"
  create_symlink "$dest/.claude/skills" "../.agents/skills"
}

setup_gemini() {
  src="$1"
  dest="$INSTALL_DIR"

  echo "Setting up Gemini CLI..."
  copy_file "$src/GEMINI.md" "$dest/GEMINI.md"
  copy_dir "$src/.gemini" "$dest/.gemini"
  create_symlink "$dest/.gemini/skills" "../.agents/skills"
}

setup_codex() {
  src="$1"
  dest="$INSTALL_DIR"

  echo "Setting up Codex CLI..."
  create_symlink "$dest/AGENTS.md" ".agents/rules/AGENTS.md"
  copy_dir "$src/.codex" "$dest/.codex"
}

# --- Uninstall functions ---

delete_target() {
  _dt_path="$1"
  _dt_label="$2"
  _dt_is_dir="$3"

  if [ "$DO_DRY_RUN" = true ]; then
    echo "  [dry-run] Would delete: $_dt_label"
    return
  fi

  if confirm_delete "$_dt_path"; then
    if [ "$_dt_is_dir" = "dir" ]; then
      rm -rf "$_dt_path"
    else
      rm -f "$_dt_path"
    fi
    echo "  Deleted: $_dt_label"
    COUNT_DELETED=$((COUNT_DELETED + 1))
  else
    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
  fi
}

uninstall_common() {
  dest="$INSTALL_DIR"

  echo "Uninstalling common files..."
  if [ -d "$dest/.agents" ]; then
    delete_target "$dest/.agents" ".agents/" "dir"
  fi
}

uninstall_claude() {
  dest="$INSTALL_DIR"

  echo "Uninstalling Claude Code..."
  if [ -d "$dest/.claude" ] || [ -L "$dest/.claude/rules" ]; then
    delete_target "$dest/.claude" ".claude/" "dir"
  fi
}

uninstall_gemini() {
  dest="$INSTALL_DIR"

  echo "Uninstalling Gemini CLI..."
  if [ -f "$dest/GEMINI.md" ]; then
    delete_target "$dest/GEMINI.md" "GEMINI.md" "file"
  fi
  if [ -d "$dest/.gemini" ] || [ -L "$dest/.gemini/skills" ]; then
    delete_target "$dest/.gemini" ".gemini/" "dir"
  fi
}

uninstall_codex() {
  dest="$INSTALL_DIR"

  echo "Uninstalling Codex CLI..."
  if [ -L "$dest/AGENTS.md" ]; then
    delete_target "$dest/AGENTS.md" "AGENTS.md (symlink)" "file"
  fi
  if [ -d "$dest/.codex" ]; then
    delete_target "$dest/.codex" ".codex/" "dir"
  fi
}

# --- Main ---

show_summary() {
  echo ""
  if [ "$DO_DRY_RUN" = true ]; then
    echo "Dry run complete. No changes were made."
  else
    echo "Summary:"
    [ "$COUNT_COPIED" -gt 0 ] && echo "  Copied:    $COUNT_COPIED file(s)"
    [ "$COUNT_SYMLINKED" -gt 0 ] && echo "  Symlinked: $COUNT_SYMLINKED link(s)"
    [ "$COUNT_DELETED" -gt 0 ] && echo "  Deleted:   $COUNT_DELETED item(s)"
    [ "$COUNT_SKIPPED" -gt 0 ] && echo "  Skipped:   $COUNT_SKIPPED item(s)"
    if [ "$COUNT_COPIED" -eq 0 ] && [ "$COUNT_SYMLINKED" -eq 0 ] && [ "$COUNT_DELETED" -eq 0 ] && [ "$COUNT_SKIPPED" -eq 0 ]; then
      echo "  No changes made."
    fi
    echo ""
    echo "Done."
  fi
}

if [ "$DO_UNINSTALL" = true ]; then
  echo "Uninstalling from: $INSTALL_DIR"
  echo ""

  [ "$DO_CLAUDE" = true ] && uninstall_claude
  [ "$DO_GEMINI" = true ] && uninstall_gemini
  [ "$DO_CODEX" = true ] && uninstall_codex

  # Uninstall common only if all agents are being uninstalled
  if [ "$DO_CLAUDE" = true ] && [ "$DO_GEMINI" = true ] && [ "$DO_CODEX" = true ]; then
    uninstall_common
  fi

  show_summary
  exit 0
fi

# Determine source directory
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

# Update to latest if running from a git repo
if [ -d "$SCRIPT_DIR/.git" ]; then
  echo "Updating ai-config..."
  git -C "$SCRIPT_DIR" pull --quiet 2>/dev/null || true
fi

if [ -f "$SCRIPT_DIR/.agents/rules/AGENTS.md" ]; then
  # Running from within the repo
  SRC="$SCRIPT_DIR"
  CLEANUP_SRC=false
else
  # Running via pipe or from outside the repo — clone it
  SRC="$(mktemp -d)"
  CLEANUP_SRC=true
  trap 'rm -rf "$SRC"' EXIT
  echo "Cloning ai-config..."
  git clone --quiet --depth 1 "$REPO_URL" "$SRC/repo"
  SRC="$SRC/repo"
  echo ""
fi

echo "Installing to: $INSTALL_DIR"
echo ""

# Always setup common files
setup_common "$SRC"

[ "$DO_CLAUDE" = true ] && setup_claude "$SRC"
[ "$DO_GEMINI" = true ] && setup_gemini "$SRC"
[ "$DO_CODEX" = true ] && setup_codex "$SRC"

# Clean up cloned source if it was a temporary clone
if [ "$CLEANUP_SRC" = true ]; then
  rm -rf "$(dirname "$SRC")"
fi

show_summary

# Auto-cleanup if running from /tmp/ai-config
if [ "$DO_DRY_RUN" = false ]; then
  case "$SCRIPT_DIR" in
    /tmp/ai-config) rm -rf "$SCRIPT_DIR" ;;
  esac
fi
