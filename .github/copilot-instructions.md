# GitHub Copilot Instructions for power-git

## Project Context
`power-git` is a high-performance Git prompt and argument completion module written in PowerShell. It targets **Windows PowerShell 5.1+** and **PowerShell 7+** across Windows, Linux, and macOS.

The primary architectural goal of `power-git` is maximum prompt responsiveness. It achieves this by using a single `git status --porcelain=v2 --branch` invocation and caching status results in memory (default 500 ms).

---

## 🛠️ Language & Platform Constraints

1. **PowerShell 5.1 & PowerShell 7 Compatibility**:
   - All code must execute cleanly under both Windows PowerShell 5.1 (Desktop Edition) and PowerShell 7+ (Core Edition).
   - Do NOT use PS 6+ only features without a fallback (e.g. `$IsWindows`, array slicing vs `Select-Object -SkipLast`, `[System.Runtime.InteropServices.RuntimeInformation]`).
   - For OS detection, prefer `[System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT` or check `$env:OS` for Windows compatibility across PS 5.1 and PS 7.

2. **PowerShell 5.1 Class Type Scoping Rule**:
   - In PowerShell 5.1, custom class types defined in one file (`src/Settings.ps1` / `src/GitStatus.ps1`) cannot be used as strongly-typed parameter constraints in functions defined in other files (`src/GitPrompt.ps1`).
   - Use **duck typing** or primitive type comparisons (e.g., `$Settings.WriterMode -ne 'Legacy'`) for cross-file parameter signatures in `src/GitPrompt.ps1`.

3. **Performance & Subprocess Rules**:
   - **Zero Extra Subprocesses**: Never introduce extra `git` CLI process spawns inside the prompt rendering loop.
   - Obtain branch name, detached HEAD hash, upstream tracking, ahead/behind counters, and file status counts strictly from the porcelain v2 output.
   - Stash counts must be read from `.git/logs/refs/stash` directly rather than spawning `git stash list`.

---

## 📐 Coding Conventions & Best Practices

- **Cmdlet Binding**: Decorate all public functions with `[CmdletBinding()]` and specify `[OutputType()]` where applicable.
- **Naming**: Use standard PowerShell `Verb-Noun` pairs for functions (e.g., `Get-GitStatus`, `Write-GitPrompt`, `Set-GitTheme`).
- **Error Suppression**: Suppress non-critical external executable errors using `2>$null` or `try { ... } catch {}`. Prompt generation must **never** throw unhandled exceptions or crash the user's shell prompt.
- **Module Exports**: Maintain explicit function and variable exports in `power-git.psd1` (`FunctionsToExport`) and `power-git.psm1` (`Export-ModuleMember`).

---

## 🧪 Testing & Verification

Always verify changes by executing the module under PowerShell 7 (`pwsh`):

```powershell
pwsh -NoProfile -Command "Import-Module ./power-git.psd1; Test-PowerGit"
```
