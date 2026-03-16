# power-git

A fast, feature-rich Git prompt and tab-completion module for **Windows PowerShell 5.1+**.

A better alternative to [posh-git](https://github.com/dahlbyk/posh-git) with a single-call status implementation, result caching, and richer tab completion.

---

## Features

- **Faster** — uses a single `git status --porcelain=v2 --branch` call instead of multiple git invocations
- **Caching** — status is cached for 500 ms by default, so repeated keystrokes never block the prompt
- **Four built-in themes** — Default, Minimal, ASCII, and Powerline (Nerd Font glyphs)
- **Rebase progress** — shows `REBASING 3/10` step counter during interactive rebases
- **Per-repo file status opt-out** — disable file counts for large monorepos without affecting others
- **Alias-aware tab completion** — resolves git aliases before dispatching completions
- **30+ subcommands** — branch, checkout, merge, rebase, cherry-pick, stash, remote, tag, worktree, and more
- **ANSI and Legacy modes** — full colour on Windows Terminal / VS Code; Write-Host fallback for the classic console

---

## Prompt anatomy

```
PS C:\repo [main ↑2 | +1 ~3 ?2 ≡1]>
           └────────────────────────┘
           git segment
```

| Segment | Meaning |
|---------|---------|
| `main` | Current branch name |
| `↑2` | 2 commits ahead of upstream |
| `↓3` | 3 commits behind upstream |
| `⇅ +2 -1` | Diverged (ahead and behind) |
| `✔` | In sync with upstream |
| `✗` | Upstream branch deleted |
| `+N` | N files added (staged) |
| `+~N` | N files modified (staged) |
| `+-N` | N files deleted (staged) |
| `~N` | N files modified (unstaged) |
| `?N` | N untracked files |
| `!N` | N merge conflicts |
| `≡N` | N stashed changesets |
| `REBASING 3/10` | Interactive rebase in progress |

---

## Requirements

- Windows PowerShell 5.1 (or PowerShell 7+)
- Git in your `PATH`
- A [Nerd Font](https://www.nerdfonts.com/) only if you use the **Powerline** theme

---

## Installation

### From PowerShell Gallery (recommended)

```powershell
Install-Module power-git -Scope CurrentUser
```

### Manual

1. Clone or download the repository into a folder named `power-git`
2. Copy the folder to one of your `$env:PSModulePath` directories, e.g.:
   ```
   %USERPROFILE%\Documents\WindowsPowerShell\Modules\power-git\
   ```
3. Import the module:
   ```powershell
   Import-Module power-git
   ```

### Auto-load on every session

```powershell
Add-PowerGitToProfile
```

---

## Quick start

```powershell
# Import once (or add to profile)
Import-Module power-git

# Pick a theme
Set-GitTheme Default      # Unicode symbols, any font
Set-GitTheme Minimal      # Compact ASCII
Set-GitTheme ASCII        # Pure ASCII, maximum compatibility
Set-GitTheme Powerline    # Nerd Font glyphs

# Install a Nerd Font for the Powerline theme (one-time, no admin needed)
Install-PowerGitFont                    # installs Cascadia Code NF
Install-PowerGitFont -Font FiraCode     # or FiraCode NF
Install-PowerGitFont -Font JetBrainsMono

# Diagnose your installation
Test-PowerGit

# See all symbols and commands explained
Show-PowerGitHelp
```

---

## Configuration

Settings live in `$global:PowerGitSettings`. You can edit properties directly:

```powershell
# Increase cache lifetime (ms) for slower machines
$global:PowerGitSettings.StatusCacheMs = 1000

# Truncate long branch names
$global:PowerGitSettings.BranchMaxLength = 25

# Hide stash count
$global:PowerGitSettings.ShowStashCount = $false

# Disable file counts for a large monorepo (current directory)
Disable-GitFileStatus
```

---

## Commands

| Command | Description |
|---------|-------------|
| `Test-PowerGit` | Diagnose installation and show current repo status |
| `Show-PowerGitHelp` | Quick-reference for all prompt symbols and commands |
| `Set-GitTheme <name>` | Switch theme: `Default`, `Minimal`, `ASCII`, `Powerline` |
| `Enable-GitPrompt` | Turn prompt integration on |
| `Disable-GitPrompt` | Turn prompt integration off |
| `Enable-GitFileStatus` | Show file counts in prompt (default) |
| `Disable-GitFileStatus` | Hide file counts for the current repo |
| `Get-GitStatus` | Return a `GitStatus` object for the current directory |
| `Clear-GitStatusCache` | Invalidate the status cache |
| `Install-PowerGitFont` | Download and install a Nerd Font (no admin required) |
| `Add-PowerGitToProfile` | Add `Import-Module power-git` to your profile |
| `Remove-PowerGitFromProfile` | Remove it from your profile |

---

## Themes

### Default
Unicode symbols, works with any standard font.
```
[main ↑2 | +~1 ?3 ≡1]
```

### Minimal
Compact, ASCII-safe symbols.
```
[main ^2 | +~1 ?3 $1]
```

### ASCII
Pure ASCII, maximum terminal compatibility.
```
[main ^2 | ++1 *3]
```

### Powerline
Nerd Font glyphs. Requires a [Nerd Font](https://www.nerdfonts.com/) — run `Install-PowerGitFont` to install one automatically.
```
 main ↑2 | +~1 ?3 ≡1
```

---

## Why not posh-git?

| | posh-git | power-git |
|--|----------|-----------|
| Git calls per prompt | 3–5 | **1** |
| Status caching | No | **Yes (configurable)** |
| Rebase step counter | No | **Yes** |
| Per-repo file status opt-out | No | **Yes** |
| Tab completion subcommands | ~15 | **30+** |
| Alias-aware completion | No | **Yes** |
| PowerShell version | 5.1+ | **5.1+** |

---

## License

MIT
