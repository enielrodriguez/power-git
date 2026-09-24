# AGENTS.md - Antigravity & Gemini AI Agent Rules

## Project Identity & Architectural Mission
`power-git` is an ultra-fast, cross-platform Git prompt and tab-completion module for **PowerShell 5.1+** and **PowerShell 7+** (Windows, Linux, macOS).

The foundational principle of this project is **zero prompt lag**. All AI agents contributing code to this repository must preserve low-latency prompt generation and cross-platform reliability.

---

## 🎯 Non-Negotiable Engineering Rules

1. **PowerShell 5.1 & PowerShell 7 Dual Compatibility**:
   - Every file modified must execute without errors in both Windows PowerShell 5.1 (Desktop Edition) and PowerShell 7.0+ (Core Edition).
   - Do NOT use PS 6+ features (`$IsWindows`, `Select-Object -SkipLast`, `[System.Runtime.InteropServices.RuntimeInformation]`) without explicit backward-compatibility fallbacks.
   - Standardize OS detection on `[System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT`.

2. **Single-Subprocess Porcelain V2 Rule**:
   - Prompt generation MUST depend on a single `git status --porcelain=v2 --branch` call.
   - NEVER introduce additional `git` process invocations inside `Get-GitStatus` or prompt rendering functions.
   - Extract branch names, detached HEAD commit hashes, upstream tracking status, and file counts strictly from porcelain v2 header/status lines.
   - For stash counts, inspect `.git/logs/refs/stash` directly rather than invoking `git stash list`.

3. **PowerShell 5.1 Cross-File Class Resolution Scoping**:
   - In PS 5.1, custom class types (`PowerGitSettings`, `GitStatus`) defined in dot-sourced files cannot be resolved as parameter type constraints in other files (`GitPrompt.ps1`).
   - Use duck typing / loose parameter signatures in `src/GitPrompt.ps1` to prevent runtime `TypeNotFound` exceptions in PowerShell 5.1.

4. **Prompt Resilience**:
   - `prompt` function overrides must be bulletproof. Wrap all prompt evaluations in `try { ... } catch {}` blocks. Under no circumstances should an error in `power-git` break or corrupt the user's interactive command prompt.

5. **Empirical Verification Required**:
   - NEVER claim a bug is fixed or a feature is implemented without running empirical verification using `pwsh`:
     ```powershell
     pwsh -NoProfile -Command "Import-Module ./power-git.psd1; Test-PowerGit"
     ```

---

## 📁 Codebase Map

- [power-git.psd1](file:///home/eniel/Downloads/dev/power-git/power-git.psd1): Module Manifest (v1.0.0, exported functions, metadata).
- [power-git.psm1](file:///home/eniel/Downloads/dev/power-git/power-git.psm1): Root module file (prerequisites check, sources `src/`, overrides `global:prompt`, registers completers).
- [src/Settings.ps1](file:///home/eniel/Downloads/dev/power-git/src/Settings.ps1): Configuration model (`PowerGitColor`, `PowerGitSymbols`, `PowerGitSettings`) & 4 built-in themes.
- [src/GitUtils.ps1](file:///home/eniel/Downloads/dev/power-git/src/GitUtils.ps1): Git CLI helper wrappers.
- [src/GitStatus.ps1](file:///home/eniel/Downloads/dev/power-git/src/GitStatus.ps1): Status object model (`GitStatus`), porcelain v2 parser, and 500ms status cache engine.
- [src/GitPrompt.ps1](file:///home/eniel/Downloads/dev/power-git/src/GitPrompt.ps1): Prompt formatting engine (ANSI & Legacy modes).
- [src/GitCompletion.ps1](file:///home/eniel/Downloads/dev/power-git/src/GitCompletion.ps1): Native argument completer (`Register-ArgumentCompleter`) for 30+ git subcommands & git aliases.
- [docs/](file:///home/eniel/Downloads/dev/power-git/docs/index.md): Docs as Code documentation suite.
- [mkdocs.yml](file:///home/eniel/Downloads/dev/power-git/mkdocs.yml): MkDocs configuration file.
