# power-git Documentation

Welcome to the official documentation for **power-git** — a fast, feature-rich Git prompt and tab-completion engine for **Windows PowerShell 5.1+** and **PowerShell 7+** across Windows, Linux, and macOS.

---

## ⚡ Key Highlights

* **High Performance Status Parsing**: Uses a single `git status --porcelain=v2 --branch` command to capture repository state in one pass.
* **Smart Non-Blocking Caching**: Status queries are cached for 500 ms by default, avoiding input lag on rapid keystrokes.
* **4 Built-in Themes**: `Default` (Unicode), `Minimal` (Compact), `ASCII` (Maximum compatibility), and `Powerline` (Nerd Font glyphs).
* **Interactive Rebase Counter**: Tracks rebase progress with live step indicators (`REBASING 3/10`).
* **Monorepo File Status Opt-out**: Disable expensive file status enumerations for specific large monorepos without affecting other repositories.
* **30+ Subcommands & Alias-Aware Completion**: Full tab-completion support for branches, tags, remotes, files, stashes, worktrees, and user-defined git aliases.

---

## 🚀 Quick Reference

| Action | Command |
| :--- | :--- |
| **Apply Theme** | `Set-GitTheme Default` \| `Minimal` \| `ASCII` \| `Powerline` |
| **Run Diagnostic** | `Test-PowerGit` |
| **Show Quick Help** | `Show-PowerGitHelp` |
| **Enable/Disable Prompt** | `Enable-GitPrompt` / `Disable-GitPrompt` |
| **Opt-out Monorepo File Status** | `Disable-GitFileStatus` |
| **Auto-load on Startup** | `Add-PowerGitToProfile` |

---

## 📖 Navigation

* [Getting Started](getting-started.md): Installation, prerequisites, and profile setup.
* [Configuration](configuration.md): Customizing `$global:PowerGitSettings`, caching, and monorepo overrides.
* [Themes & Styling](themes.md): Exploring built-in themes, color tokens, and custom symbol configurations.
* [Tab Completion](tab-completion.md): Supported subcommands, flag completion, and alias resolution.
* [Architecture](architecture.md): Porcelain v2 parsing design, execution benchmarking, and cache engine details.
* [Troubleshooting](troubleshooting.md): Diagnosing installation issues, font setup, and terminal ANSI configuration.
