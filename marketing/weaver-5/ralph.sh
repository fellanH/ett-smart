#!/bin/bash
set -uo pipefail

# Configuration
MAX_LOOPS=150
BATCH_SIZE=5
START_ROW="${1:-155}"  # Starting row, can override via CLI arg
PROMPT_FILE="PROMPT.md"
LOG_DIR=".logs"
timer_pid=""

cleanup() {
  printf "\n" >&2
  echo "Shutting down..." >&2
  [[ -n "$timer_pid" ]] && kill "$timer_pid" 2>/dev/null
  wait "$timer_pid" 2>/dev/null
  exit 0
}
trap cleanup SIGINT SIGTERM

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Error: $PROMPT_FILE not found" >&2
  exit 1
fi

# Get total rows in CSV (excluding header)
CSV_FILE="blue-collar-companies.csv"
if [[ ! -f "$CSV_FILE" ]]; then
  echo "Error: $CSV_FILE not found" >&2
  exit 1
fi
TOTAL_ROWS=$(($(wc -l < "$CSV_FILE") - 1))  # Subtract 1 for header row

mkdir -p "$LOG_DIR"
loop_count=0
current_row=$START_ROW

# Display startup info
echo "Starting batch processing..." >&2
echo "CSV file: $CSV_FILE (total rows: $TOTAL_ROWS)" >&2
echo "Starting at row: $START_ROW, Batch size: $BATCH_SIZE" >&2
echo "Max loops: $MAX_LOOPS" >&2
echo "" >&2

update_prompt_row() {
  local row=$1
  # Update "Start Row Index: X" in PROMPT.md
  sed -i '' "s/- Start Row Index: [0-9]*/- Start Row Index: $row/" "$PROMPT_FILE"
  # Also update "starting from row X" in instructions
  sed -i '' "s/starting from row [0-9]*/starting from row $row/" "$PROMPT_FILE"
}

while :; do
  # Check if we've reached the end of the CSV before processing
  if [[ $current_row -gt $TOTAL_ROWS ]]; then
    echo "✅ Reached end of CSV file (row $TOTAL_ROWS). Processed rows $START_ROW - $((current_row - BATCH_SIZE))" >&2
    break
  fi

  ((loop_count++))
  start_time=$(date +%s)
  log_file="$LOG_DIR/run-$(date +%Y%m%d-%H%M%S)-loop${loop_count}-row${current_row}.log"

  # Update PROMPT.md with current row
  update_prompt_row "$current_row"

  echo "" >&2
  echo "==========================================" >&2
  echo "Loop #$loop_count / $MAX_LOOPS" >&2
  echo "Processing rows $current_row - $((current_row + BATCH_SIZE - 1))" >&2
  echo "Log: $log_file" >&2
  echo "==========================================" >&2

  # Timer writes to stderr only
  (
    timer=0
    while true; do
      printf "\r⏱  Elapsed: %02d:%02d" $((timer/60)) $((timer%60)) >&2
      sleep 1
      ((timer++))
    done
  ) &
  timer_pid=$!

  # Run agent, capture output to log
  agent -p --force --output-format stream-json "$(cat "$PROMPT_FILE")" | \
    tee "$log_file" | \
    # Parse stream for progress updates
    while IFS= read -r line; do
      type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
      if [[ "$type" == "tool_call" ]]; then
        echo "$line" | jq -r '.tool_call | keys[]' 2>/dev/null | head -1
      fi
    done >&2
  agent_exit=${PIPESTATUS[0]}

  kill "$timer_pid" 2>/dev/null
  wait "$timer_pid" 2>/dev/null
  timer_pid=""
  printf "\n" >&2

  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  echo "" >&2
  echo "Loop #$loop_count completed in $((elapsed/60))m $((elapsed%60))s (exit: $agent_exit)" >&2

  # Increment row for next batch
  current_row=$((current_row + BATCH_SIZE))

  # Check if we've reached max loops
  if [[ $MAX_LOOPS -gt 0 && $loop_count -ge $MAX_LOOPS ]]; then
    echo "✅ Reached max loops ($MAX_LOOPS). Processed rows $START_ROW - $((current_row - BATCH_SIZE))" >&2
    break
  fi

  sleep 2
done

echo "Done. Logs saved to $LOG_DIR/" >&2
