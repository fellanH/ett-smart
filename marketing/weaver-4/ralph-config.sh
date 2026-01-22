#!/bin/bash
set -uo pipefail

# Configuration file
CONFIG_FILE=".ralph.config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Box drawing characters
BOX_H="═"
BOX_V="║"
BOX_TL="╔"
BOX_TR="╗"
BOX_BL="╚"
BOX_BR="╝"
BOX_T="╤"
BOX_B="╧"
BOX_L="╟"
BOX_R="╢"
BOX_CROSS="┼"

# Default values
DEFAULT_PROMPT_FILE="PROMPT.md"
DEFAULT_CSV_FILE="blue-collar-companies.csv"
DEFAULT_LOG_DIR=".logs"
DEFAULT_MAX_COMPANIES="10"
DEFAULT_CSV_ROWS_PER_SESSION="1"
DEFAULT_PARALLEL_AGENTS="1"
DEFAULT_ENABLE_SUB_AGENTS="true"
DEFAULT_CURSOR_BUDGET_LIMIT="0"
DEFAULT_CURSOR_USAGE_FILE=".logs/cursor_usage.json"

# Current selection
selected_item=1
total_items=9

# Load configuration from file
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE" 2>/dev/null || true
  fi
  
  # Set defaults if not set
  PROMPT_FILE="${PROMPT_FILE:-$DEFAULT_PROMPT_FILE}"
  CSV_FILE="${CSV_FILE:-$DEFAULT_CSV_FILE}"
  LOG_DIR="${LOG_DIR:-$DEFAULT_LOG_DIR}"
  MAX_COMPANIES="${MAX_COMPANIES:-$DEFAULT_MAX_COMPANIES}"
  CSV_ROWS_PER_SESSION="${CSV_ROWS_PER_SESSION:-$DEFAULT_CSV_ROWS_PER_SESSION}"
  PARALLEL_AGENTS="${PARALLEL_AGENTS:-$DEFAULT_PARALLEL_AGENTS}"
  ENABLE_SUB_AGENTS="${ENABLE_SUB_AGENTS:-$DEFAULT_ENABLE_SUB_AGENTS}"
  CURSOR_BUDGET_LIMIT="${CURSOR_BUDGET_LIMIT:-$DEFAULT_CURSOR_BUDGET_LIMIT}"
  CURSOR_USAGE_FILE="${CURSOR_USAGE_FILE:-$DEFAULT_CURSOR_USAGE_FILE}"
}

# Save configuration to file
save_config() {
  cat > "$CONFIG_FILE" << EOF
# Ralph Agent Configuration
# Generated on $(date '+%Y-%m-%d %H:%M:%S')

PROMPT_FILE="${PROMPT_FILE}"
CSV_FILE="${CSV_FILE}"
LOG_DIR="${LOG_DIR}"
MAX_COMPANIES="${MAX_COMPANIES}"
CSV_ROWS_PER_SESSION="${CSV_ROWS_PER_SESSION}"
PARALLEL_AGENTS="${PARALLEL_AGENTS}"
ENABLE_SUB_AGENTS="${ENABLE_SUB_AGENTS}"
CURSOR_BUDGET_LIMIT="${CURSOR_BUDGET_LIMIT}"
CURSOR_USAGE_FILE="${CURSOR_USAGE_FILE}"
EOF
  return 0
}

# Draw a box with title
draw_box() {
  local width=$1
  local title="$2"
  local title_len=${#title}
  local padding=$(( (width - title_len - 2) / 2 ))
  
  echo -ne "${BOLD}${MAGENTA}${BOX_TL}"
  printf "%*s" $((padding + title_len + 2)) "" | tr ' ' "${BOX_H}"
  echo -ne "${BOX_TR}${NC}\n"
  
  echo -ne "${BOLD}${MAGENTA}${BOX_V}${NC}"
  printf "%*s" $padding "" | tr ' ' ' '
  echo -ne "${BOLD}${title}${NC}"
  printf "%*s" $((width - padding - title_len - 2)) "" | tr ' ' ' '
  echo -ne "${BOLD}${MAGENTA}${BOX_V}${NC}\n"
  
  echo -ne "${BOLD}${MAGENTA}${BOX_BL}"
  printf "%*s" $width "" | tr ' ' "${BOX_H}"
  echo -ne "${BOX_BR}${NC}\n"
}

# Draw separator line
draw_separator() {
  local width=60
  echo -ne "${DIM}${BOX_L}"
  printf "%*s" $width "" | tr ' ' "${BOX_H}"
  echo -ne "${BOX_R}${NC}\n"
}

# Display configuration with selection
show_config() {
  clear
  
  # Header
  echo ""
  draw_box 62 "⚙️  Ralph Agent Configuration"
  echo ""
  
  # Configuration items
  local items=(
    "Prompt File"
    "CSV File"
    "Log Directory"
    "Max Companies"
    "Rows Per Session"
    "Parallel Agents"
    "Enable Sub-Agents"
    "Budget Limit"
    "Usage File"
  )
  
  local values=(
    "$PROMPT_FILE"
    "$CSV_FILE"
    "$LOG_DIR"
    "${MAX_COMPANIES}${NC} ${DIM}(${MAX_COMPANIES:-0} = unlimited)${NC}"
    "${CSV_ROWS_PER_SESSION}${NC} ${DIM}(rows processed per agent session)${NC}"
    "${PARALLEL_AGENTS}${NC} ${DIM}(concurrent agent instances)${NC}"
    "${ENABLE_SUB_AGENTS}${NC} ${DIM}(allow agent to spawn sub-agents)${NC}"
    "${CURSOR_BUDGET_LIMIT}${NC} ${DIM}(${CURSOR_BUDGET_LIMIT:-0} = unlimited)${NC}"
    "$CURSOR_USAGE_FILE"
  )
  
  for i in "${!items[@]}"; do
    local idx=$((i + 1))
    local item="${items[$i]}"
    local value="${values[$i]}"
    
    if [[ $idx -eq $selected_item ]]; then
      echo -ne "  ${BOLD}${GREEN}▶${NC} ${BOLD}${CYAN}${idx}.${NC} ${BOLD}${item}:${NC} "
    else
      echo -ne "  ${DIM} ${NC} ${CYAN}${idx}.${NC} ${item}: "
    fi
    
    # Truncate long values for display
    local display_value="$value"
    if [[ ${#display_value} -gt 40 ]]; then
      display_value="${display_value:0:37}..."
    fi
    echo -e "${BOLD}${display_value}${NC}"
  done
  
  echo ""
  draw_separator
  echo ""
  
  # Action buttons
  local actions=(
    "Save Configuration"
    "Reset to Defaults"
    "Validate Config"
    "Show Help"
    "Quit"
  )
  
  local action_keys=("s" "r" "v" "h" "q")
  local action_start=10
  
  echo -e "  ${BOLD}Actions:${NC}"
  for i in "${!actions[@]}"; do
    local idx=$((i + action_start))
    local action="${actions[$i]}"
    local key="${action_keys[$i]}"
    
    if [[ $idx -eq $selected_item ]]; then
      echo -e "  ${BOLD}${GREEN}▶${NC} ${BOLD}${CYAN}[${key}]${NC} ${BOLD}${action}${NC}"
    else
      echo -e "  ${DIM} ${NC} ${CYAN}[${key}]${NC} ${action}"
    fi
  done
  
  echo ""
  draw_separator
  echo ""
  echo -e "  ${DIM}Use ↑↓ arrow keys or numbers to navigate, Enter to select${NC}"
  echo -e "  ${DIM}Press ${BOLD}q${NC}${DIM} to quit${NC}"
  echo ""
}

# Edit a setting
edit_setting() {
  local setting_num=$1
  local new_value=""
  
  clear
  draw_box 62 "Edit Configuration"
  echo ""
  
  case $setting_num in
    1)
      echo -e "  ${BOLD}Prompt File${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${PROMPT_FILE}${NC}${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new prompt file path:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        if [[ -f "$new_value" ]]; then
          PROMPT_FILE="$new_value"
          echo -e "  ${GREEN}✓ Updated successfully${NC}"
        else
          echo -e "  ${RED}✗ File not found: $new_value${NC}"
          echo -e "  ${YELLOW}Press Enter to continue...${NC}"
          read -r
          return 1
        fi
      fi
      ;;
    2)
      echo -e "  ${BOLD}CSV File${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${CSV_FILE}${NC}${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new CSV file path:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        if [[ -f "$new_value" ]]; then
          CSV_FILE="$new_value"
          echo -e "  ${GREEN}✓ Updated successfully${NC}"
        else
          echo -e "  ${RED}✗ File not found: $new_value${NC}"
          echo -e "  ${YELLOW}Press Enter to continue...${NC}"
          read -r
          return 1
        fi
      fi
      ;;
    3)
      echo -e "  ${BOLD}Log Directory${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${LOG_DIR}${NC}${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new log directory path:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        LOG_DIR="$new_value"
        # Update CURSOR_USAGE_FILE if it's in the old log dir
        if [[ "$CURSOR_USAGE_FILE" == *"$DEFAULT_LOG_DIR"* ]]; then
          CURSOR_USAGE_FILE="${LOG_DIR}/cursor_usage.json"
        fi
        echo -e "  ${GREEN}✓ Updated successfully${NC}"
      fi
      ;;
    4)
      echo -e "  ${BOLD}Max Companies${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${MAX_COMPANIES}${NC}${NC}"
      echo -e "  ${DIM}Set to 0 for unlimited${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new value:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
          MAX_COMPANIES="$new_value"
          echo -e "  ${GREEN}✓ Updated successfully${NC}"
        else
          echo -e "  ${RED}✗ Invalid input. Must be a number.${NC}"
          echo -e "  ${YELLOW}Press Enter to continue...${NC}"
          read -r
          return 1
        fi
      fi
      ;;
    5)
      echo -e "  ${BOLD}Rows Per Session${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${CSV_ROWS_PER_SESSION}${NC}${NC}"
      echo -e "  ${DIM}Number of CSV rows to process per agent session${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new value:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        if [[ "$new_value" =~ ^[0-9]+$ && $new_value -gt 0 ]]; then
          CSV_ROWS_PER_SESSION="$new_value"
          echo -e "  ${GREEN}✓ Updated successfully${NC}"
        else
          echo -e "  ${RED}✗ Invalid input. Must be a positive number.${NC}"
          echo -e "  ${YELLOW}Press Enter to continue...${NC}"
          read -r
          return 1
        fi
      fi
      ;;
    6)
      echo -e "  ${BOLD}Parallel Agents${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${PARALLEL_AGENTS}${NC}${NC}"
      echo -e "  ${DIM}Number of concurrent agent instances to run${NC}"
      echo -e "  ${DIM}Set to 1 for sequential processing${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new value:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        if [[ "$new_value" =~ ^[0-9]+$ && $new_value -gt 0 ]]; then
          PARALLEL_AGENTS="$new_value"
          echo -e "  ${GREEN}✓ Updated successfully${NC}"
        else
          echo -e "  ${RED}✗ Invalid input. Must be a positive number.${NC}"
          echo -e "  ${YELLOW}Press Enter to continue...${NC}"
          read -r
          return 1
        fi
      fi
      ;;
    7)
      echo -e "  ${BOLD}Enable Sub-Agents${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${ENABLE_SUB_AGENTS}${NC}${NC}"
      echo -e "  ${DIM}Allow agents to spawn sub-agents for parallel research${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new value (true/false):${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        if [[ "$new_value" =~ ^(true|false|TRUE|FALSE)$ ]]; then
          ENABLE_SUB_AGENTS="$new_value"
          echo -e "  ${GREEN}✓ Updated successfully${NC}"
        else
          echo -e "  ${RED}✗ Invalid input. Must be 'true' or 'false'.${NC}"
          echo -e "  ${YELLOW}Press Enter to continue...${NC}"
          read -r
          return 1
        fi
      fi
      ;;
    8)
      echo -e "  ${BOLD}Budget Limit${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${CURSOR_BUDGET_LIMIT}${NC}${NC}"
      echo -e "  ${DIM}Set to 0 for unlimited${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new value:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
          CURSOR_BUDGET_LIMIT="$new_value"
          echo -e "  ${GREEN}✓ Updated successfully${NC}"
        else
          echo -e "  ${RED}✗ Invalid input. Must be a number.${NC}"
          echo -e "  ${YELLOW}Press Enter to continue...${NC}"
          read -r
          return 1
        fi
      fi
      ;;
    9)
      echo -e "  ${BOLD}Usage File${NC}"
      echo -e "  ${DIM}Current: ${BOLD}${CURSOR_USAGE_FILE}${NC}${NC}"
      echo ""
      echo -e "  ${YELLOW}Enter new usage file path:${NC} "
      read -r new_value
      if [[ -n "$new_value" ]]; then
        CURSOR_USAGE_FILE="$new_value"
        echo -e "  ${GREEN}✓ Updated successfully${NC}"
      fi
      ;;
  esac
  
  sleep 0.8
  return 0
}

# Validate configuration
validate_config() {
  local errors=0
  
  clear
  draw_box 62 "Validate Configuration"
  echo ""
  
  echo -e "  ${BOLD}Checking configuration...${NC}"
  echo ""
  
  # Check prompt file
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo -e "  ${RED}✗${NC} Prompt file not found: ${BOLD}${PROMPT_FILE}${NC}"
    ((errors++))
  else
    echo -e "  ${GREEN}✓${NC} Prompt file exists: ${BOLD}${PROMPT_FILE}${NC}"
  fi
  
  # Check CSV file
  if [[ ! -f "$CSV_FILE" ]]; then
    echo -e "  ${RED}✗${NC} CSV file not found: ${BOLD}${CSV_FILE}${NC}"
    ((errors++))
  else
    local row_count=$(tail -n +2 "$CSV_FILE" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✓${NC} CSV file exists: ${BOLD}${CSV_FILE}${NC} ${DIM}(${row_count} companies)${NC}"
  fi
  
  # Check log directory
  if [[ ! -d "$LOG_DIR" ]]; then
    echo -e "  ${YELLOW}⚠${NC} Log directory doesn't exist: ${BOLD}${LOG_DIR}${NC}"
    echo -e "     ${DIM}(Will be created automatically)${NC}"
  else
    echo -e "  ${GREEN}✓${NC} Log directory exists: ${BOLD}${LOG_DIR}${NC}"
  fi
  
  # Check numeric values
  if [[ ! "$MAX_COMPANIES" =~ ^[0-9]+$ ]]; then
    echo -e "  ${RED}✗${NC} Invalid Max Companies: ${BOLD}${MAX_COMPANIES}${NC}"
    ((errors++))
  else
    if [[ $MAX_COMPANIES -eq 0 ]]; then
      echo -e "  ${GREEN}✓${NC} Max Companies: ${BOLD}Unlimited${NC}"
    else
      echo -e "  ${GREEN}✓${NC} Max Companies: ${BOLD}${MAX_COMPANIES}${NC}"
    fi
  fi
  
  if [[ ! "$CURSOR_BUDGET_LIMIT" =~ ^[0-9]+$ ]]; then
    echo -e "  ${RED}✗${NC} Invalid Budget Limit: ${BOLD}${CURSOR_BUDGET_LIMIT}${NC}"
    ((errors++))
  else
    if [[ $CURSOR_BUDGET_LIMIT -eq 0 ]]; then
      echo -e "  ${GREEN}✓${NC} Budget Limit: ${BOLD}Unlimited${NC}"
    else
      echo -e "  ${GREEN}✓${NC} Budget Limit: ${BOLD}${CURSOR_BUDGET_LIMIT}${NC}"
    fi
  fi
  
  echo ""
  draw_separator
  echo ""
  
  if [[ $errors -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✓ Configuration is valid!${NC}${NC}"
  else
    echo -e "  ${RED}${BOLD}✗ Found ${errors} error(s)${NC}${NC}"
  fi
  
  echo ""
  echo -e "  ${YELLOW}Press Enter to continue...${NC}"
  read -r
}

# Reset to defaults
reset_config() {
  clear
  draw_box 62 "Reset Configuration"
  echo ""
  echo -e "  ${YELLOW}Reset all settings to defaults?${NC}"
  echo ""
  echo -e "  ${CYAN}[y]${NC} Yes"
  echo -e "  ${CYAN}[n]${NC} No (Cancel)"
  echo ""
  echo -ne "  ${BOLD}Your choice:${NC} "
  read -r confirm
  
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    PROMPT_FILE="$DEFAULT_PROMPT_FILE"
    CSV_FILE="$DEFAULT_CSV_FILE"
    LOG_DIR="$DEFAULT_LOG_DIR"
    MAX_COMPANIES="$DEFAULT_MAX_COMPANIES"
    CSV_ROWS_PER_SESSION="$DEFAULT_CSV_ROWS_PER_SESSION"
    PARALLEL_AGENTS="$DEFAULT_PARALLEL_AGENTS"
    ENABLE_SUB_AGENTS="$DEFAULT_ENABLE_SUB_AGENTS"
    CURSOR_BUDGET_LIMIT="$DEFAULT_CURSOR_BUDGET_LIMIT"
    CURSOR_USAGE_FILE="$DEFAULT_CURSOR_USAGE_FILE"
    echo ""
    echo -e "  ${GREEN}✓ Configuration reset to defaults${NC}"
    sleep 1.5
  fi
}

# Show help
show_help() {
  clear
  draw_box 62 "📖 Help & Documentation"
  echo ""
  
  echo -e "  ${BOLD}Configuration Options:${NC}"
  echo ""
  echo -e "  ${CYAN}Prompt File${NC}"
  echo -e "    The markdown file containing the agent prompt instructions."
  echo -e "    ${DIM}Default: ${BOLD}PROMPT.md${NC}${NC}"
  echo ""
  echo -e "  ${CYAN}CSV File${NC}"
  echo -e "    The CSV file containing company data to process."
  echo -e "    ${DIM}Default: ${BOLD}blue-collar-companies.csv${NC}${NC}"
  echo ""
  echo -e "  ${CYAN}Log Directory${NC}"
  echo -e "    Directory where log files and usage tracking are stored."
  echo -e "    ${DIM}Default: ${BOLD}.logs${NC}${NC}"
  echo ""
  echo -e "  ${CYAN}Max Companies${NC}"
  echo -e "    Maximum number of companies to process in one batch."
  echo -e "    Set to ${BOLD}0${NC} for unlimited processing."
  echo -e "    ${DIM}Default: ${BOLD}10${NC}${NC}"
  echo ""
  echo -e "  ${CYAN}Rows Per Session${NC}"
  echo -e "    Number of CSV rows to process per agent session."
  echo -e "    Higher values process more companies per agent instance."
  echo -e "    ${DIM}Default: ${BOLD}1${NC}${NC}"
  echo ""
  echo -e "  ${CYAN}Parallel Agents${NC}"
  echo -e "    Number of concurrent agent instances to run."
  echo -e "    Set to 1 for sequential processing, higher for parallel execution."
  echo -e "    ${DIM}Default: ${BOLD}1${NC}${NC}"
  echo ""
  echo -e "  ${CYAN}Enable Sub-Agents${NC}"
  echo -e "    Allow agents to spawn sub-agents for parallel research tasks."
  echo -e "    Enables parallel tool calling and concurrent research operations."
  echo -e "    ${DIM}Default: ${BOLD}true${NC}${NC}"
  echo ""
  echo -e "  ${CYAN}Budget Limit${NC}"
  echo -e "    Maximum number of API calls allowed."
  echo -e "    Set to ${BOLD}0${NC} for unlimited API calls."
  echo -e "    ${DIM}Default: ${BOLD}0${NC} (unlimited)${NC}"
  echo ""
  echo -e "  ${CYAN}Usage File${NC}"
  echo -e "    File path for tracking API usage and statistics."
  echo -e "    ${DIM}Default: ${BOLD}.logs/cursor_usage.json${NC}${NC}"
  echo ""
  draw_separator
  echo ""
  echo -e "  ${BOLD}Navigation:${NC}"
  echo -e "    ${CYAN}↑↓${NC} Arrow keys to navigate"
  echo -e "    ${CYAN}1-6${NC} Select configuration item"
  echo -e "    ${CYAN}Enter${NC} Edit selected item"
  echo -e "    ${CYAN}s${NC} Save configuration"
  echo -e "    ${CYAN}q${NC} Quit"
  echo ""
  echo -e "  ${YELLOW}Press Enter to return...${NC}"
  read -r
}

# Handle action
handle_action() {
      case $selected_item in
    10) # Save
      if save_config; then
        clear
        draw_box 62 "Save Configuration"
        echo ""
        echo -e "  ${GREEN}${BOLD}✓ Configuration saved successfully!${NC}${NC}"
        echo ""
        echo -e "  ${DIM}Saved to: ${BOLD}${CONFIG_FILE}${NC}${NC}"
        echo ""
        echo -e "  ${YELLOW}Press Enter to continue...${NC}"
        read -r
      fi
      ;;
    11) # Reset
      reset_config
      ;;
    12) # Validate
      validate_config
      ;;
    13) # Help
      show_help
      ;;
    14) # Quit
      clear
      echo ""
      draw_box 62 "Exit"
      echo ""
      echo -e "  ${YELLOW}Quitting without saving changes...${NC}"
      echo ""
      echo -e "  ${DIM}Tip: Use 's' to save before quitting${NC}"
      echo ""
      sleep 1
      exit 0
      ;;
  esac
}

# Read arrow keys
read_key() {
  local key
  local key2
  local key3
  
  # Read first character
  read -rsn1 key
  
  # Check for escape sequence (arrow keys)
  if [[ "$key" == $'\x1b' ]]; then
    read -rsn1 key2
    if [[ "$key2" == '[' ]]; then
      read -rsn1 key3
      case "$key3" in
        'A') echo "UP" ;;
        'B') echo "DOWN" ;;
        *) echo "$key$key2$key3" ;;
      esac
    else
      echo "$key$key2"
    fi
  else
    # Regular key
    case "$key" in
      $'\x0a'|$'\x0d') echo "ENTER" ;;
      'q'|'Q') echo "QUIT" ;;
      's'|'S') echo "SAVE" ;;
      'r'|'R') echo "RESET" ;;
      'v'|'V') echo "VALIDATE" ;;
      'h'|'H') echo "HELP" ;;
      [1-6]) echo "NUM_$key" ;;
      *) echo "$key" ;;
    esac
  fi
}

# Main menu loop
main() {
  load_config
  
  # Enable raw mode for better key handling
  stty -echo -icanon time 0 min 0 2>/dev/null || true
  
  while true; do
    show_config
    
    # Read input
    local input=$(read_key)
    
    case "$input" in
      "UP")
        if [[ $selected_item -gt 1 ]]; then
          ((selected_item--))
        fi
        ;;
      "DOWN")
        if [[ $selected_item -lt 14 ]]; then
          ((selected_item++))
        fi
        ;;
      "ENTER")
        if [[ $selected_item -le 9 ]]; then
          edit_setting $selected_item
        else
          handle_action
        fi
        ;;
      "NUM_1"|"NUM_2"|"NUM_3"|"NUM_4"|"NUM_5"|"NUM_6"|"NUM_7"|"NUM_8"|"NUM_9")
        local num="${input#NUM_}"
        edit_setting "$num"
        ;;
      "SAVE")
        selected_item=7
        handle_action
        ;;
      "RESET")
        selected_item=8
        handle_action
        ;;
      "VALIDATE")
        selected_item=9
        handle_action
        ;;
      "HELP")
        selected_item=10
        handle_action
        ;;
      "QUIT")
        selected_item=11
        handle_action
        ;;
    esac
  done
}

# Restore terminal settings on exit
cleanup() {
  stty echo icanon 2>/dev/null || true
  clear
  exit 0
}
trap cleanup EXIT INT TERM

# Handle command line arguments
case "${1:-}" in
  --show|-s|show)
    load_config
    echo ""
    draw_box 62 "Current Configuration"
    echo ""
    echo -e "  Prompt File:        ${BOLD}${PROMPT_FILE}${NC}"
    echo -e "  CSV File:           ${BOLD}${CSV_FILE}${NC}"
    echo -e "  Log Directory:      ${BOLD}${LOG_DIR}${NC}"
    echo -e "  Max Companies:      ${BOLD}${MAX_COMPANIES}${NC}"
    echo -e "  Budget Limit:        ${BOLD}${CURSOR_BUDGET_LIMIT}${NC}"
    echo -e "  Usage File:         ${BOLD}${CURSOR_USAGE_FILE}${NC}"
    echo ""
    exit 0
    ;;
  --help|-h|help)
    echo "Ralph Agent Configuration Manager"
    echo ""
    echo "Usage:"
    echo "  ./ralph-config.sh           Interactive configuration UI"
    echo "  ./ralph-config.sh --show    Show current configuration"
    echo "  ./ralph-config.sh --help    Show this help message"
    echo ""
    exit 0
    ;;
  "")
    # No arguments - run interactive UI
    main
    ;;
  *)
    echo "Unknown option: $1"
    echo "Use --help for usage information"
    exit 1
    ;;
esac
