# CLAUDE.md - power-git Development Guide

## Overview
`power-git` is a fast Git prompt and tab-completion module for PowerShell 5.1+ and PowerShell 7+ on Windows, Linux, and macOS.

## Common Developer Commands

```powershell
# Import module and run diagnostic check
pwsh -NoProfile -Command "Import-Module ./power-git.psd1; Test-PowerGit"

# Test prompt string generation
pwsh -NoProfile -Command "Import-Module ./power-git.psd1; Get-GitPromptString"

# Test tab completion logic
pwsh -NoProfile -Command "Import-Module ./power-git.psd1; Get-Command git"

# Validate and build documentation site
mkdocs build --strict
```

## Core Architecture
- `power-git.psd1`: Module manifest (v1.0.0, exported functions, metadata).
- `power-git.psm1`: Root module file (prerequisites check, sources `src/`, overrides `global:prompt`, registers completers, exports functions).
- `src/Settings.ps1`: `PowerGitColor`, `PowerGitSymbols`, `PowerGitSettings` classes & 4 themes (`Default`, `Minimal`, `ASCII`, `Powerline`).
- `src/GitUtils.ps1`: Wrapper functions for git CLI invocations (`Invoke-Git`, `Get-GitDirectory`, etc.).
- `src/GitStatus.ps1`: Status data model (`GitStatus`), porcelain v2 parser (`ConvertFrom-GitPorcelainV2`), and 500ms in-memory status cache.
- `src/GitPrompt.ps1`: Prompt formatting engine (`Build-AnsiPrompt`, `Write-LegacyPrompt`).
- `src/GitCompletion.ps1`: `Register-ArgumentCompleter` logic for 30+ subcommands & git aliases.

## Code Style & Critical Constraints
1. **Dual PowerShell Target**: Code MUST run on both PowerShell 5.1 (Windows PowerShell) and PowerShell 7+ (Core).
2. **PS 5.1 Cross-File Class Constraint**: In PS 5.1, custom class parameters across dot-sourced files fail at runtime. Do NOT type-constrain cross-file class parameters in `GitPrompt.ps1` (use duck typing).
3. **Single Porcelain Call**: Prompt generation MUST rely on a single `git status --porcelain=v2 --branch` invocation. Do NOT add extra `git` subprocess spawns in prompt rendering loops.
4. **Platform Checks**: Guard Windows-specific API calls (P/Invoke to `kernel32.dll` or registry access) with `[System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT`.
5. **Prompt Hook Safety**: Never crash the user prompt. Always catch prompt errors and fall back to original prompt.
