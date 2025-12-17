<p align="center">
  <img src=".github/hop.png" alt="hop" width="400">
</p>

<h3 align="center">Jump between projects. Instantly.</h3>

<p align="center">
  <code>hop</code> is a tmux session manager that gets out of your way.<br>
  Mark your projects, define how they should look, and hop between them with a single keystroke.
</p>

---

## The Problem

You have 12 projects. Each needs an editor, a dev server, maybe a shell for git. Setting them up manually in tmux is tedious. Remembering which session is which? Worse.

## The Solution

```bash
hop
```

That's it. A fuzzy finder appears. Pick a project. You're there—windows configured, commands running, exactly how you left it (or exactly how you defined it).

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/mattmezza/hop/main/install.sh | bash

# Mark your first project
cd ~/work/my-app
hop mark default

# From anywhere, anytime
hop
```

## How It Works

1. **Mark** projects with templates that define your tmux layout
2. **Hop** between them instantly via fuzzy search
3. **Trust** that your session configs haven't been tampered with (SHA-256 verified)

## Templates

Templates are simple bash scripts. Here's one for a Node.js project:

```bash
#!/usr/bin/env bash
# Node.js - editor + server + shell

tmux rename-window -t "$SESSION_NAME:1" "edit"
tmux send-keys -t "$SESSION_NAME:1" "nvim ." C-m

tmux new-window -t "$SESSION_NAME" -n "server"
tmux send-keys -t "$SESSION_NAME:server" "npm run dev" C-m

tmux new-window -t "$SESSION_NAME" -n "shell"
tmux select-window -t "$SESSION_NAME:1"
```

Install extras with `hop extras install` or create your own in `~/.config/hop/templates/`.

## Commands

| Command | What it does |
|---------|--------------|
| `hop` | Fuzzy-select a project and jump to it |
| `hop mark <template>` | Register current directory |
| `hop list` | See all your projects |
| `hop templates` | List available templates |
| `hop unmark` | Remove a project |
| `hop help` | Everything else |

## Requirements

- bash 4.0+
- tmux 3.0+
- fzf
- curl (for install/updates)

## License

MIT

---

<p align="center">
  <i>Stop managing tmux sessions. Start shipping.</i>
</p>
