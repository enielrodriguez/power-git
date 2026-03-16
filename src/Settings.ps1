#requires -Version 5.1
# Settings.ps1 - Configuration system for power-git
# Provides typed settings, theme support, and per-repo overrides

class PowerGitColor {
    [string]$Ansi      # ANSI escape sequence (e.g. "$([char]27)[32m")
    [System.ConsoleColor]$Legacy   # Legacy console color

    PowerGitColor([string]$ansi, [System.ConsoleColor]$legacy) {
        $this.Ansi   = $ansi
        $this.Legacy = $legacy
    }

    static [PowerGitColor] FromRgb([byte]$r, [byte]$g, [byte]$b, [System.ConsoleColor]$legacy) {
        return [PowerGitColor]::new("$([char]27)[38;2;${r};${g};${b}m", $legacy)
    }
    static [PowerGitColor] FromAnsi256([byte]$n, [System.ConsoleColor]$legacy) {
        return [PowerGitColor]::new("$([char]27)[38;5;${n}m", $legacy)
    }
    static [PowerGitColor] Reset() {
        return [PowerGitColor]::new("$([char]27)[0m", [System.ConsoleColor]::Gray)
    }
}

class PowerGitSymbols {
    [string]$Branch          = [char]0xE0A0  # Powerline branch (overridden by theme)
    [string]$Detached        = [char]0x27A6  # ➦
    [string]$Ahead           = [char]0x2191  # ↑
    [string]$Behind          = [char]0x2193  # ↓
    [string]$Diverged        = [char]0x21C5  # ⇅
    [string]$UpToDate        = [char]0x2714  # ✔
    [string]$Gone            = [char]0x2717  # ✗
    [string]$Staged          = [char]0x2022  # •  (indexed changes)
    [string]$Unstaged        = [char]0x00B1  # ±  (working dir changes)
    [string]$Untracked       = [char]0x2026  # …  (untracked files)
    [string]$Conflict        = [char]0x25C6  # ◆
    [string]$Stash           = [char]0x2261  # ≡
    [string]$Merging         = 'MERGING'
    [string]$Rebasing        = 'REBASING'
    [string]$CherryPicking   = 'CHERRY-PICKING'
    [string]$Reverting       = 'REVERTING'
    [string]$Bisecting       = 'BISECTING'
}

class PowerGitSettings {
    # Rendering mode: 'Ansi' (ANSI escape sequences) or 'Legacy' (Write-Host ConsoleColor)
    [string]$WriterMode = 'Ansi'

    # Show git status in prompt
    [bool]$EnablePrompt = $true

    # Show file-level status counts (index/working). Disable for large repos.
    [bool]$ShowFileStatus = $true

    # Show stash count
    [bool]$ShowStashCount = $true

    # Show tag distance (e.g. v1.2-3-gabcdef)
    [bool]$ShowTagDistance = $false

    # Truncate long branch names to this length (0 = no truncation)
    [int]$BranchMaxLength = 0

    # Cache git status for this many milliseconds (0 = no cache)
    [int]$StatusCacheMs = 500

    # Repos to skip file status (large monorepos)
    [System.Collections.Generic.HashSet[string]]$DisableFileStatusRepos =
        [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    # Colors
    [PowerGitColor]$BranchColor           = [PowerGitColor]::new("$([char]27)[32m",  [System.ConsoleColor]::Green)
    [PowerGitColor]$BranchAheadColor      = [PowerGitColor]::new("$([char]27)[36m",  [System.ConsoleColor]::Cyan)
    [PowerGitColor]$BranchBehindColor     = [PowerGitColor]::new("$([char]27)[33m",  [System.ConsoleColor]::Yellow)
    [PowerGitColor]$BranchDivergedColor   = [PowerGitColor]::new("$([char]27)[31m",  [System.ConsoleColor]::Red)
    [PowerGitColor]$BranchGoneColor       = [PowerGitColor]::new("$([char]27)[90m",  [System.ConsoleColor]::DarkGray)
    [PowerGitColor]$StagedColor           = [PowerGitColor]::new("$([char]27)[32m",  [System.ConsoleColor]::Green)
    [PowerGitColor]$UnstagedColor         = [PowerGitColor]::new("$([char]27)[33m",  [System.ConsoleColor]::Yellow)
    [PowerGitColor]$ConflictColor         = [PowerGitColor]::new("$([char]27)[31;1m",[System.ConsoleColor]::Red)
    [PowerGitColor]$UntrackedColor        = [PowerGitColor]::new("$([char]27)[90m",  [System.ConsoleColor]::DarkGray)
    [PowerGitColor]$StateColor            = [PowerGitColor]::new("$([char]27)[35m",  [System.ConsoleColor]::Magenta)
    [PowerGitColor]$StashColor            = [PowerGitColor]::new("$([char]27)[36m",  [System.ConsoleColor]::Cyan)
    [PowerGitColor]$DelimiterColor        = [PowerGitColor]::new("$([char]27)[37m",  [System.ConsoleColor]::Gray)
    [PowerGitColor]$ResetColor            = [PowerGitColor]::Reset()

    # Symbols
    [PowerGitSymbols]$Symbols = [PowerGitSymbols]::new()

    # Prompt delimiters
    [string]$BeforeText = ' ['
    [string]$AfterText  = ']'

    # Apply a named theme
    [void] ApplyTheme([string]$name) {
        switch ($name) {
            'Default'   { & $script:Themes['Default']   $this; break }
            'Minimal'   { & $script:Themes['Minimal']   $this; break }
            'Powerline' { & $script:Themes['Powerline'] $this; break }
            'ASCII'     { & $script:Themes['ASCII']     $this; break }
            default     { Write-Warning "power-git: Unknown theme '$name'. Available: Default, Minimal, Powerline, ASCII" }
        }
    }
}

# Theme registry
$script:Themes = @{}

# Default theme - sensible defaults with Unicode symbols
$script:Themes['Default'] = {
    param($s)
    $s.Symbols.Branch        = ''
    $s.Symbols.Ahead         = [char]0x2191
    $s.Symbols.Behind        = [char]0x2193
    $s.Symbols.Diverged      = [char]0x21C5
    $s.Symbols.UpToDate      = [char]0x2714
    $s.Symbols.Gone          = [char]0x2717
    $s.Symbols.Staged        = '+'
    $s.Symbols.Unstaged      = '~'
    $s.Symbols.Untracked     = '?'
    $s.Symbols.Conflict      = '!'
    $s.Symbols.Stash         = [char]0x2261
    $s.BeforeText            = ' ['
    $s.AfterText             = ']'
}

# Minimal theme - plain ASCII, no colors on branch name
$script:Themes['Minimal'] = {
    param($s)
    & $script:Themes['Default'] $s
    $s.Symbols.Branch    = ''
    $s.Symbols.Ahead     = '^'
    $s.Symbols.Behind    = 'v'
    $s.Symbols.Diverged  = '<>'
    $s.Symbols.UpToDate  = '='
    $s.Symbols.Gone      = 'x'
    $s.Symbols.Stash     = '$'
    $s.ShowStashCount    = $false
    $s.ShowTagDistance   = $false
}

# ASCII theme - pure ASCII, maximum compatibility
$script:Themes['ASCII'] = {
    param($s)
    & $script:Themes['Minimal'] $s
    $s.Symbols.Staged    = '+'
    $s.Symbols.Unstaged  = '*'
    $s.Symbols.Untracked = '?'
    $s.Symbols.Conflict  = '!'
}

# Powerline theme - nerd fonts glyphs
$script:Themes['Powerline'] = {
    param($s)
    & $script:Themes['Default'] $s
    $s.Symbols.Branch    = [char]0xE0A0   #
    $s.Symbols.Detached  = [char]0xE0A3   #
    $s.Symbols.Staged    = [char]0xF067   # (plus)
    $s.Symbols.Unstaged  = [char]0xF069   # (asterisk-like)
    $s.Symbols.Conflict  = [char]0xF06A   # (exclamation)
    $s.Symbols.Untracked = [char]0xF128   # (question)
    $s.Symbols.Stash     = [char]0xF01C   # (inbox)
    $s.BeforeText        = " $([char]0xE0B0) "
    $s.AfterText         = " $([char]0xE0B1)"
}

# Factory function - creates fresh settings with auto-detected writer mode
function New-PowerGitSettings {
    [OutputType([PowerGitSettings])]
    param(
        [string]$Theme = 'Default'
    )
    $settings = [PowerGitSettings]::new()

    # Auto-detect ANSI support
    if (-not $env:TERM_PROGRAM -and
        -not $env:WT_SESSION -and
        -not $env:TERM -and
        $Host.Name -eq 'ConsoleHost' -and
        [System.Environment]::OSVersion.Version.Major -lt 10) {
        $settings.WriterMode = 'Legacy'
    }

    $settings.ApplyTheme($Theme)
    return $settings
}
