# Shell Script Best Practices Review

## Overview

Review of `ralph.sh` and `ralph-config.sh` against modern shell script best practices.

## ✅ Good Practices Found

### Both Scripts

1. **Error handling**: Both use `set -uo pipefail` ✓
   - `-u`: Treat unset variables as errors
   - `-o pipefail`: Return value of pipeline is last non-zero exit
2. **Shebang**: Both use `#!/bin/bash` ✓

3. **Function organization**: Well-structured functions ✓

4. **Read command**: Uses `read -r` to prevent backslash interpretation ✓

### ralph.sh Specific

- Good use of trap for cleanup
- Proper error messages to stderr (`>&2`)
- Good variable initialization with defaults

### ralph-config.sh Specific

- Interactive UI with proper terminal handling
- Good validation of user input

## ⚠️ Issues Found & Recommendations

### 1. Unquoted Variables (Medium Priority)

**ralph.sh:60**

```bash
sleep $delay
```

**Fix:**

```bash
sleep "$delay"
```

**Rationale**: Unquoted variables can cause word splitting and pathname expansion. Always quote variables unless you specifically need word splitting.

**ralph.sh:473**

```bash
echo $((tokens * 3))
```

**Fix:**

```bash
echo "$((tokens * 3))"
```

### 2. Command Substitution in Arithmetic (Low Priority)

**ralph.sh:357, 378, 385, 389**

```bash
local start_time=$(grep -o '"start_time"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || echo "$(date +%s)")
```

**Issue**: Nested command substitution `$(date +%s)` inside `echo` is unnecessary.

**Fix:**

```bash
local start_time=$(grep -o '"start_time"[ ]*:[ ]*[0-9]*' "$CURSOR_USAGE_FILE" 2>/dev/null | grep -o '[0-9]*' || date +%s)
```

### 3. Array Access Without Quoting (Low Priority)

**ralph-config.sh:148-150**

```bash
local idx=$((i + 1))
local item="${items[$i]}"
local value="${values[$i]}"
```

**Status**: Already properly quoted ✓

### 4. Function Return Codes (Medium Priority)

**ralph.sh: Functions that don't check return codes**

- `get_company_name()` - doesn't validate CSV file access
- `get_cursor_user()` - doesn't validate cursor command availability
- `get_cursor_version()` - doesn't validate cursor command availability

**Recommendation**: Add validation:

```bash
get_company_name() {
  local row_index=$1
  local company_name

  if [[ ! -f "$CSV_FILE" ]]; then
    echo "" >&2
    return 1
  fi

  company_name=$(awk -F',' -v idx="$((row_index + 2))" 'NR==idx {print $1}' "$CSV_FILE" 2>/dev/null)
  echo "${company_name:-}"
}
```

### 5. Security: Command Injection Risk (High Priority)

**ralph.sh:827**

```bash
abs_prompt_file="$(cd "$(dirname "$PROMPT_FILE")" && pwd)/$(basename "$PROMPT_FILE")"
```

**Status**: Properly quoted ✓

**ralph.sh:959**

```bash
cursor agent -p --force --output-format text "$abs_prompt_file" > "$log_file" 2>&1
```

**Status**: Properly quoted ✓

**ralph-config.sh:68**

```bash
# Generated on $(date)
```

**Issue**: Command substitution in heredoc without quoting.

**Fix:**

```bash
cat > "$CONFIG_FILE" << EOF
# Ralph Agent Configuration
# Generated on $(date '+%Y-%m-%d %H:%M:%S')

PROMPT_FILE="${PROMPT_FILE}"
...
EOF
```

### 6. Error Handling in Pipelines (Medium Priority)

**ralph.sh:254**

```bash
total=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
```

**Issue**: Doesn't check if `tail` or `wc` succeed.

**Recommendation**: Add validation:

```bash
get_total_rows() {
  local total
  if [[ ! -f "$CSV_FILE" ]]; then
    echo "0"
    return 1
  fi
  total=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
  echo "${total:-0}"
}
```

### 7. Temporary File Handling (Medium Priority)

**ralph.sh:193, 307, etc.**

```bash
jq ... "$CURSOR_USAGE_FILE" > "${CURSOR_USAGE_FILE}.tmp" && mv "${CURSOR_USAGE_FILE}.tmp" "$CURSOR_USAGE_FILE"
```

**Status**: Good pattern ✓ (atomic write)

**Recommendation**: Consider using `mktemp` for better security:

```bash
local temp_file
temp_file=$(mktemp "${CURSOR_USAGE_FILE}.tmp.XXXXXX") || return 1
jq ... "$CURSOR_USAGE_FILE" > "$temp_file" && mv "$temp_file" "$CURSOR_USAGE_FILE"
```

### 8. IFS Handling (Low Priority)

**ralph.sh:526-528**

```bash
IFS=','
echo "${names[*]}"
unset IFS
```

**Status**: Properly handled ✓

**ralph.sh:912**

```bash
IFS='|' read -r agent_used agent_max agent_type <<< "$agent_context_info"
```

**Issue**: IFS not restored after use.

**Fix:**

```bash
local old_ifs="$IFS"
IFS='|' read -r agent_used agent_max agent_type <<< "$agent_context_info"
IFS="$old_ifs"
```

### 9. Division by Zero Risk (Medium Priority)

**ralph.sh:70-71, 1119**

```bash
local percent=$((current * 100 / total))
local avg_time=$((total_batch_time/company_count))
```

**Issue**: No check for zero division.

**Fix:**

```bash
if [[ $total -gt 0 ]]; then
  local percent=$((current * 100 / total))
else
  local percent=0
fi
```

### 10. Read Command Improvements (Low Priority)

**ralph-config.sh: Multiple locations**

```bash
read -r new_value
```

**Recommendation**: Add timeout and IFS handling:

```bash
IFS= read -r -t 60 new_value || {
  echo "Input timeout" >&2
  return 1
}
```

### 11. Variable Naming Consistency (Low Priority)

**Status**: Generally good ✓

**Minor**: Some variables use `snake_case`, others use `UPPER_CASE`. Consider consistency:

- Configuration variables: `UPPER_CASE` ✓
- Local variables: `snake_case` ✓
- Function names: `snake_case` ✓

### 12. Exit Codes (Low Priority)

**ralph.sh:145**

```bash
exit 0
```

**Issue**: Cleanup function always exits with 0, even on error.

**Fix:**

```bash
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
```

## 📋 Summary of Recommended Changes

### High Priority

1. Fix unquoted variables (`sleep $delay` → `sleep "$delay"`)

### Medium Priority

1. Add division by zero checks
2. Improve function return code handling
3. Restore IFS after modification
4. Add validation for file operations

### Low Priority

1. Simplify nested command substitutions
2. Use `mktemp` for temporary files
3. Add timeouts to read commands
4. Improve cleanup exit code handling

## 🔍 Additional Best Practices to Consider

1. **ShellCheck**: Install and run `shellcheck` for automated linting:

   ```bash
   brew install shellcheck
   shellcheck ralph.sh ralph-config.sh
   ```

2. **shfmt**: Format shell scripts:

   ```bash
   brew install shfmt
   shfmt -w ralph.sh ralph-config.sh
   ```

3. **Documentation**: Add function documentation:

   ```bash
   # Function: get_company_name
   # Description: Retrieves company name from CSV at specified row index
   # Arguments:
   #   $1: row_index - Zero-based row index
   # Returns: Company name or empty string on error
   # Exit codes: 0 on success, 1 on error
   ```

4. **Testing**: Consider adding unit tests for functions using `bats` (Bash Automated Testing System)

5. **Logging**: Consider structured logging (JSON) for better parsing

6. **Configuration**: Consider using a more structured config format (YAML/TOML) with validation

## 📚 References

- [ShellCheck Wiki](https://github.com/koalaman/shellcheck/wiki)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Guide](https://mywiki.wooledge.org/BashGuide)
- [Bash Pitfalls](http://mywiki.wooledge.org/BashPitfalls)
