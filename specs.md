# `hop` — Project Session Manager for tmux

**Version:** 0.1
**Author:** mattmezza

---

## Overview

`hop` is a bash CLI utility for tmux project management. It maintains an explicit registry of "marked" project directories, each associated with a verified session template. The tool handles session creation, switching, and the tmux nesting problem while providing registry maintenance utilities.

### Design Principles

- **Explicit over implicit** — Manual marking, mandatory template selection
- **Trust but verify** — Template integrity checking via SHA-256
- **Single-purpose commands** — Predictable behavior, no magic

---

## Functional Requirements

### FR-1: Registry Management

The script shall maintain a flat-file database at `~/.hop-projects` containing records in the format:

```
<absolute_path>:<template_name>:<sha256_hash>
```

Example:
```
/home/user/work/api:backend:a3f2e1b8c9d0...
/home/user/personal/blog:default:b4c8d2e5f6a1...
```

| Field | Purpose |
|-------|---------|
| `absolute_path` | Location of the marked project directory |
| `template_name` | Name of the template used at marking time (enables `refresh`) |
| `sha256_hash` | Integrity hash of the local `.tmux-session` file |

---

### FR-2: Project Marking

```bash
hop mark <template> [path]
```

| Behavior | Description |
|----------|-------------|
| `<template>` | **Mandatory**; omission produces error with usage hint |
| `[path]` | Defaults to `$PWD` if omitted |
| Directory check | Verify directory exists; error if not |
| Duplicate check | Verify directory is not already marked; error if duplicate |
| Template check | Verify template exists in `~/.config/hop/templates/`; error if missing |
| File copy | Copy template to `<path>/.tmux-session` |
| Hash computation | Compute SHA-256 of copied file |
| Registry append | Add record to `~/.hop-projects` |

---

### FR-3: Template Integrity Verification

Before sourcing any `.tmux-session` file during session creation:

1. Compute current SHA-256 hash of the file
2. Compare against stored hash in registry
3. If mismatch:
   - Print warning: `Warning: .tmux-session has changed since marking. Continue? [y/N]`
   - Abort unless user confirms interactively
   - Suggest `hop allow [path]` to trust the new version

**Allow command:**
```bash
hop allow [path]
```
- `[path]` defaults to `$PWD`
- Recomputes SHA-256 hash of current `.tmux-session`
- Updates stored hash in registry
- Does **not** re-copy template from `~/.config/hop/templates/`

---

### FR-4: Template Management

**Listing templates:**
```bash
hop templates    # or: hop tpls
```
- Lists all files in `~/.config/hop/templates/`
- Displays first comment line of each file as description (if present)

**Template location:**
- Templates reside in `~/.config/hop/templates/`
- Users create templates manually via text editor
- A `default` template shall ship with the tool:

```bash
#!/usr/bin/env bash
# Default template - single window, no panes
tmux rename-window -t "$SESSION_NAME:1" "default"
```

**Template contract:**

Templates are bash scripts sourced with these variables available:

| Variable | Description |
|----------|-------------|
| `$SESSION_NAME` | Computed session name (see FR-8) |
| `$PROJECT_PATH` | Absolute path to project directory |

---

### FR-5: Fuzzy Selection with Preview

When invoked without arguments:
```bash
hop
```

| Behavior | Description |
|----------|-------------|
| Source | Pipe registry paths to `fzf` |
| Preview | Display preview pane (see below) |
| Selection | Proceeds to session creation/attachment (FR-6, FR-7) |
| Empty/Cancel | Exit gracefully with status `0` |

**Preview pane content:**
- If tmux session exists: `tmux list-windows -t <session>` output
- If session doesn't exist and directory is git repo: `git -C <path> log --oneline -5`
- Otherwise: `ls -la <path>`

---

### FR-6: Dynamic Session Creation

Upon selection of a project:

1. Compute session name per FR-8
2. If session **does not exist**:
   - Create detached session: `tmux new-session -d -s "$SESSION_NAME" -c "$PROJECT_PATH"`
   - Verify template integrity (FR-3)
   - Source `.tmux-session` to configure windows/panes
3. If session **already exists**:
   - Do not re-source template (idempotency)
   - Proceed directly to attachment (FR-7)

---

### FR-7: Smart Attachment

After session creation or lookup:

| Condition | Action |
|-----------|--------|
| `$TMUX` unset (outside tmux) | `tmux attach-session -t "$SESSION_NAME"` |
| `$TMUX` set (inside tmux) | `tmux switch-client -t "$SESSION_NAME"` |

---

### FR-8: Session Naming Strategy

Session names use the project directory name by default. If another registered project has the same directory name (collision), the parent directory is prepended:

| Scenario | Path | Session Name |
|----------|------|--------------|
| No collision | `/home/user/work/api` | `api` |
| Collision (both have `api`) | `/home/user/work/api` | `work-api` |
| Collision (both have `api`) | `/home/user/personal/api` | `personal-api` |
| No collision | `/home/user/projects/foo` | `foo` |

Characters invalid for tmux session names (`.`, `:`) shall be replaced with `_`.

---

### FR-9: Registry Inspection

**List registered projects:**
```bash
hop list
```

Output format:
```
api             /home/user/work/api         [backend]    ✓
blog            /home/user/personal/blog    [default]    ⚠ hash mismatch
old-project     /home/user/old              [node]       ✗ path missing
```

**Remove from registry:**
```bash
hop unmark [path]
```

| Behavior | Description |
|----------|-------------|
| `[path]` | Defaults to `$PWD` |
| Registry | Removes entry from `~/.hop-projects` |
| Template file | Prompts: `Delete .tmux-session file? [y/N]` |
| `-d`, `--delete-template` | Skip prompt, delete `.tmux-session` |
| `-k`, `--keep-template` | Skip prompt, preserve `.tmux-session` |

**Edit registry:**
```bash
hop edit
```
Opens `~/.hop-projects` in `$EDITOR` (falls back to `vi`).

---

### FR-10: Maintenance Commands

**Garbage collection:**
```bash
hop gc
```
- Iterates registry entries
- Removes entries where path no longer exists on filesystem
- Reports actions taken: `Removed: /home/user/deleted-project`

**Session pruning:**
```bash
hop prune
```
- Lists running tmux sessions matching registered projects
- Identifies sessions whose project directories no longer exist
- Prompts: `Kill session 'old-project'? [y/N]`
- `-f`, `--force` flag skips confirmation

---

### FR-11: Dry Run Mode

```bash
hop -n <command>    # or: hop --dry-run <command>
```

Applies to: `mark`, `unmark`, `allow`, `refresh`, `gc`, `prune`, and default selection flow.

| Behavior | Description |
|----------|-------------|
| Output | Prints commands/operations that would be executed |
| Side effects | None — no files modified, no tmux commands run |
| Format | Prefixed with `[dry-run]` |

Example:
```
$ hop -n mark node
[dry-run] Would copy /home/user/.config/hop/templates/node to /home/user/work/api/.tmux-session
[dry-run] Would append to ~/.hop-projects: /home/user/work/api:node:e3b0c44298fc...
```

---

### FR-12: Template Refresh

```bash
hop refresh [path]
```

Re-copies the original template from `~/.config/hop/templates/` to the project's `.tmux-session` file, updating the stored hash.

| Behavior | Description |
|----------|-------------|
| `[path]` | Defaults to `$PWD` |
| Lookup | Reads template name from registry for the given path |
| Template check | Verifies template still exists in `~/.config/hop/templates/`; error if missing |
| Overwrite | Replaces `<path>/.tmux-session` with fresh copy from template |
| Hash update | Recomputes SHA-256 and updates registry |
| Confirmation | Prompts: `Overwrite .tmux-session with template '<name>'? [y/N]` |
| `-f`, `--force` | Skip confirmation prompt |

**Use case:** User has updated their templates in `~/.config/hop/templates/` and wants to propagate changes to existing projects.

**Error conditions:**
- Path not in registry: `Error: /path/to/project is not marked`
- Template no longer exists: `Error: Template 'oldtemplate' not found in ~/.config/hop/templates/`

Example:
```bash
$ hop refresh ~/work/api
Overwrite .tmux-session with template 'backend'? [y/N] y
Refreshed: /home/user/work/api [backend]
```

---

### FR-13: Version Information

```bash
hop version
```

Output: `hop 0.1`

---

### FR-14: Help

```bash
hop help
```

Displays comprehensive usage information covering all commands and options.

---

### FR-15: Installation & Maintenance Commands

**Self-update:**
```bash
hop self-update
```

| Behavior | Description |
|----------|-------------|
| Version check | Queries GitHub API for latest release |
| Comparison | Compares semver versions numerically |
| Update | Downloads and runs installer if newer version available |
| Up-to-date | Prints "Already at latest version" if current |

**Extra templates:**
```bash
hop extras              # List available extras
hop extras install      # Install all extras
hop extras install node python  # Install specific extras
```

| Behavior | Description |
|----------|-------------|
| List | Shows available extra templates (node, python, go, rust, docker) |
| Install | Downloads extras from GitHub release matching installed version |
| Location | Copies templates to `~/.config/hop/templates/` |

**Shell completions:**
```bash
hop completion bash      # Output bash completions to stdout
hop completion zsh       # Output zsh completions to stdout
hop completion --how-to  # Print installation instructions
```

Output is sent to stdout for redirection. Users install by redirecting to appropriate location:
- Bash: `hop completion bash > ~/.local/share/bash-completion/completions/hop`
- Zsh: `hop completion zsh > ~/.zsh/completions/_hop`

**Uninstall:**
```bash
hop uninstall
```

| Behavior | Description |
|----------|-------------|
| Confirmation | Prompts before removal unless `-f` specified |
| `--keep-templates` | Preserves `~/.config/hop/templates/` |
| Removes | `~/.local/bin/hop`, `~/.local/share/man/man1/hop.1`, `~/.config/hop/` |
| Reminder | Prints instructions for removing shell completions |

---

## Non-Functional Requirements

### NFR-1: Bash Native

- Shebang: `#!/usr/bin/env bash`
- Minimum version: Bash 4.0+
- Permitted features: Associative arrays, `[[`, extended globbing, process substitution
- POSIX compliance: **Not a goal**

---

### NFR-2: Single Portable Script

- Distribution: Single file named `hop`
- Installation: Copy to directory in `$PATH`, ensure `~/.config/hop/templates/` exists with `default` template
- No compilation required

---

### NFR-3: Dependencies

**Required:**

| Dependency | Minimum Version | Purpose |
|------------|-----------------|---------|
| `bash` | 4.0+ | Script execution |
| `tmux` | 3.0+ | Session management |
| `fzf` | Any | Fuzzy selection |
| `sha256sum` | Any (coreutils) | Template integrity |

**Optional:**

| Dependency | Purpose |
|------------|---------|
| `git` | Enhanced preview (commit log) |

---

### NFR-4: Performance

| Metric | Target |
|--------|--------|
| Selection UI appearance | < 100ms for ≤500 projects |
| Registry operations | O(n) where n = marked projects |
| Background processes | None — no daemons |

---

### NFR-5: Idempotency

| Operation | Idempotent Behavior |
|-----------|---------------------|
| `mark` on marked project | Error (no overwrite) |
| Select active session | Attach without re-sourcing template |
| `gc` | Safe to run repeatedly |
| `prune` | Safe to run repeatedly |
| `refresh` | Safe to run repeatedly (same result if template unchanged) |

---

### NFR-6: Signal Handling

| Signal | Context | Behavior |
|--------|---------|----------|
| `SIGINT` | During fzf selection | Exit status `0` |
| `SIGINT` | During template sourcing | Exit status `130`, cleanup partial session |
| `SIGTERM` | Any | Graceful exit, no orphaned sessions |

---

### NFR-7: File System Layout

| Type | Location |
|------|----------|
| Executable | `~/.local/bin/hop` |
| Man page | `~/.local/share/man/man1/hop.1` |
| Registry (state) | `~/.hop-projects` |
| Version file | `~/.config/hop/.version` |
| Templates (config) | `~/.config/hop/templates/` |
| Per-project config | `<project>/.tmux-session` |

---

## Command Reference

| Command | Description |
|---------|-------------|
| `hop` | Fuzzy-select and attach to project session |
| `hop mark <template> [path]` | Register project with template |
| `hop unmark [path]` | Remove project from registry |
| `hop allow [path]` | Trust modified `.tmux-session` (update hash) |
| `hop refresh [path]` | Re-copy template from source, update hash |
| `hop list` | Show all registered projects with status |
| `hop templates` | List available templates (alias: `tpls`) |
| `hop edit` | Open registry in `$EDITOR` |
| `hop gc` | Remove entries for deleted directories |
| `hop prune` | Kill sessions for deleted directories |
| `hop self-update` | Update hop to latest version |
| `hop extras [install] [names]` | List or install extra templates |
| `hop completion <shell>` | Output shell completions to stdout |
| `hop uninstall` | Remove hop from system |
| `hop -n <cmd>` | Preview actions without execution (alias: `--dry-run`) |
| `hop version` | Print version |
| `hop help` | Print usage |

---

## Default Template

Ships with installation at `~/.config/hop/templates/default`:

```bash
#!/usr/bin/env bash
# Default template - single window
# Available variables: $SESSION_NAME, $PROJECT_PATH

tmux rename-window -t "$SESSION_NAME:1" "default"
```

---

## Example Session

```bash
# Mark a new project
$ cd ~/work/myapp
$ hop mark node
Marked: /home/user/work/myapp [node]

# List projects
$ hop list
work-myapp    /home/user/work/myapp    [node]    ✓

# Hop to project (creates session if needed)
$ hop
# → fzf opens, select "work-myapp", attached to tmux session

# Template was modified externally
$ hop
# → fzf opens, select "work-myapp"
Warning: .tmux-session has changed since marking. Continue? [y/N] n
Aborted.

# Trust the changes
$ hop allow ~/work/myapp
Allowed: /home/user/work/myapp (hash updated)

# Later: update the node template globally
$ vim ~/.config/hop/templates/node
# ... make improvements ...

# Propagate changes to existing project
$ hop refresh ~/work/myapp
Overwrite .tmux-session with template 'node'? [y/N] y
Refreshed: /home/user/work/myapp [node]

# Clean up stale entries
$ hop gc
Removed: /home/user/work/deleted-project

# Dry run to preview actions
$ hop -n refresh ~/work/api
[dry-run] Would copy /home/user/.config/hop/templates/backend to /home/user/work/api/.tmux-session
[dry-run] Would update hash in ~/.hop-projects for /home/user/work/api
```

---

## Delivery Checklist

- [ ] Single executable `hop` script
- [ ] Default template file (`default`)
- [ ] Installation instructions (README.md)
- [ ] Man page or `--help` comprehensive enough to serve as documentation

---

## Appendix A: Registry File Format

The registry file `~/.hop-projects` is a plain text file with one record per line.

**Format:**
```
<absolute_path>:<template_name>:<sha256_hash>
```

**Rules:**
- Paths must be absolute (start with `/`)
- Template names contain no colons
- Hash is lowercase hexadecimal, 64 characters (SHA-256)
- Lines starting with `#` may be treated as comments (optional)
- Empty lines are ignored

**Example:**
```
/home/user/work/api:backend:a3f2e1b8c9d0e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0
/home/user/personal/blog:default:b4c8d2e5f6a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7
```

---

## Appendix B: Template Examples

### Node.js Project

`~/.config/hop/templates/node`:
```bash
#!/usr/bin/env bash
# Node.js project - editor + server + shell

tmux rename-window -t "$SESSION_NAME:1" "edit"
tmux send-keys -t "$SESSION_NAME:1" "nvim ." C-m

tmux new-window -t "$SESSION_NAME" -n "server"
tmux send-keys -t "$SESSION_NAME:server" "npm run dev" C-m

tmux new-window -t "$SESSION_NAME" -n "shell"

tmux select-window -t "$SESSION_NAME:1"
```

### Python Project

`~/.config/hop/templates/python`:
```bash
#!/usr/bin/env bash
# Python project - editor + venv shell

tmux rename-window -t "$SESSION_NAME:1" "edit"
tmux send-keys -t "$SESSION_NAME:1" "source .venv/bin/activate && nvim ." C-m

tmux new-window -t "$SESSION_NAME" -n "shell"
tmux send-keys -t "$SESSION_NAME:shell" "source .venv/bin/activate" C-m

tmux select-window -t "$SESSION_NAME:1"
```

### Backend with Split Panes

`~/.config/hop/templates/backend`:
```bash
#!/usr/bin/env bash
# Backend project - editor + logs/server split

tmux rename-window -t "$SESSION_NAME:1" "edit"
tmux send-keys -t "$SESSION_NAME:1" "nvim ." C-m

tmux new-window -t "$SESSION_NAME" -n "server"
tmux split-window -t "$SESSION_NAME:server" -h -p 30
tmux send-keys -t "$SESSION_NAME:server.1" "make run" C-m
tmux send-keys -t "$SESSION_NAME:server.2" "tail -f logs/app.log" C-m

tmux select-window -t "$SESSION_NAME:1"
```

---

*End of specification.*
