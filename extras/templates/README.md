# Extra Templates

This directory contains optional templates that users can install via `hop extras install`.

## templates/ vs extras/templates/

| Directory | Purpose | Installed by default |
|-----------|---------|---------------------|
| `templates/` | Generic templates useful to everyone (e.g., `default`) | Yes |
| `extras/templates/` | Language/framework-specific templates | No (opt-in) |

The `default` template ships with every installation because it works for any project. Extra templates assume specific tooling (npm, cargo, docker, etc.) and are installed on demand.

## Creating a Good Template

### Basics

Templates are bash scripts sourced with two variables:

```bash
$SESSION_NAME   # e.g., "work-myapp"
$PROJECT_PATH   # e.g., "/home/user/work/myapp"
```

The session already exists and is cd'd into `$PROJECT_PATH` when your template runs.

### Structure

```bash
#!/usr/bin/env bash
# Short description (shown in `hop templates`)
# Available variables: $SESSION_NAME, $PROJECT_PATH

# Rename the default window
tmux rename-window -t "$SESSION_NAME:1" "edit"
tmux send-keys -t "$SESSION_NAME:1" "${EDITOR:-nvim} ." C-m

# Add more windows as needed
tmux new-window -t "$SESSION_NAME" -n "server"
tmux send-keys -t "$SESSION_NAME:server" "npm run dev" C-m

# Return to first window
tmux select-window -t "$SESSION_NAME:1"
```

### Best Practices

1. **Use `${EDITOR:-nvim}`** — Respect the user's editor preference with a sensible fallback.

2. **Don't auto-run destructive commands** — Prefer typing commands without `C-m` for things like `rm` or database operations:
   ```bash
   tmux send-keys -t "$SESSION_NAME:danger" "npm run db:reset"  # No C-m
   ```

3. **Check for tools before using them** — Graceful degradation:
   ```bash
   if command -v cargo-watch &>/dev/null; then
       tmux send-keys -t "$SESSION_NAME:watch" "cargo watch -x check" C-m
   else
       tmux send-keys -t "$SESSION_NAME:watch" "cargo build"
   fi
   ```

4. **Check for project files** — Not every project has the same structure:
   ```bash
   if [[ -d ".venv" ]]; then
       tmux send-keys -t "$SESSION_NAME:1" "source .venv/bin/activate && $EDITOR ." C-m
   else
       tmux send-keys -t "$SESSION_NAME:1" "$EDITOR ." C-m
   fi
   ```

5. **Keep the first comment line short** — It's displayed by `hop templates`:
   ```bash
   # Node.js project - editor, server, shell     <- Good
   # A comprehensive template for Node.js...     <- Too long
   ```

6. **End with `select-window`** — Return focus to a sensible starting point:
   ```bash
   tmux select-window -t "$SESSION_NAME:1"
   ```

### Testing Your Template

```bash
# Copy to your templates directory
cp my-template ~/.config/hop/templates/

# Mark a test project
cd /tmp/test-project
hop mark my-template

# Hop to it (creates the session)
hop
```

If something's wrong, kill the session and try again:
```bash
tmux kill-session -t <session-name>
```

## Contributing

To add a template to extras:

1. Create the template file (no extension)
2. Test it thoroughly
3. Add it to `cmd_extras()` in `hop` if you want it listed
4. Submit a PR
