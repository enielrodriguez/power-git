#requires -Version 5.1
# GitPrompt.ps1 - Prompt formatting for power-git
#
# NOTE: No custom class type constraints are used as parameters here.
# PS 5.1 class/enum type tables are per-file; cross-file type references in
# parameter constraints fail at runtime. Duck typing is used instead.

# ──────────────────────────────────────────────────────────────────────────────
# Internal rendering helpers
# ──────────────────────────────────────────────────────────────────────────────

function Write-AnsiColor {
    param($Builder, $Color, [string]$Text)
    if ($Text) {
        $null = $Builder.Append($Color.Ansi)
        $null = $Builder.Append($Text)
    }
}

function Write-LegacyColor {
    param($Color, [string]$Text)
    if ($Text) {
        Write-Host -NoNewline -ForegroundColor $Color.Legacy $Text
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Branch name rendering
# ──────────────────────────────────────────────────────────────────────────────

function Format-BranchName {
    param($Branch, $Settings)

    $sym  = if ($Branch.IsDetached) { $Settings.Symbols.Detached } else { $Settings.Symbols.Branch }
    $name = $Branch.Name

    if ($Settings.BranchMaxLength -gt 0 -and $name.Length -gt $Settings.BranchMaxLength) {
        $keep = [Math]::Max($Settings.BranchMaxLength - 1, 3)
        $name = $name.Substring(0, $keep) + [char]0x2026  # ellipsis
    }

    if ($sym) { return "$sym $name" }
    return $name
}

# ──────────────────────────────────────────────────────────────────────────────
# Upstream tracking symbol
# ──────────────────────────────────────────────────────────────────────────────

function Get-BranchStatusSymbol {
    param($Branch, $Settings)

    if (-not $Branch.Upstream) { return $null }
    if ($Branch.UpstreamGone)  { return $Settings.Symbols.Gone }

    if ($Branch.AheadBy -gt 0 -and $Branch.BehindBy -gt 0) {
        return "$($Settings.Symbols.Diverged) +$($Branch.AheadBy) -$($Branch.BehindBy)"
    }
    if ($Branch.AheadBy  -gt 0) { return "$($Settings.Symbols.Ahead)$($Branch.AheadBy)" }
    if ($Branch.BehindBy -gt 0) { return "$($Settings.Symbols.Behind)$($Branch.BehindBy)" }
    return $Settings.Symbols.UpToDate
}

function Get-BranchStatusColor {
    param($Branch, $Settings)

    if (-not $Branch.Upstream)  { return $Settings.BranchColor }
    if ($Branch.UpstreamGone)   { return $Settings.BranchGoneColor }
    if ($Branch.AheadBy -gt 0 -and $Branch.BehindBy -gt 0) { return $Settings.BranchDivergedColor }
    if ($Branch.AheadBy  -gt 0) { return $Settings.BranchAheadColor }
    if ($Branch.BehindBy -gt 0) { return $Settings.BranchBehindColor }
    return $Settings.BranchColor
}

# ──────────────────────────────────────────────────────────────────────────────
# File status segment (index + working)
# ──────────────────────────────────────────────────────────────────────────────

function Format-IndexStatus {
    param($Index, $Settings)

    $parts = [System.Collections.Generic.List[string]]::new()
    $s = $Settings.Symbols

    if ($Index.Added    -gt 0) { $parts.Add("$($s.Staged)$($Index.Added)") }
    if ($Index.Modified -gt 0) { $parts.Add("$($s.Staged)~$($Index.Modified)") }
    if ($Index.Deleted  -gt 0) { $parts.Add("$($s.Staged)-$($Index.Deleted)") }
    if ($Index.Renamed  -gt 0) { $parts.Add("$($s.Staged)R$($Index.Renamed)") }
    if ($Index.Copied   -gt 0) { $parts.Add("$($s.Staged)C$($Index.Copied)") }

    return $parts -join ' '
}

function Format-WorkingStatus {
    param($Working, $Settings)

    $parts = [System.Collections.Generic.List[string]]::new()
    $s = $Settings.Symbols

    if ($Working.Conflicted -gt 0) { $parts.Add("$($s.Conflict)$($Working.Conflicted)") }
    if ($Working.Modified   -gt 0) { $parts.Add("$($s.Unstaged)$($Working.Modified)") }
    if ($Working.Deleted    -gt 0) { $parts.Add("$($s.Unstaged)-$($Working.Deleted)") }
    if ($Working.Untracked  -gt 0) { $parts.Add("$($s.Untracked)$($Working.Untracked)") }

    return $parts -join ' '
}

# ──────────────────────────────────────────────────────────────────────────────
# Repo state (MERGE, REBASE n/m, etc.)
# ──────────────────────────────────────────────────────────────────────────────

function Format-RepoState {
    param($RepoState, $Settings)

    if (-not $RepoState.State) { return $null }

    $label = switch ($RepoState.State) {
        'MERGE'        { $Settings.Symbols.Merging }
        'CHERRY-PICK'  { $Settings.Symbols.CherryPicking }
        'REVERT'       { $Settings.Symbols.Reverting }
        'BISECT'       { $Settings.Symbols.Bisecting }
        'AM'           { 'AM' }
        'REBASE'       { $Settings.Symbols.Rebasing }
        'REBASE-i'     { $Settings.Symbols.Rebasing }
        default        { $RepoState.State }
    }

    if ($RepoState.RebaseTotal -gt 0) {
        return "$label $($RepoState.RebaseStep)/$($RepoState.RebaseTotal)"
    }
    return $label
}

# ──────────────────────────────────────────────────────────────────────────────
# Core prompt builder - ANSI mode
# ──────────────────────────────────────────────────────────────────────────────

function Build-AnsiPrompt {
    param($Status, $Settings)

    $sb  = [System.Text.StringBuilder]::new(128)
    $s   = $Settings.Symbols
    $rst = $Settings.ResetColor.Ansi

    # Opening delimiter
    Write-AnsiColor -Builder $sb -Color $Settings.DelimiterColor -Text $Settings.BeforeText

    # Branch name + upstream color
    $branchText  = Format-BranchName -Branch $Status.Branch -Settings $Settings
    $branchColor = Get-BranchStatusColor -Branch $Status.Branch -Settings $Settings
    Write-AnsiColor -Builder $sb -Color $branchColor -Text $branchText

    # Upstream tracking symbol
    $trackSymbol = Get-BranchStatusSymbol -Branch $Status.Branch -Settings $Settings
    if ($trackSymbol) {
        $null = $sb.Append(' ')
        Write-AnsiColor -Builder $sb -Color $branchColor -Text $trackSymbol
    }

    # Repo state (MERGE, REBASE n/m, etc.)
    $stateText = Format-RepoState -RepoState $Status.RepoState -Settings $Settings
    if ($stateText) {
        $null = $sb.Append(' ')
        Write-AnsiColor -Builder $sb -Color $Settings.StateColor -Text $stateText
    }

    # Index status
    $indexText = Format-IndexStatus -Index $Status.Index -Settings $Settings
    if ($indexText) {
        $null = $sb.Append(' ')
        Write-AnsiColor -Builder $sb -Color $Settings.StagedColor -Text $indexText
    }

    # Separator between index and working
    if ($indexText -and ($Status.Working.Modified   -gt 0 -or
                          $Status.Working.Deleted    -gt 0 -or
                          $Status.Working.Untracked  -gt 0 -or
                          $Status.Working.Conflicted -gt 0)) {
        Write-AnsiColor -Builder $sb -Color $Settings.DelimiterColor -Text ' |'
    }

    # Working dir status
    $workText = Format-WorkingStatus -Working $Status.Working -Settings $Settings
    if ($workText) {
        $null = $sb.Append(' ')
        $workColor = if ($Status.Working.Conflicted -gt 0) { $Settings.ConflictColor } else { $Settings.UnstagedColor }
        Write-AnsiColor -Builder $sb -Color $workColor -Text $workText
    }

    # Stash count
    if ($Settings.ShowStashCount -and $Status.StashCount -gt 0) {
        Write-AnsiColor -Builder $sb -Color $Settings.StashColor -Text " $($s.Stash)$($Status.StashCount)"
    }

    # Closing delimiter + reset
    Write-AnsiColor -Builder $sb -Color $Settings.DelimiterColor -Text $Settings.AfterText
    $null = $sb.Append($rst)

    return $sb.ToString()
}

# ──────────────────────────────────────────────────────────────────────────────
# Core prompt builder - Legacy (Write-Host) mode
# ──────────────────────────────────────────────────────────────────────────────

function Write-LegacyPrompt {
    param($Status, $Settings)

    $s = $Settings.Symbols

    Write-LegacyColor -Color $Settings.DelimiterColor -Text $Settings.BeforeText

    $branchText  = Format-BranchName -Branch $Status.Branch -Settings $Settings
    $branchColor = Get-BranchStatusColor -Branch $Status.Branch -Settings $Settings
    Write-LegacyColor -Color $branchColor -Text $branchText

    $trackSymbol = Get-BranchStatusSymbol -Branch $Status.Branch -Settings $Settings
    if ($trackSymbol) {
        Write-Host -NoNewline ' '
        Write-LegacyColor -Color $branchColor -Text $trackSymbol
    }

    $stateText = Format-RepoState -RepoState $Status.RepoState -Settings $Settings
    if ($stateText) {
        Write-Host -NoNewline ' '
        Write-LegacyColor -Color $Settings.StateColor -Text $stateText
    }

    $indexText = Format-IndexStatus -Index $Status.Index -Settings $Settings
    if ($indexText) {
        Write-Host -NoNewline ' '
        Write-LegacyColor -Color $Settings.StagedColor -Text $indexText
    }

    if ($indexText -and ($Status.Working.Modified   -gt 0 -or
                          $Status.Working.Deleted    -gt 0 -or
                          $Status.Working.Untracked  -gt 0 -or
                          $Status.Working.Conflicted -gt 0)) {
        Write-LegacyColor -Color $Settings.DelimiterColor -Text ' |'
    }

    $workText = Format-WorkingStatus -Working $Status.Working -Settings $Settings
    if ($workText) {
        Write-Host -NoNewline ' '
        $workColor = if ($Status.Working.Conflicted -gt 0) { $Settings.ConflictColor } else { $Settings.UnstagedColor }
        Write-LegacyColor -Color $workColor -Text $workText
    }

    if ($Settings.ShowStashCount -and $Status.StashCount -gt 0) {
        Write-LegacyColor -Color $Settings.StashColor -Text " $($s.Stash)$($Status.StashCount)"
    }

    Write-LegacyColor -Color $Settings.DelimiterColor -Text $Settings.AfterText
}

# ──────────────────────────────────────────────────────────────────────────────
# Public API
# ──────────────────────────────────────────────────────────────────────────────

# Returns a formatted string (ANSI mode) or writes directly (Legacy mode).
# Call this inside your prompt function.
function Write-GitPrompt {
    [CmdletBinding()]
    param(
        $Status,
        $Settings = $global:PowerGitSettings
    )

    if (-not $Settings) { return }
    if (-not $Status -or -not $Status.IsGitRepo) { return }

    # Compare as string - avoids cross-file enum type lookup issues on PS 5.1
    if ($Settings.WriterMode -ne 'Legacy') {
        return (Build-AnsiPrompt -Status $Status -Settings $Settings)
    } else {
        Write-LegacyPrompt -Status $Status -Settings $Settings
        return ''
    }
}

# Convenience: fetch status and render in one call
function Get-GitPromptString {
    [CmdletBinding()]
    param(
        $Settings = $global:PowerGitSettings
    )

    if (-not $Settings -or -not $Settings.EnablePrompt) { return '' }

    try {
        $status = Get-GitStatus
        if (-not $status) { return '' }
        return (Write-GitPrompt -Status $status -Settings $Settings)
    } catch {
        # Never crash the prompt
        return ''
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Window title integration
# ──────────────────────────────────────────────────────────────────────────────

function Set-WindowTitle {
    [CmdletBinding()]
    param(
        $Status,
        [string]$BasePath = (Get-Location).Path
    )
    if ($Status -and $Status.IsGitRepo) {
        $repoName = Split-Path $Status.WorkingDir -Leaf
        $branch   = $Status.Branch.Name
        $host.UI.RawUI.WindowTitle = "$BasePath [$repoName/$branch]"
    } else {
        $host.UI.RawUI.WindowTitle = $BasePath
    }
}
