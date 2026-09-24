# power-git

[![Docs as Code CI](https://github.com/power-git/power-git/actions/workflows/docs.yml/badge.svg)](https://github.com/power-git/power-git/actions/workflows/docs.yml)
[![PowerShell Version](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-blue.svg)](https://microsoft.com/powershell)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)](https://github.com/power-git/power-git)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A fast, feature-rich Git prompt and tab-completion engine for **Windows PowerShell 5.1+** and **PowerShell 7+** across Windows, Linux, and macOS.

A modern, high-performance alternative to [posh-git](https://github.com/dahlbyk/posh-git) powered by single-call status parsing, result caching, and alias-aware tab completion.

---

## ⚡ Key Features

* **⚡ Ultra Fast** — Uses a single `git status --porcelain=v2 --branch` call instead of multiple git process invocations.
* **🗄️ Status Caching** — In-memory caching (default 500 ms) ensures prompt redraws never block keystrokes.
* **🎨 4 Built-in Themes** — `Default` (Unicode), `Minimal` (Compact), `ASCII` (Maximum compatibility), and `Powerline` (Nerd Font glyphs).
* **🔄 Rebase Step Counter** — Shows live interactive rebase progress (e.g., `REBASING 3/10`).
* **📦 Monorepo File Status Opt-Out** — Disable file counts for large monorepos without affecting other repositories.
* **💡 Alias-Aware Tab Completion** — Resolves custom `git` aliases and completes arguments for 30+ subcommands.
* **🖥️ Cross-Platform & Dual Rendering** — Full ANSI color on Windows Terminal / VS Code / Linux / macOS, with `Write-Host` fallback for legacy Windows console.

---

## 🔍 Prompt Anatomy

```
PS C:\repo [main ↑2 | +1 ~3 ?2 ≡1]>
           └────────────────────────┘
                  git segment
```

| Segment | Meaning |
| :--- | :--- |
| `main` | Current branch name (or short commit hash if detached HEAD) |
| `↑2` | 2 commits ahead of upstream |
| `↓3` | 3 commits behind upstream |
| `⇅ +2 -1` | Diverged (ahead and behind simultaneously) |
| `✔` | In sync with upstream |
| `✗` | Upstream tracking branch deleted |
| `+N` | N files added (staged) |
| `+~N` | N files modified (staged) |
| `+-N` | N files deleted (staged) |
| `~N` | N files modified (unstaged) |
| `?N` | N untracked files |
| `!N` | N merge conflicts |
| `≡N` | N stashed changesets |
| `REBASING 3/10` | Interactive rebase in progress (step 3 of 10) |

---

## 📚 Documentation (Docs as Code)

Comprehensive documentation is maintained directly alongside the codebase in the [`docs/`](docs/index.md) directory and built via MkDocs:

* 🚀 [Getting Started Guide](docs/getting-started.md) — Installation, requirements, and profile auto-loading.
* ⚙️ [Configuration Reference](docs/configuration.md) — `$global:PowerGitSettings`, caching, and monorepo overrides.
* 🎨 [Themes & Styling](docs/themes.md) — Built-in themes, symbol customization, and Nerd Font setup.
* 💡 [Tab Completion](docs/tab-completion.md) — 30+ subcommands, flag completion, and alias resolution.
* 🏗️ [Architecture & Design](docs/architecture.md) — Porcelain v2 parser details, caching engine, and benchmarks.
* 🩺 [Troubleshooting & FAQ](docs/troubleshooting.md) — Diagnostics cmdlet and common solutions.

---

## 🚀 Quick Start

```powershell
# 1. Install from PowerShell Gallery (recommended)
Install-Module power-git -Scope CurrentUser

# 2. Import module into your current session
Import-Module power-git

# 3. Choose a theme
Set-GitTheme Default      # Unicode symbols (works with standard fonts)
Set-GitTheme Minimal      # Compact ASCII
Set-GitTheme ASCII        # Pure 7-bit ASCII
Set-GitTheme Powerline    # Nerd Font glyphs

# 4. Auto-load power-git on every PowerShell startup
Add-PowerGitToProfile

# 5. Run diagnostics
Test-PowerGit
```

---

## 🛠️ Commands Reference

| Command | Description |
| :--- | :--- |
| `Test-PowerGit` | Diagnoses installation and displays current repo status. |
| `Show-PowerGitHelp` | Displays quick-reference for prompt symbols and settings. |
| `Set-GitTheme <Name>` | Switches active theme (`Default`, `Minimal`, `ASCII`, `Powerline`). |
| `Enable-GitPrompt` / `Disable-GitPrompt` | Toggles prompt integration on or off. |
| `Enable-GitFileStatus` / `Disable-GitFileStatus` | Toggles file counts (use `Disable-GitFileStatus` for large monorepos). |
| `Get-GitStatus` | Returns structured `GitStatus` object for the current directory. |
| `Clear-GitStatusCache` | Invalidates the status cache. |
| `Install-PowerGitFont` | Downloads and installs a Nerd Font for the Powerline theme (Windows). |
| `Add-PowerGitToProfile` / `Remove-PowerGitFromProfile` | Manages auto-load setup in your `$PROFILE`. |

---

## 📊 Comparison: power-git vs posh-git

| Feature | posh-git | power-git |
| :--- | :---: | :---: |
| **Git calls per prompt** | 3–5 processes | **1 process** |
| **Status caching** | ❌ No | **✅ Yes (configurable TTL)** |
| **Rebase step counter** | ❌ No | **✅ Yes (`REBASING N/M`)** |
| **Monorepo file status opt-out** | ❌ No | **✅ Yes (`Disable-GitFileStatus`)** |
| **Tab completion subcommands** | ~15 commands | **30+ commands** |
| **Alias-aware completion** | ❌ No | **✅ Yes** |
| **PowerShell compatibility** | 5.1+ | **5.1+ & 7+ (Win/Linux/macOS)** |

---

## 📄 License

[MIT License](LICENSE) © power-git contributors
