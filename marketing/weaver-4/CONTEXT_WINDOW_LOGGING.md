# Enhanced Context Window Logging

## Overview

The logging system has been enhanced to provide full transparency into how agent and sub-agent context windows are utilized, with clear differentiation between token spend (API costs) and context window utilization (memory limits).

## Key Improvements

### 1. **Separate Tracking of Token Spend vs Context Windows**

- **Token Spend**: Tracks estimated API costs separately for main agents and sub-agents
  - `token_spend.total_estimated`: Total tokens across all agents
  - `token_spend.main_agents`: Tokens used by main agent instances
  - `token_spend.sub_agents`: Tokens used by sub-agent instances

- **Context Windows**: Tracks memory/limit utilization separately
  - `context_windows.main_agents`: Context window usage for main agents
  - `context_windows.sub_agents`: Context window usage for sub-agents
  - `context_windows.overall_max`: Maximum context window used across all agents

### 2. **Per-Agent Context Window Tracking**

Each agent session now logs:

- `context_used`: Actual context window tokens used
- `context_max`: Maximum context window size (if known)
- `session_id`: Unique identifier for the session
- `timestamp`: When the session occurred

### 3. **Enhanced Logging Functions**

#### `extract_context_window(log_file)`

- Returns: `context_used|context_max|agent_type`
- Automatically detects agent type (main vs sub) from log file names or content
- Extracts context window usage from Cursor agent logs

#### `update_usage(api_calls, tokens_estimated, companies, context_window_used, agent_type, session_id, context_window_max)`

- Enhanced to track both token spend and context windows separately
- Supports per-agent and per-session tracking
- Maintains backward compatibility with old format

#### `log_context_window_details()`

- Displays detailed breakdown of context window utilization
- Shows max, average, and session counts for main agents and sub-agents
- Separately displays token spend (API costs) vs context window utilization

### 4. **Usage Statistics JSON Structure**

```json
{
  "start_time": 1234567890,
  "api_calls": 10,
  "token_spend": {
    "total_estimated": 50000,
    "main_agents": 40000,
    "sub_agents": 10000
  },
  "context_windows": {
    "main_agents": {
      "max_used": 128000,
      "total_sessions": 5,
      "sessions": [
        {
          "timestamp": 1234567890,
          "context_used": 95000,
          "context_max": 128000,
          "session_id": "session-0-to-0-20240101-120000"
        }
      ]
    },
    "sub_agents": {
      "max_used": 64000,
      "total_sessions": 3,
      "sessions": [...]
    },
    "overall_max": 128000
  },
  "companies_processed": 10
}
```

## Usage

### During Execution

After each session, the script displays:

- Context window utilization breakdown (main agents vs sub-agents)
- Token spend breakdown (API costs)
- Clear note differentiating token spend from context window utilization

### Final Summary

At the end of batch processing, a comprehensive summary shows:

- Total API calls
- Token spend by agent type
- Context window statistics (max, average, session counts)
- Overall maximum context window used

## Benefits

1. **Full Transparency**: See exactly how context windows are used across all agent types
2. **Optimization Insights**: Identify which agents use the most context and optimize accordingly
3. **Cost Tracking**: Separate API costs (token spend) from memory usage (context windows)
4. **Per-Session Tracking**: Track individual session context usage for detailed analysis
5. **Backward Compatible**: Automatically migrates old usage files to new format

## Migration

Old usage files are automatically migrated to the new format when the script runs. The migration preserves all existing data:

- `tokens_estimated` → `token_spend.total_estimated` and `token_spend.main_agents`
- `context_window_max` → `context_windows.main_agents.max_used` and `context_windows.overall_max`

## Requirements

- `jq` is recommended for full functionality (automatic JSON manipulation)
- Falls back to basic tracking if `jq` is not available (with limited context window details)
