# Configuration Reference

All live runtime settings in `power-git` are accessible via the `$global:PowerGitSettings` configuration object.

---

## ⚙️ Settings Properties

| Property | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `WriterMode` | `string` | `'Ansi'` | Prompt rendering mode: `'Ansi'` (VT escape sequences) or `'Legacy'` (`Write-Host` fallback). |
| `EnablePrompt` | `bool` | `$true` | Master switch for prompt status integration. |
| `ShowFileStatus` | `bool` | `$true` | Toggles file status counting (staged, unstaged, untracked, conflicts). |
| `ShowStashCount` | `bool` | `$true` | Toggles display of stashed changesets count (`≡N`). |
| `ShowTagDistance` | `bool` | `$false` | Shows distance to nearest git tag (e.g., `v1.2-3-gabcdef`). |
| `BranchMaxLength` | `int` | `0` | Truncates branch names longer than N characters (0 = no truncation). |
| `StatusCacheMs` | `int` | `500` | Duration (in milliseconds) to cache status queries. |
| `DisableFileStatusRepos` | `HashSet[string]` | `@()` | Set of repository root paths where file status counting is disabled. |
| `BeforeText` | `string` | `' ['` | Opening delimiter before the git prompt segment. |
| `AfterText` | `string` | `']'` | Closing delimiter after the git prompt segment. |

---

## 🛠️ Usage Examples

### Modify Cache Expiration
On slower systems or NFS/network drives, increasing the cache lifetime prevents prompt lag:

```powershell
# Cache status results for 1 second
$global:PowerGitSettings.StatusCacheMs = 1000

# Disable caching completely (always query git)
$global:PowerGitSettings.StatusCacheMs = 0
```

### Truncate Long Branch Names
To prevent long git branch names from cluttering your prompt line:

```powershell
$global:PowerGitSettings.BranchMaxLength = 20
```

### Monorepo Opt-Out (File Status)
Scanning millions of untracked/modified files in a massive monorepo can slow down prompt generation. Disable file-level counts for the current repository:

```powershell
# Disable file status for current repository
Disable-GitFileStatus

# Re-enable file status for current repository
Enable-GitFileStatus
```

---

## 🎨 Color Customization

Colors are defined on `$global:PowerGitSettings` using `PowerGitColor` instances containing both an ANSI escape sequence and a legacy `ConsoleColor`:

```powershell
# Custom RGB color for branch name (ANSI mode)
$global:PowerGitSettings.BranchColor = [PowerGitColor]::FromRgb(100, 200, 255, [ConsoleColor]::Cyan)

# 256-color ANSI mode
$global:PowerGitSettings.StagedColor = [PowerGitColor]::FromAnsi256(118, [ConsoleColor]::Green)
```
