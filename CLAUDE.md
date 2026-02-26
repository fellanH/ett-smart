# ett-smart

API integration project connecting HubOne apartment platform with Happy Booking reservation system.

## Context Loading

At session start, load from the context vault:

- `get_context(query: "ett-smart project context")` — project architecture and decisions
- `get_context(tags: ["ett-smart"])` — all entries tagged for this project

## Structure

```
ett-smart/
  api/            — API integration source (has its own CLAUDE.md)
  dorma-kaba/     — Door access integration
  ett-smart/      — Core project files and meeting materials
  ett-smart-llms-txt/ — LLM reference docs
  marketing/      — Marketing materials
```
