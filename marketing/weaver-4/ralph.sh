#!/bin/bash
set -uo pipefail

# Prevent sleep while running (re-exec under caffeinate if not already)
if [[ -z "${CAFFEINATED:-}" ]]; then
  export CAFFEINATED=1
  exec caffeinate -dims "$0" "$@"
fi

# Load configuration from file if it exists
CONFIG_FILE=".ralph.config"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi

# Configuration with defaults (can be overridden by config file or environment)
PROMPT_FILE="${1:-${PROMPT_FILE:-PROMPT.md}}"
CSV_FILE="${CSV_FILE:-blue-collar-companies.csv}"
LOG_DIR="${LOG_DIR:-.logs}"
MAX_COMPANIES="${MAX_COMPANIES:-10}"  # Set to 0 for unlimited, or N to process N companies
CSV_ROWS_PER_SESSION="${CSV_ROWS_PER_SESSION:-1}"  # Number of CSV rows to process per agent session
PARALLEL_AGENTS="${PARALLEL_AGENTS:-1}"  # Number of parallel agent instances to run
ENABLE_SUB_AGENTS="${ENABLE_SUB_AGENTS:-true}"  # Allow agent to spawn sub-agents for parallel research
CURSOR_BUDGET_LIMIT="${CURSOR_BUDGET_LIMIT:-0}"  # Set budget limit (0 = unlimited)
CURSOR_USAGE_FILE="${CURSOR_USAGE_FILE:-$LOG_DIR/cursor_usage.json}"  # Track usage
timer_pid=""
spinner_pid=""
parallel_pids=()

# Usage tracking
total_api_calls=0
total_tokens_estimated=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Animation characters
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
DOTS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
BAR_CHARS="█▉▊▋▌▍▎▏"

# Spinner animation function
spinner() {
  local pid=$1
  local message="$2"
  local spinstr="${SPINNER_CHARS}"
  local delay=0.1
  
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf "\r${CYAN}%s${NC} %s" "${spinstr:0:1}" "$message" >&2
    spinstr=$temp${spinstr%"$temp"}
    sleep "$delay"
  done
  printf "\r${NC}" >&2
}

# Progress bar function
progress_bar() {
  local current=$1
  local total=$2
  local width=40
  local percent=0
  local filled=0
  local empty=$width
  
  if [[ $total -gt 0 ]]; then
    percent=$((current * 100 / total))
    filled=$((current * width / total))
    empty=$((width - filled))
  fi
  
  # Clear line and print progress bar
  printf "\r${NC}${GREEN}["
  printf "%${filled}s" | tr ' ' '█'
  printf "%${empty}s" | tr ' ' '░'
  printf "]${NC} ${BOLD}%d%%${NC} (%d/%d)${NC}" "$percent" "$current" "$total" >&2
}

# Log function with timestamp
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp=$(date '+%H:%M:%S')
  local color=""
  
  case "$level" in
    INFO)  color="${BLUE}" ;;
    SUCCESS) color="${GREEN}" ;;
    WARN)  color="${YELLOW}" ;;
    ERROR) color="${RED}" ;;
    STEP)  color="${CYAN}" ;;
    *)     color="${NC}" ;;
  esac
  
  echo -e "${color}[${timestamp}]${NC} ${BOLD}${color}${level}${NC} → ${message}${NC}" >&2
}

# Detailed status logging
log_status() {
  local step="$1"
  local details="$2"
  log "STEP" "${step}"
  [[ -n "$details" ]] && echo -e "   ${CYAN}${details}${NC}" >&2
}

# Grouped status logging - displays multiple items under one header
log_group() {
  local group_name="$1"
  shift
  local items=("$@")
  local timestamp=$(date '+%H:%M:%S')
  
  echo -e "${CYAN}[${timestamp}]${NC} ${BOLD}${CYAN}STEP${NC} → ${BOLD}${group_name}${NC}" >&2
  for item in "${items[@]}"; do
    echo -e "   ${CYAN}${item}${NC}" >&2
  done
}

# Compact grouped status - shows items on same line or compact format
log_group_compact() {
  local group_name="$1"
  shift
  local items=("$@")
  local timestamp=$(date '+%H:%M:%S')
  local first_item="${items[0]}"
  shift
  local remaining_items=("$@")
  
  echo -e "${CYAN}[${timestamp}]${NC} ${BOLD}${CYAN}STEP${NC} → ${BOLD}${group_name}${NC}" >&2
  echo -e "   ${CYAN}${first_item}${NC}" >&2
  for item in "${remaining_items[@]}"; do
    echo -e "   ${CYAN}${item}${NC}" >&2
  done
}

cleanup() {
  local exit_code=${1:-0}
  printf "\n" >&2
  log "INFO" "Shutting down gracefully..."
  [[ -n "$timer_pid" ]] && kill "$timer_pid" 2>/dev/null
  [[ -n "$spinner_pid" ]] && kill "$spinner_pid" 2>/dev/null
  wait "$timer_pid" "$spinner_pid" 2>/dev/null
  exit "$exit_code"
}
trap 'cleanup $?' SIGINT SIGTERM

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE not found" >&2
  exit 1
fi

if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: $CSV_FILE not found" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

# Function to initialize usage tracking
init_usage_tracking() {
  mkdir -p "$(dirname "$CURSOR_USAGE_FILE")"
  if [[ ! -f "$CURSOR_USAGE_FILE" ]]; then
    # Enhanced structure with separate tracking for agents/sub-agents and token spend vs context windows
    cat > "$CURSOR_USAGE_FILE" << 'EOF'
{
  "start_time": 0,
  "api_calls": 0,
  "token_spend": {
    "total_estimated": 0,
    "main_agents": 0,
    "sub_agents": 0
  },
  "context_windows": {
    "main_agents": {
      "max_used": 0,
      "total_sessions": 0,
      "sessions": []
    },
    "sub_agents": {
      "max_used": 0,
      "total_sessions": 0,
      "sessions": []
    },
    "overall_max": 0
  },
  "companies_processed": 0
}
EOF
    # Set start_time
    if command -v jq >/dev/null 2>&1; then
      local temp_file
      temp_file=$(mktemp "${CURSOR_USAGE_FILE}.tmp.XXXXXX" 2>/dev/null) || temp_file="${CURSOR_USAGE_FILE}.tmp"
      jq --argjson start_time "$(date +%s)" '.start_time = $start_time' "$CURSOR_USAGE_FILE" > "$temp_file" && mv "$temp_file" "$CURSOR_USAGE_FILE" || rm -f "$temp_file"
    else
      # Fallback: simple replacement
      local start_time
      start_time=$(date +%s)
      sed -i.bak "s/\"start_time\": 0/\"start_time\": $start_time/" "$CURSOR_USAGE_FILE" 2>/dev/null || \
        sed -i '' "s/\"start_time\": 0/\"start_time\": $start_time/" "$CURSOR_USAGE_FILE" 2>/dev/null || true
      rm -f "${CURSOR_USAGE_FILE}.bak" 2>/dev/null || true
    fi
  else
    # Migrate old format to new format if needed
    if command -v jq >/dev/null 2>&1; then
      # Check if old format (has tokens_estimated at root level)
      if jq -e '.tokens_estimated != null' "$CURSOR_USAGE_FILE" >/dev/null 2>&1; then
        # Migrate old format
        local old_tokens=$(jq -r '.tokens_estimated // 0' "$CURSOR_USAGE_FILE")
        local old_context=$(jq -r '.context_window_max // 0' "$CURSOR_USAGE_FILE")
        jq --argjson tokens "$old_tokens" \
           --argjson context "$old_context" \
           '. + {
             token_spend: {
               total_estimated: $tokens,
               main_agents: $tokens,
               sub_agents: 0
             },
             context_windows: {
               main_agents: {
                 max_used: $context,
                 total_sessions: 0,
                 sessions: []
               },
               sub_agents: {
                 max_used: 0,
                 total_sessions: 0,
                 sessions: []
               },
               overall_max: $context
             }
           } | del(.tokens_estimated, .context_window_max)' \
           "$CURSOR_USAGE_FILE" > "${CURSOR_USAGE_FILE}.tmp" && mv "${CURSOR_USAGE_FILE}.tmp" "$CURSOR_USAGE_FILE" || rm -f "${CURSOR_USAGE_FILE}.tmp"
      fi
    fi
  fi
}

init_usage_tracking

# Function to get next row index from PROMPT.md
get_next_row_index() {
  local next_index
  # Extract the PROGRESS_LOG section and get the Next_Row_Index value
  next_index=$(sed -n '/\[PROGRESS_LOG\]/,/\[\/PROGRESS_LOG\]/p' "$PROMPT_FILE" | \
    grep "^Next_Row_Index:" | \
    awk -F: '{print $2}' | \
    tr -d ' ' | \
    head -1)
  echo "${next_index:-0}"
}

# Function to get total rows in CSV (excluding header)
get_total_rows() {
  local total
  if [[ ! -f "$CSV_FILE" ]]; then
    echo "0"
    return 1
  fi
  total=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
  echo "${total:-0}"
}

# Function to check if processing is complete
is_complete() {
  grep -q "Status: COMPLETED" "$PROMPT_FILE" 2>/dev/null
}

# Function to get company name at row index
get_company_name() {
  local row_index=$1
  local company_name
  
  if [[ ! -f "$CSV_FILE" ]]; then
    echo "" >&2
    return 1
  fi
  
  # Row index is 0-based, CSV row is index+2 (header + 1-based)
  company_name=$(awk -F',' -v idx="$((row_index + 2))" 'NR==idx {print $1}' "$CSV_FILE" 2>/dev/null)
  echo "${company_name:-}"
}

# Function to get Cursor user info
get_cursor_user() {
  local user_info
  user_info=$(cursor agent whoami 2>/dev/null | grep -i "logged in" | sed 's/.*Logged in as //' | tr -d '\n' || echo "unknown")
  echo "$user_info"
}

# Function to get Cursor version
get_cursor_version() {
  local version
  version=$(cursor --status 2>/dev/null | grep "^Version:" | sed 's/Version:[ ]*//' | head -1 || echo "unknown")
  echo "$version"
}

# Function to update usage tracking with enhanced context window tracking
# Parameters:
#   $1: api_calls (number of agent invocations)
#   $2: tokens_estimated (estimated token spend for API costs)
#   $3: companies (number of companies processed)
#   $4: context_window_used (context window tokens used - for memory/limits)
#   $5: agent_type ("main" or "sub", default: "main")
#   $6: session_id (optional: unique session identifier)
#   $7: context_window_max (optional: max context window size if known)
update_usage() {
  local api_calls=$1
  local tokens_estimated=$2
  local companies=$3
  local context_window_used="${4:-0}"
  local agent_type="${5:-main}"
  local session_id="${6:-}"
  local context_window_max="${7:-0}"
  
  if [[ -f "$CURSOR_USAGE_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
      # Use jq for proper JSON manipulation
      local temp_file
      temp_file=$(mktemp "${CURSOR_USAGE_FILE}.tmp.XXXXXX" 2>/dev/null) || temp_file="${CURSOR_USAGE_FILE}.tmp"
      
      # Update API calls
      jq --argjson calls "$api_calls" '.api_calls += $calls' "$CURSOR_USAGE_FILE" > "$temp_file" && mv "$temp_file" "$CURSOR_USAGE_FILE" || rm -f "$temp_file"
      
      # Update token spend (separate from context windows)
      if [[ "$agent_type" == "sub" ]]; then
        jq --argjson tokens "$tokens_estimated" \
           '.token_spend.total_estimated += $tokens | .token_spend.sub_agents += $tokens' \
           "$CURSOR_USAGE_FILE" > "$temp_file" && mv "$temp_file" "$CURSOR_USAGE_FILE" || rm -f "$temp_file"
      else
        jq --argjson tokens "$tokens_estimated" \
           '.token_spend.total_estimated += $tokens | .token_spend.main_agents += $tokens' \
           "$CURSOR_USAGE_FILE" > "$temp_file" && mv "$temp_file" "$CURSOR_USAGE_FILE" || rm -f "$temp_file"
      fi
      
      # Update companies processed
      jq --argjson comp "$companies" '.companies_processed += $comp' "$CURSOR_USAGE_FILE" > "$temp_file" && mv "$temp_file" "$CURSOR_USAGE_FILE" || rm -f "$temp_file"
      
      # Update context windows (separate from token spend)
      if [[ "$context_window_used" -gt 0 ]]; then
        local agent_key="main_agents"
        if [[ "$agent_type" == "sub" ]]; then
          agent_key="sub_agents"
        fi
        
        local timestamp=$(date +%s)
        
        # Update context window tracking using jq to properly construct JSON
        jq --argjson used "$context_window_used" \
           --argjson max "$context_window_max" \
           --arg key "$agent_key" \
           --argjson timestamp "$timestamp" \
           --arg session_id "${session_id}" \
           '.context_windows[$key].total_sessions += 1 |
            .context_windows[$key].sessions += [{
              timestamp: $timestamp,
              context_used: $used,
              context_max: $max,
              session_id: $session_id
            }] |
            (if .context_windows[$key].max_used < $used then .context_windows[$key].max_used = $used else . end) |
            (if .context_windows.overall_max < $used then .context_windows.overall_max = $used else . end)' \
           "$CURSOR_USAGE_FILE" > "$temp_file" && mv "$temp_file" "$CURSOR_USAGE_FILE" || rm -f "$temp_file"
      fi
    else
      # Fallback: simple parsing without jq (limited functionality)
      log "WARN" "jq not available - using fallback tracking (limited context window details)"
      local current_calls
      local current_companies
      local start_time
      current_calls=$(grep -o '"api_calls"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "0")
      current_companies=$(grep -o '"companies_processed"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "0")
      start_time=$(grep -o '"start_time"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || date +%s)
      
      local new_calls=$((current_calls + api_calls))
      local new_companies=$((current_companies + companies))
      
      # Simple update (can't do complex JSON without jq)
      echo "{\"start_time\": $start_time, \"api_calls\": $new_calls, \"companies_processed\": $new_companies, \"note\": \"jq required for full tracking\"}" > "$CURSOR_USAGE_FILE"
    fi
  fi
}

# Function to get usage stats (backward compatible format)
# Returns: api_calls|total_tokens|companies|start_time|overall_max_context
get_usage_stats() {
  if [[ -f "$CURSOR_USAGE_FILE" ]]; then
    if command -v jq >/dev/null 2>&1; then
      local api_calls
      local tokens
      local companies
      local context_window
      local start_time
      api_calls=$(jq -r '.api_calls // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "0")
      # Try new format first, fallback to old format
      tokens=$(jq -r '.token_spend.total_estimated // .tokens_estimated // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "0")
      companies=$(jq -r '.companies_processed // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "0")
      context_window=$(jq -r '.context_windows.overall_max // .context_window_max // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "0")
      start_time=$(jq -r '.start_time // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || date +%s)
    else
      # Fallback: simple parsing without jq
      local api_calls
      local tokens
      local companies
      local context_window
      local start_time
      api_calls=$(grep -o '"api_calls"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "0")
      tokens=$(grep -oE '"(token_spend|tokens_estimated)"[^}]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
      companies=$(grep -o '"companies_processed"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "0")
      context_window=$(grep -oE '"(overall_max|context_window_max)"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' | head -1 || echo "0")
      start_time=$(grep -o '"start_time"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || date +%s)
    fi
    echo "$api_calls|$tokens|$companies|$start_time|$context_window"
  else
    echo "0|0|0|$(date +%s)|0"
  fi
}

# Function to get detailed context window stats
# Returns detailed breakdown of context window usage
get_context_window_stats() {
  if [[ -f "$CURSOR_USAGE_FILE" ]] && command -v jq >/dev/null 2>&1; then
    jq -c '{
      main_agents: {
        max_used: .context_windows.main_agents.max_used,
        total_sessions: .context_windows.main_agents.total_sessions,
        avg_used: (if .context_windows.main_agents.total_sessions > 0 then 
          ([.context_windows.main_agents.sessions[].context_used] | add / length) else 0 end)
      },
      sub_agents: {
        max_used: .context_windows.sub_agents.max_used,
        total_sessions: .context_windows.sub_agents.total_sessions,
        avg_used: (if .context_windows.sub_agents.total_sessions > 0 then 
          ([.context_windows.sub_agents.sessions[].context_used] | add / length) else 0 end)
      },
      overall_max: .context_windows.overall_max
    }' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "{}"
  else
    echo "{}"
  fi
}

# Function to log context window details
log_context_window_details() {
  if command -v jq >/dev/null 2>&1 && [[ -f "$CURSOR_USAGE_FILE" ]]; then
    local stats=$(get_context_window_stats)
    local main_max=$(echo "$stats" | jq -r '.main_agents.max_used // 0' 2>/dev/null || echo "0")
    local main_sessions=$(echo "$stats" | jq -r '.main_agents.total_sessions // 0' 2>/dev/null || echo "0")
    local main_avg=$(echo "$stats" | jq -r '.main_agents.avg_used // 0' 2>/dev/null || echo "0")
    local sub_max=$(echo "$stats" | jq -r '.sub_agents.max_used // 0' 2>/dev/null || echo "0")
    local sub_sessions=$(echo "$stats" | jq -r '.sub_agents.total_sessions // 0' 2>/dev/null || echo "0")
    local sub_avg=$(echo "$stats" | jq -r '.sub_agents.avg_used // 0' 2>/dev/null || echo "0")
    local overall_max=$(echo "$stats" | jq -r '.overall_max // 0' 2>/dev/null || echo "0")
    
    # Get token spend info
    local token_total=$(jq -r '.token_spend.total_estimated // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "0")
    local token_main=$(jq -r '.token_spend.main_agents // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "0")
    local token_sub=$(jq -r '.token_spend.sub_agents // 0' "$CURSOR_USAGE_FILE" 2>/dev/null || echo "0")
    
    if [[ $main_sessions -gt 0 ]] || [[ $sub_sessions -gt 0 ]]; then
      log "STEP" "Context Window Utilization"
      echo -e "   ${CYAN}Main Agents:${NC} Max: ${BOLD}${main_max}${NC} │ Avg: ${BOLD}$(printf "%.0f" "$main_avg")${NC} │ Sessions: ${BOLD}${main_sessions}${NC}" >&2
      if [[ $sub_sessions -gt 0 ]]; then
        echo -e "   ${CYAN}Sub-Agents:${NC}  Max: ${BOLD}${sub_max}${NC} │ Avg: ${BOLD}$(printf "%.0f" "$sub_avg")${NC} │ Sessions: ${BOLD}${sub_sessions}${NC}" >&2
      fi
      echo -e "   ${CYAN}Overall Max:${NC} ${BOLD}${overall_max}${NC} tokens" >&2
      
      log "STEP" "Token Spend (API Costs)"
      echo -e "   ${CYAN}Total:${NC} ${BOLD}${token_total}${NC} │ Main: ${BOLD}${token_main}${NC} │ Sub: ${BOLD}${token_sub}${NC}" >&2
      echo -e "   ${DIM}Note: Token spend (API costs) is separate from context window utilization (memory limits)${NC}" >&2
    fi
  fi
}

# Function to check budget limits
check_budget_limit() {
  if [[ $CURSOR_BUDGET_LIMIT -gt 0 ]]; then
    local usage_stats
    usage_stats=$(get_usage_stats)
    local api_calls=$(echo "$usage_stats" | cut -d'|' -f1)
    
    if [[ $api_calls -ge $CURSOR_BUDGET_LIMIT ]]; then
      log "WARN" "Budget limit reached: ${BOLD}${api_calls}${NC}/${BOLD}${CURSOR_BUDGET_LIMIT}${NC} API calls"
      return 1
    elif [[ $api_calls -ge $((CURSOR_BUDGET_LIMIT * 90 / 100)) ]]; then
      log "WARN" "Approaching budget limit: ${BOLD}${api_calls}${NC}/${BOLD}${CURSOR_BUDGET_LIMIT}${NC} API calls (90%)"
    fi
  fi
  return 0
}

# Function to estimate tokens (rough estimate based on prompt size)
estimate_tokens() {
  local prompt_file="$1"
  # Rough estimate: ~4 characters per token
  local chars=$(wc -c < "$prompt_file" 2>/dev/null || echo "0")
  local tokens=$((chars / 4))
  # Add overhead for response (estimate 2x input)
  echo "$((tokens * 3))"
}

# Function to extract context window usage from log file
# Returns: context_used|context_max|agent_type
# agent_type: "main" or "sub" (detected by log file name patterns or content)
extract_context_window() {
  local log_file="$1"
  local context_used=""
  local context_max=""
  local agent_type="main"
  
  # Detect agent type from log file name or content
  if [[ "$log_file" == *"sub-agent"* ]] || [[ "$log_file" == *"subagent"* ]] || \
     grep -qiE "(sub-agent|subagent|spawned agent)" "$log_file" 2>/dev/null; then
    agent_type="sub"
  fi
  
  if [[ -f "$log_file" ]]; then
    # Try multiple patterns that might appear in cursor agent logs
    # Look for patterns like "context: 1234/128000" or "tokens: 1234/128000"
    local context_line=$(grep -iE "(context|tokens? used|window|context window)" "$log_file" 2>/dev/null | \
      grep -oE "[0-9,]+[[:space:]]*/[[:space:]]*[0-9,]+" | head -1 | tr -d ',')
    
    if [[ -n "$context_line" && "$context_line" == *"/"* ]]; then
      # Extract used and max from pattern "used/max"
      context_used=$(echo "$context_line" | cut -d'/' -f1 | tr -d ' ')
      context_max=$(echo "$context_line" | cut -d'/' -f2 | tr -d ' ')
    else
      # Try to find just used tokens without max
      context_used=$(grep -oE "(context|tokens?)[[:space:]]*:[[:space:]]*[0-9,]+" "$log_file" 2>/dev/null | \
        grep -oE "[0-9,]+" | head -1 | tr -d ',')
    fi
  fi
  
  echo "${context_used:-0}|${context_max:-0}|${agent_type}"
}

# Function to get company names for a range of rows
get_company_names_range() {
  local start_index=$1
  local count=$2
  local names=()
  
  for ((i=0; i<count; i++)); do
    local row_index=$((start_index + i))
    if [[ $row_index -lt $total_rows ]]; then
      local name=$(get_company_name "$row_index")
      names+=("$name")
    fi
  done
  
  # Join names with comma
  local old_ifs="$IFS"
  IFS=','
  echo "${names[*]}"
  IFS="$old_ifs"
}

# Function to create a parallel prompt file with sub-agent instructions
create_parallel_prompt() {
  local base_prompt="$1"
  local parallel_prompt="$2"
  local rows_per_agent=$3
  
  # Read base prompt and inject parallel execution instructions
  if [[ -f "$base_prompt" ]]; then
    cat "$base_prompt" > "$parallel_prompt"
    
    # Append parallel execution instructions
    cat >> "$parallel_prompt" << 'PARALLEL_EOF'

---

# PARALLEL EXECUTION MODE

**CRITICAL: You are running in PARALLEL MODE. Optimize for speed by using parallel operations.**

## Parallel Tool Calling
- **Use parallel tool calls** when possible - make multiple web requests simultaneously
- **Batch operations** - Group related research tasks and execute them in parallel
- **Don't wait** for one tool to complete before starting another if they're independent

## Sub-Agent Spawning Strategy
For complex research tasks, you can spawn sub-agents using the `cursor agent` command:

1. **Identify parallelizable tasks**:
   - Financial data research (allabolag.se, ratsit.se)
   - Contact information gathering (LinkedIn, company websites)
   - Industry research and verification

2. **Spawn sub-agents** for independent research tasks:
   ```bash
   # Example: Spawn sub-agent for financial data
   cursor agent -p --force "Research financial data for [Company Name] from allabolag.se and ratsit.se. Extract: revenue, employees, year founded. Output JSON."
   
   # Example: Spawn sub-agent for contact info
   cursor agent -p --force "Find contact information for [Company Name]: email, phone, key personnel. Search LinkedIn and company website. Output JSON."
   ```

3. **Coordinate results**: Collect results from sub-agents and merge into final CSV update

## Optimization Guidelines
- **Concurrent web requests**: Make multiple browser requests simultaneously when researching different aspects
- **Batch CSV updates**: Update multiple rows in one operation when possible
- **Cache results**: Reuse data from previous searches when applicable
- **Prioritize speed**: Complete research faster by parallelizing independent tasks

## Rate Limiting in Parallel Mode
- Still respect rate limits, but you can make requests to **different domains** simultaneously
- Use parallel requests for: allabolag.se + ratsit.se + LinkedIn (different domains = OK)
- Sequential requests still required for same domain (allabolag.se → allabolag.se)

PARALLEL_EOF
  else
    echo "Error: Base prompt file not found: $base_prompt" >&2
    return 1
  fi
}

# Function to run a single agent instance in parallel
run_parallel_agent() {
  local agent_id=$1
  local start_index=$2
  local rows_to_process=$3
  local log_file="$4"
  local prompt_file="$5"
  
  # Create a temporary prompt file for this agent instance
  local agent_prompt="${prompt_file}.agent${agent_id}"
  
  # Modify prompt to include specific row range
  if [[ -f "$prompt_file" ]]; then
    # Create a copy with agent-specific instructions
    sed "s/Next_Row_Index: [0-9]*/Next_Row_Index: ${start_index}/" "$prompt_file" > "$agent_prompt"
    
    # Add agent-specific instructions
    cat >> "$agent_prompt" << AGENT_EOF

---
# AGENT INSTANCE ${agent_id}
Processing rows ${start_index} to $((start_index + rows_to_process - 1))
Focus on speed and parallel operations.
AGENT_EOF
  fi
  
  # Run agent
  cursor agent -p --force --output-format text "$agent_prompt" > "$log_file" 2>&1
  local exit_code=$?
  
  # Cleanup
  rm -f "$agent_prompt"
  
  return $exit_code
}


company_count=0
total_rows=$(get_total_rows)
batch_start_time=$(date +%s)

echo "" >&2
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}" >&2
echo -e "${BOLD}${MAGENTA}║${NC}  ${BOLD}🚀 Corporate Data Enrichment Agent - Batch Processing${NC}  ${BOLD}${MAGENTA}║${NC}" >&2
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}" >&2
echo "" >&2

log "INFO" "Initializing batch processing..."

# Configuration group - all items together
log_group "Configuration" \
  "Prompt file: ${BOLD}${PROMPT_FILE}${NC}" \
  "CSV file: ${BOLD}${CSV_FILE}${NC}" \
  "Log directory: ${BOLD}${LOG_DIR}${NC}"

# Statistics and Limits together
log "STEP" "Statistics & Limits"
if [[ $MAX_COMPANIES -gt 0 ]]; then
  echo -e "   ${CYAN}Total companies: ${BOLD}${total_rows}${NC} │ Max to process: ${BOLD}${MAX_COMPANIES}${NC} │ Rows per session: ${BOLD}${CSV_ROWS_PER_SESSION}${NC} │ Parallel agents: ${BOLD}${PARALLEL_AGENTS}${NC} │ Sub-agents: ${BOLD}${ENABLE_SUB_AGENTS}${NC}${NC}" >&2
else
  echo -e "   ${CYAN}Total companies: ${BOLD}${total_rows}${NC} │ Processing all remaining │ Rows per session: ${BOLD}${CSV_ROWS_PER_SESSION}${NC} │ Parallel agents: ${BOLD}${PARALLEL_AGENTS}${NC} │ Sub-agents: ${BOLD}${ENABLE_SUB_AGENTS}${NC}${NC}" >&2
fi

# Cursor info - get values first, then display together
cursor_user=$(get_cursor_user)
cursor_version=$(get_cursor_version)
log_group "Cursor Info" \
  "User: ${BOLD}${cursor_user}${NC}" \
  "Version: ${BOLD}${cursor_version}${NC}"

# Usage stats
usage_stats=$(get_usage_stats)
prev_api_calls=$(echo "$usage_stats" | cut -d'|' -f1)
prev_tokens=$(echo "$usage_stats" | cut -d'|' -f2)
prev_companies=$(echo "$usage_stats" | cut -d'|' -f3)
prev_context=$(echo "$usage_stats" | cut -d'|' -f5)

if [[ $prev_api_calls -gt 0 ]]; then
  log "STEP" "Usage Stats"
  if [[ $prev_context -gt 0 ]]; then
    echo -e "   ${CYAN}Previous session: ${BOLD}${prev_api_calls}${NC} calls │ ${BOLD}${prev_tokens}${NC} tokens │ ${BOLD}${prev_companies}${NC} companies │ Max context: ${BOLD}${prev_context}${NC}${NC}" >&2
  else
    echo -e "   ${CYAN}Previous session: ${BOLD}${prev_api_calls}${NC} calls │ ${BOLD}${prev_tokens}${NC} tokens │ ${BOLD}${prev_companies}${NC} companies${NC}" >&2
  fi
fi

# Budget
log "STEP" "Budget"
if [[ $CURSOR_BUDGET_LIMIT -gt 0 ]]; then
  if [[ $prev_api_calls -gt 0 ]]; then
    remaining=$((CURSOR_BUDGET_LIMIT - prev_api_calls))
    if [[ $remaining -lt 0 ]]; then
      log "ERROR" "Budget exceeded! ${BOLD}${prev_api_calls}${NC}/${BOLD}${CURSOR_BUDGET_LIMIT}${NC}"
      exit 1
    else
      echo -e "   ${CYAN}Limit: ${BOLD}${CURSOR_BUDGET_LIMIT}${NC} calls │ Remaining: ${BOLD}${remaining}${NC}${NC}" >&2
    fi
  else
    echo -e "   ${CYAN}Limit: ${BOLD}${CURSOR_BUDGET_LIMIT}${NC} API calls${NC}" >&2
  fi
else
  echo -e "   ${CYAN}No budget limit set (unlimited)${NC}" >&2
fi

echo "" >&2

# Main loop: deploy agent sessions (can process multiple rows per session)
while :; do
  # Check if complete
  if is_complete; then
    log "SUCCESS" "All companies processed. Exiting."
    break
  fi

  # Get next row to process
  next_index=$(get_next_row_index)
  
  # Check if we've processed all rows
  if [[ $next_index -ge $total_rows ]]; then
    log "SUCCESS" "Reached end of CSV. All companies processed."
    break
  fi

  # Determine how many rows to process in this session
  rows_to_process=$CSV_ROWS_PER_SESSION
  remaining_rows=$((total_rows - next_index))
  if [[ $rows_to_process -gt $remaining_rows ]]; then
    rows_to_process=$remaining_rows
  fi
  
  # Check max companies limit
  if [[ $MAX_COMPANIES -gt 0 ]]; then
    remaining_companies=$((MAX_COMPANIES - company_count))
    if [[ $remaining_companies -le 0 ]]; then
      log "INFO" "Reached max companies limit ($MAX_COMPANIES). Exiting."
      break
    fi
    if [[ $rows_to_process -gt $remaining_companies ]]; then
      rows_to_process=$remaining_companies
    fi
  fi

  # Get company names for this session
  session_companies=()
  for ((i=0; i<rows_to_process; i++)); do
    row_idx=$((next_index + i))
    if [[ $row_idx -lt $total_rows ]]; then
      session_companies+=("$(get_company_name "$row_idx")")
    fi
  done
  
  # Display first company for header
  company_name="${session_companies[0]}"
  ((company_count++))
  
  company_start_time=$(date +%s)
  log_file="$LOG_DIR/session-${next_index}-to-$((next_index + rows_to_process - 1))-$(date +%Y%m%d-%H%M%S).json"

  echo "" >&2
  # Calculate box width dynamically based on content
  box_width=60
  company_label="Company #${company_count}"
  row_label="Row ${next_index}"
  name_label="${company_name}"
  content="${company_label} │ ${row_label} │ ${name_label}"
  content_len=${#content}
  
  # Pad content to fit box width (accounting for box borders and padding)
  padding=$((box_width - content_len - 4))
  if [[ $padding -lt 0 ]]; then
    padding=0
    # Truncate name if too long
    max_name_len=$((box_width - ${#company_label} - ${#row_label} - 10))
    if [[ ${#name_label} -gt $max_name_len ]]; then
      name_label="${name_label:0:$((max_name_len-3))}..."
    fi
    content="${company_label} │ ${row_label} │ ${name_label}"
  fi
  
  echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════╗${NC}" >&2
  printf "${BOLD}${CYAN}║${NC}  ${BOLD}%s${NC}%*s  ${BOLD}${CYAN}║${NC}\n" "$content" "$padding" "" >&2
  echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════╝${NC}" >&2
  echo "" >&2
  
  # Company info grouped together
  if [[ $rows_to_process -eq 1 ]]; then
    log_group "Company Info" \
      "Name: ${BOLD}${company_name}${NC}" \
      "Row Index: ${BOLD}${next_index}${NC}" \
      "Log file: ${BOLD}${log_file}${NC}"
  else
    log_group "Session Info" \
      "Processing ${BOLD}${rows_to_process}${NC} rows (${BOLD}${next_index}${NC} to ${BOLD}$((next_index + rows_to_process - 1))${NC})" \
      "Companies: ${BOLD}$(IFS=', '; echo "${session_companies[*]}")${NC}" \
      "Log file: ${BOLD}${log_file}${NC}"
  fi
  
  # Show progress bar - calculate total properly
  progress_total=$total_rows
  if [[ $MAX_COMPANIES -gt 0 ]]; then
    if [[ $MAX_COMPANIES -lt $total_rows ]]; then
      progress_total=$MAX_COMPANIES
    fi
  fi
  progress_bar $company_count $progress_total
  echo "" >&2
  
  # Enhanced timer with detailed status - display on new line after progress bar
  (
    timer=0
    while true; do
      mins=$((timer/60))
      secs=$((timer%60))
      hours=$((mins/60))
      mins_display=$((mins%60))
      
      # Print timer on its own line, clearing previous timer line
      if [[ $hours -gt 0 ]]; then
        printf "\r${NC}${YELLOW}⏱  Elapsed: %02d:%02d:%02d${NC} │ ${CYAN}Processing...${NC}%*s\r" "$hours" "$mins_display" "$secs" 20 "" >&2
      else
        printf "\r${NC}${YELLOW}⏱  Elapsed: %02d:%02d${NC} │ ${CYAN}Processing...${NC}%*s\r" "$mins" "$secs" 20 "" >&2
      fi
      sleep 1
      ((timer++))
    done
  ) &
  timer_pid=$!

  # Deploy agent(s) for this session
  # Store initial state to detect changes
  initial_index=$(get_next_row_index)
  
  # Run cursor agent - ensure we're in the right directory and capture both stdout and stderr
  # Use absolute path for prompt file to avoid any path issues
  # --force flag allows commands and tool usage (web fetches, file writes, etc.)
  abs_prompt_file="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
  
  # Check budget before execution
  if ! check_budget_limit; then
    log "ERROR" "Budget limit reached. Stopping execution."
    exit 1
  fi
  
  # Estimate tokens for this request
  estimated_tokens=$(estimate_tokens "$abs_prompt_file")
  
  # Determine execution mode: parallel or sequential
  if [[ $PARALLEL_AGENTS -gt 1 && $rows_to_process -ge $PARALLEL_AGENTS ]]; then
    # PARALLEL MODE: Split work across multiple agents
    log_group "Agent Deployment" \
      "Starting ${BOLD}${PARALLEL_AGENTS}${NC} parallel agent instances" \
      "Prompt: ${BOLD}${PROMPT_FILE}${NC}" \
      "Rows in session: ${BOLD}${rows_to_process}${NC} (split across ${PARALLEL_AGENTS} agents)" \
      "Sub-agents enabled: ${BOLD}${ENABLE_SUB_AGENTS}${NC}" \
      "Estimated tokens: ${BOLD}${estimated_tokens}${NC}"
    
    # Create parallel prompt if sub-agents are enabled
    parallel_prompt_file="$abs_prompt_file"
    if [[ "$ENABLE_SUB_AGENTS" == "true" ]]; then
      parallel_prompt_file="${abs_prompt_file}.parallel"
      create_parallel_prompt "$abs_prompt_file" "$parallel_prompt_file" "$rows_to_process"
    fi
    
    # Calculate rows per agent
    rows_per_agent=$((rows_to_process / PARALLEL_AGENTS))
    remaining_rows=$rows_to_process
    
    # Launch parallel agents
    parallel_pids=()
    parallel_logs=()
    agent_start_index=$next_index
    
    for ((agent_id=1; agent_id<=PARALLEL_AGENTS && remaining_rows>0; agent_id++)); do
      # Calculate rows for this agent
      current_agent_rows=$rows_per_agent
      if [[ $agent_id -eq $PARALLEL_AGENTS ]]; then
        # Last agent gets remaining rows
        current_agent_rows=$remaining_rows
      fi
      
      if [[ $current_agent_rows -le 0 ]]; then
        break
      fi
      
      agent_log_file="$LOG_DIR/agent${agent_id}-session-${agent_start_index}-to-$((agent_start_index + current_agent_rows - 1))-$(date +%Y%m%d-%H%M%S).json"
      parallel_logs+=("$agent_log_file")
      
      # Launch agent in background
      (
        run_parallel_agent "$agent_id" "$agent_start_index" "$current_agent_rows" "$agent_log_file" "$parallel_prompt_file"
      ) &
      parallel_pids+=($!)
      
      log "STEP" "Launched agent ${BOLD}${agent_id}${NC} │ Rows: ${BOLD}${agent_start_index}${NC}-${BOLD}$((agent_start_index + current_agent_rows - 1))${NC}"
      
      agent_start_index=$((agent_start_index + current_agent_rows))
      remaining_rows=$((remaining_rows - current_agent_rows))
    done
    
    # Wait for all parallel agents to complete
    cursor_exit=0
    for pid in "${parallel_pids[@]}"; do
      wait "$pid"
      agent_exit=$?
      if [[ $agent_exit -ne 0 ]]; then
        cursor_exit=$agent_exit
      fi
    done
    
    # Merge logs
    cat "${parallel_logs[@]}" > "$log_file" 2>&1
    
    # Extract context window from all logs with enhanced tracking
    context_window_used=0
    context_window_max=0
    session_id="session-${next_index}-to-$((next_index + rows_to_process - 1))-$(date +%Y%m%d-%H%M%S)"
    
    for agent_log in "${parallel_logs[@]}"; do
      agent_context_info=$(extract_context_window "$agent_log")
      if [[ -n "$agent_context_info" ]]; then
        local old_ifs="$IFS"
        IFS='|' read -r agent_used agent_max agent_type <<< "$agent_context_info"
        IFS="$old_ifs"
        agent_used=${agent_used:-0}
        agent_max=${agent_max:-0}
        
        # Track per-agent context window
        if [[ "$agent_used" -gt 0 ]]; then
          update_usage 0 0 0 "$agent_used" "$agent_type" "${session_id}-agent-$(basename "$agent_log")" "$agent_max"
        fi
        
        # Track maximum across all agents
        if [[ "$agent_used" -gt $context_window_used ]]; then
          context_window_used=$agent_used
        fi
        if [[ "$agent_max" -gt $context_window_max ]]; then
          context_window_max=$agent_max
        fi
      fi
    done
    
    if [[ $context_window_used -eq 0 ]]; then
      context_window_used=$estimated_tokens
    fi
    
    # Update usage tracking (PARALLEL_AGENTS API calls, track companies processed)
    update_usage $PARALLEL_AGENTS "$estimated_tokens" "$rows_to_process" "$context_window_used" "main" "$session_id" "$context_window_max"
    total_api_calls=$((total_api_calls + PARALLEL_AGENTS))
    total_tokens_estimated=$((total_tokens_estimated + estimated_tokens))
    
    # Cleanup parallel prompt if created
    [[ -f "$parallel_prompt_file" && "$parallel_prompt_file" != "$abs_prompt_file" ]] && rm -f "$parallel_prompt_file"
    
  else
    # SEQUENTIAL MODE: Single agent execution
    log_group "Agent Deployment" \
      "Starting fresh agent instance" \
      "Prompt: ${BOLD}${PROMPT_FILE}${NC}" \
      "Rows in session: ${BOLD}${rows_to_process}${NC}" \
      "Sub-agents enabled: ${BOLD}${ENABLE_SUB_AGENTS}${NC}" \
      "Estimated tokens: ${BOLD}${estimated_tokens}${NC}"
    
    # Create parallel prompt if sub-agents are enabled
    if [[ "$ENABLE_SUB_AGENTS" == "true" ]]; then
      parallel_prompt_file="${abs_prompt_file}.parallel"
      create_parallel_prompt "$abs_prompt_file" "$parallel_prompt_file" "$rows_to_process"
      abs_prompt_file="$parallel_prompt_file"
    fi
    
    cursor agent -p --force --output-format text "$abs_prompt_file" > "$log_file" 2>&1
    cursor_exit=$?
    
    # Extract context window usage from log with enhanced tracking
    session_id="session-${next_index}-to-$((next_index + rows_to_process - 1))-$(date +%Y%m%d-%H%M%S)"
    context_info=$(extract_context_window "$log_file")
    
    if [[ -n "$context_info" ]]; then
      local old_ifs="$IFS"
      IFS='|' read -r context_window_used context_window_max agent_type <<< "$context_info"
      IFS="$old_ifs"
      context_window_used=${context_window_used:-0}
      context_window_max=${context_window_max:-0}
      agent_type=${agent_type:-main}
    else
      # Fallback: estimate from tokens if we can't extract from log
      context_window_used=$estimated_tokens
      context_window_max=0
      agent_type="main"
    fi
    
    # Update usage tracking (1 API call per session, but track companies processed)
    update_usage 1 "$estimated_tokens" "$rows_to_process" "$context_window_used" "$agent_type" "$session_id" "$context_window_max"
    total_api_calls=$((total_api_calls + 1))
    total_tokens_estimated=$((total_tokens_estimated + estimated_tokens))
    
    # Cleanup parallel prompt if created
    [[ -f "$parallel_prompt_file" && "$parallel_prompt_file" != "$abs_prompt_file" ]] && rm -f "$parallel_prompt_file"
  fi

  kill "$timer_pid" 2>/dev/null
  wait "$timer_pid" 2>/dev/null
  timer_pid=""
  # Clear timer line completely
  printf "\r${NC}%*s\r${NC}" 80 "" >&2

  company_end_time=$(date +%s)
  company_elapsed=$((company_end_time - company_start_time))
  company_mins=$((company_elapsed/60))
  company_secs=$((company_elapsed%60))
  
  # Calculate batch elapsed time
  batch_elapsed=$((company_end_time - batch_start_time))
  batch_hours=$((batch_elapsed/3600))
  batch_mins=$(((batch_elapsed%3600)/60))
  batch_secs=$((batch_elapsed%60))

  echo "" >&2
  
  # Completion status
  if [[ $cursor_exit -eq 0 ]]; then
    if [[ -n "$context_window_used" && "$context_window_used" != "0" ]]; then
      log "SUCCESS" "Session completed │ Exit code: ${GREEN}${cursor_exit}${NC} │ Time: ${BOLD}${company_mins}m ${company_secs}s${NC} │ Context window: ${BOLD}${context_window_used}${NC}"
    else
      log "SUCCESS" "Session completed │ Exit code: ${GREEN}${cursor_exit}${NC} │ Time: ${BOLD}${company_mins}m ${company_secs}s${NC}"
    fi
  else
    if [[ -n "$context_window_used" && "$context_window_used" != "0" ]]; then
      log "WARN" "Session completed │ Exit code: ${YELLOW}${cursor_exit}${NC} │ Time: ${BOLD}${company_mins}m ${company_secs}s${NC} │ Context window: ${BOLD}${context_window_used}${NC}"
    else
      log "WARN" "Session completed │ Exit code: ${YELLOW}${cursor_exit}${NC} │ Time: ${BOLD}${company_mins}m ${company_secs}s${NC}"
    fi
  fi
  
  # Check log for abort/error messages
  if grep -qiE "abort|aborting" "$log_file"; then
    log "WARN" "Agent aborted operation detected in log"
    echo -e "   ${YELLOW}Last 15 lines:${NC}" >&2
    tail -15 "$log_file" | sed 's/^/   /' >&2
    echo "" >&2
  fi
  
  # Verify the session was actually processed by checking if progress updated
  sleep 2  # Brief pause to ensure file writes complete
  new_index=$(get_next_row_index)
  
  expected_index=$((initial_index + rows_to_process))
  if [[ $new_index -lt $expected_index ]]; then
    log "ERROR" "Progress log not updated sufficiently (expected index $expected_index, got $new_index)"
    log_group "Debug" \
      "Agent exit code: ${BOLD}${cursor_exit}${NC}" \
      "Log file: ${BOLD}${log_file}${NC}" \
      "Rows processed: ${BOLD}$((new_index - initial_index))${NC} of ${BOLD}${rows_to_process}${NC}"
    echo "" >&2
    
    # Show more context from log
    echo -e "${RED}=== Full log content ===${NC}" >&2
    cat "$log_file" >&2
    echo -e "${RED}=== End log ===${NC}" >&2
    echo "" >&2
    
    log "ERROR" "Stopping to prevent infinite loop"
    log_group "Troubleshooting" \
      "Check file write permissions" \
      "Verify command flags" \
      "Review prompt file configuration"
    exit 1
  else
    log "SUCCESS" "Progress updated: ${BOLD}${initial_index}${NC} → ${BOLD}${GREEN}${new_index}${NC} (${BOLD}$((new_index - initial_index))${NC} rows)"
  fi

  # Show batch statistics and usage stats together
  usage_stats=$(get_usage_stats)
  current_api_calls=$(echo "$usage_stats" | cut -d'|' -f1)
  current_tokens=$(echo "$usage_stats" | cut -d'|' -f2)
  
  log "STEP" "Statistics"
  current_context=$(echo "$usage_stats" | cut -d'|' -f5)
  if [[ $batch_hours -gt 0 ]]; then
    if [[ $current_context -gt 0 ]]; then
      echo -e "   ${CYAN}Batch time: ${BOLD}${batch_hours}h ${batch_mins}m ${batch_secs}s${NC} │ Avg/session: ${BOLD}$((batch_elapsed/company_count))s${NC} │ API calls: ${BOLD}${current_api_calls}${NC} │ Tokens: ${BOLD}${current_tokens}${NC} │ Max context: ${BOLD}${current_context}${NC}${NC}" >&2
    else
      echo -e "   ${CYAN}Batch time: ${BOLD}${batch_hours}h ${batch_mins}m ${batch_secs}s${NC} │ Avg/session: ${BOLD}$((batch_elapsed/company_count))s${NC} │ API calls: ${BOLD}${current_api_calls}${NC} │ Tokens: ${BOLD}${current_tokens}${NC}${NC}" >&2
    fi
  else
    if [[ $current_context -gt 0 ]]; then
      echo -e "   ${CYAN}Batch time: ${BOLD}${batch_mins}m ${batch_secs}s${NC} │ Avg/session: ${BOLD}$((batch_elapsed/company_count))s${NC} │ API calls: ${BOLD}${current_api_calls}${NC} │ Tokens: ${BOLD}${current_tokens}${NC} │ Max context: ${BOLD}${current_context}${NC}${NC}" >&2
    else
      echo -e "   ${CYAN}Batch time: ${BOLD}${batch_mins}m ${batch_secs}s${NC} │ Avg/session: ${BOLD}$((batch_elapsed/company_count))s${NC} │ API calls: ${BOLD}${current_api_calls}${NC} │ Tokens: ${BOLD}${current_tokens}${NC}${NC}" >&2
    fi
  fi
  
  # Show detailed context window breakdown
  log_context_window_details
  
  if [[ $CURSOR_BUDGET_LIMIT -gt 0 ]]; then
    remaining=$((CURSOR_BUDGET_LIMIT - current_api_calls))
    percent=$((current_api_calls * 100 / CURSOR_BUDGET_LIMIT))
    if [[ $percent -ge 90 ]]; then
      log "WARN" "Budget usage: ${BOLD}${percent}%${NC} (${current_api_calls}/${CURSOR_BUDGET_LIMIT}) - ${BOLD}${remaining}${NC} remaining"
    else
      echo -e "   ${CYAN}Budget: ${BOLD}${percent}%${NC} (${current_api_calls}/${CURSOR_BUDGET_LIMIT}) - ${BOLD}${remaining}${NC} remaining${NC}" >&2
    fi
  fi
  
  # Brief pause between sessions to avoid rate limits
  # This gives time for any rate limit windows to reset
  log "STEP" "Rate Limiting"
  echo -e "   ${CYAN}Waiting 3 seconds before next session...${NC}" >&2
  sleep 3
done

echo "" >&2
batch_end_time=$(date +%s)
total_batch_time=$((batch_end_time - batch_start_time))
total_hours=$((total_batch_time/3600))
total_mins=$(((total_batch_time%3600)/60))
total_secs=$((total_batch_time%60))

echo -e "${BOLD}${GREEN}╔════════════════════════════════════════════════════════════╗${NC}" >&2
echo -e "${BOLD}${GREEN}║${NC}  ${BOLD}✅ Batch Processing Complete${NC}                          ${BOLD}${GREEN}║${NC}" >&2
echo -e "${BOLD}${GREEN}╚════════════════════════════════════════════════════════════╝${NC}" >&2
echo "" >&2

log "SUCCESS" "Total companies processed: ${BOLD}${company_count}${NC}"
if [[ $total_hours -gt 0 ]]; then
  log "SUCCESS" "Total time: ${BOLD}${total_hours}h ${total_mins}m ${total_secs}s${NC}"
else
  log "SUCCESS" "Total time: ${BOLD}${total_mins}m ${total_secs}s${NC}"
fi

if [[ $company_count -gt 0 ]]; then
  avg_time=$((total_batch_time / company_count))
  log "SUCCESS" "Average time per company: ${BOLD}${avg_time}s${NC}"
else
  log "INFO" "No companies processed"
fi

# Final usage statistics
usage_stats=$(get_usage_stats)
final_api_calls=$(echo "$usage_stats" | cut -d'|' -f1)
final_tokens=$(echo "$usage_stats" | cut -d'|' -f2)
final_companies=$(echo "$usage_stats" | cut -d'|' -f3)
final_context=$(echo "$usage_stats" | cut -d'|' -f5)
session_start=$(echo "$usage_stats" | cut -d'|' -f4)
session_duration=$((batch_end_time - session_start))

log "SUCCESS" "Session API calls: ${BOLD}${final_api_calls}${NC}"
log "SUCCESS" "Session companies processed: ${BOLD}${final_companies}${NC}"

# Show detailed context window and token spend breakdown
log_context_window_details

if [[ $CURSOR_BUDGET_LIMIT -gt 0 ]]; then
  remaining=$((CURSOR_BUDGET_LIMIT - final_api_calls))
  percent=$((final_api_calls * 100 / CURSOR_BUDGET_LIMIT))
  log "SUCCESS" "Budget usage: ${BOLD}${percent}%${NC} (${final_api_calls}/${CURSOR_BUDGET_LIMIT})"
  if [[ $remaining -gt 0 ]]; then
    log "SUCCESS" "Budget remaining: ${BOLD}${remaining}${NC} API calls"
  else
    log "WARN" "Budget exhausted: ${BOLD}${final_api_calls}${NC}/${BOLD}${CURSOR_BUDGET_LIMIT}${NC}"
  fi
fi

log_status "Usage File" "Saved to: ${CURSOR_USAGE_FILE}"

echo "" >&2
