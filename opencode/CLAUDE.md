# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OpenCode is an open-source, provider-agnostic AI coding agent. It's a Bun/TypeScript monorepo managed with Turbo, containing ~19 packages. The default branch is `dev` (local `main` may not exist; use `dev` or `origin/dev` for diffs).

## Common Commands

```bash
bun install                    # Install all dependencies
bun dev                        # Run TUI locally (targets packages/opencode by default)
bun dev <directory>            # Run TUI against a specific directory
bun dev .                      # Run TUI against the repo root
bun dev serve                  # Start headless API server (port 4096)
bun dev serve --port 8080      # Custom port
bun dev web                    # Start server + open web UI
bun typecheck                  # TypeScript type checking (via Turbo)
```

**Tests must be run from package directories, not the repo root:**
```bash
cd packages/opencode && bun test           # Run all tests in opencode package
cd packages/opencode && bun test <file>    # Run a single test file
```

**Building:**
```bash
./packages/opencode/script/build.ts --single     # Standalone binary
bun run --cwd packages/desktop tauri build        # Desktop app
```

**SDK regeneration** (after API/SDK changes):
```bash
./script/generate.ts                              # Regenerate SDK
./packages/sdk/js/script/build.ts                 # Regenerate JS SDK
```

## Architecture

**Core packages:**
- `packages/opencode` — Main application: CLI, server (Hono), session management, agent logic, 45+ tools, provider integrations, storage (Drizzle ORM + SQLite)
- `packages/app` — Shared web UI (SolidJS)
- `packages/desktop` — Native desktop app (Tauri v2 + Rust, wraps `packages/app`)
- `packages/ui` — UI component library
- `packages/sdk/js` — JavaScript SDK
- `packages/plugin` — Plugin system (`@opencode-ai/plugin`)

**Key directories in `packages/opencode/src/`:**
- `cli/cmd/` — CLI commands (run, serve, web, agent, auth, etc.)
- `cli/tui/` — Terminal UI (SolidJS + opentui)
- `server/` — HTTP server (Hono)
- `provider/` — LLM provider integrations (Anthropic, OpenAI, Google, Azure, etc.)
- `tool/` — Built-in tools for code interaction
- `agent/` — Agent logic (two agents: "build" with full access, "plan" as read-only)
- `session/` — Session management & state
- `storage/` — Drizzle ORM + SQLite persistence
- `mcp/` — Model Context Protocol support
- `lsp/` — Language Server Protocol support

## Style Guide

- Prefer single-word variable names; inline values used only once
- Avoid unnecessary destructuring; use dot notation (`obj.a` not `const { a } = obj`)
- `const` over `let`; use ternaries or early returns instead of reassignment
- Avoid `else`; prefer early returns
- Avoid `try`/`catch`; prefer `.catch()`
- Avoid `any` type; rely on type inference when possible
- Functional array methods (flatMap, filter, map) over for loops
- Use Bun APIs when possible (e.g., `Bun.file()`)
- snake_case for Drizzle schema field names
- Avoid mocks in tests; test actual implementations
- Prettier config: no semicolons, 120 char print width

## Commit Conventions

PR titles and commits use conventional format: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:` — optionally scoped like `feat(app):` or `fix(desktop):`.
