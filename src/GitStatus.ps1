#requires -Version 5.1
# GitStatus.ps1 - Fast git status detection with caching for power-git
#
# Key improvement over posh-git: uses `git status --porcelain=v2 --branch`
# in a SINGLE call to get all information, vs posh-git's multiple git invocations.

# Status result object
class GitBranchStatus {
    [string]$Name           # Branch name (or commit hash if detached)
    [bool]$IsDetached       # HEAD is detached
    [string]$Upstream       # Upstream tracking branch (or $null)
    [bool]$UpstreamGone     # Upstream branch has been deleted
    [int]$AheadBy           # Commits ahead of upstream
    [int]$BehindBy          # Commits behind upstream

    [string] ToString() {
        $uStr = ''
        if ($this.Upstream) { $uStr = " -> $($this.Upstream) +$($this.AheadBy)/-$($this.BehindBy)" }
        $dStr = ''
        if ($this.IsDetached) { $dStr = ' (detached)' }
        return "$($this.Name)$dStr$uStr"
    }
}

class GitIndexStatus {
    [int]$Added
    [int]$Modified
    [int]$Deleted
    [int]$Renamed
    [int]$Copied

    [string] ToString() {
        return "Added=$($this.Added) Modified=$($this.Modified) Deleted=$($this.Deleted) Renamed=$($this.Renamed) Copied=$($this.Copied)"
    }
}

class GitWorkingStatus {
    [int]$Modified
    [int]$Deleted
    [int]$Untracked
    [int]$Conflicted

    [string] ToString() {
        return "Modified=$($this.Modified) Deleted=$($this.Deleted) Untracked=$($this.Untracked) Conflicted=$($this.Conflicted)"
    }
}

class GitRepoState {
    [string]$State          # '', 'MERGE', 'REBASE', 'REBASE-i', 'REBASE-m', 'CHERRY-PICK', 'REVERT', 'BISECT'
    [int]$RebaseStep        # Current rebase step (0 if not rebasing)
    [int]$RebaseTotal       # Total rebase steps (0 if not rebasing)

    [string] ToString() {
        if (-not $this.State) { return 'clean' }
        if ($this.RebaseTotal -gt 0) { return "$($this.State) $($this.RebaseStep)/$($this.RebaseTotal)" }
        return $this.State
    }
}

class GitStatus {
    [bool]$IsGitRepo        = $false
    [string]$GitDir         # Path to .git directory
    [string]$WorkingDir     # Path to working tree root
    [GitBranchStatus]$Branch
    [GitIndexStatus]$Index
    [GitWorkingStatus]$Working
    [GitRepoState]$RepoState
    [int]$StashCount
    [bool]$HasUntracked

    # True if the repo has any changes worth showing
    [bool] HasChanges() {
        return ($this.Index.Added    -gt 0 -or
                $this.Index.Modified -gt 0 -or
                $this.Index.Deleted  -gt 0 -or
                $this.Index.Renamed  -gt 0 -or
                $this.Index.Copied   -gt 0 -or
                $this.Working.Modified   -gt 0 -or
                $this.Working.Deleted    -gt 0 -or
                $this.Working.Untracked  -gt 0 -or
                $this.Working.Conflicted -gt 0)
    }
}

# Cache entry
class StatusCacheEntry {
    [string]$Key            # Resolved git dir path
    [GitStatus]$Status
    [datetime]$FetchedAt
    [int]$TtlMs
    [bool] IsExpired() { return ((Get-Date) - $this.FetchedAt).TotalMilliseconds -gt $this.TtlMs }
}

# Module-level cache (plain hashtable avoids generic type parameter issues in PS 5.1)
$script:StatusCache = @{}

# Parse `git status --porcelain=v2 --branch` output into a GitStatus object
function ConvertFrom-GitPorcelainV2 {
    [CmdletBinding()]
    [OutputType([GitStatus])]
    param(
        [string[]]$Lines,
        [string]$GitDir,
        [string]$WorkingDir
    )

    $status = [GitStatus]::new()
    $status.IsGitRepo   = $true
    $status.GitDir      = $GitDir
    $status.WorkingDir  = $WorkingDir
    $status.Branch      = [GitBranchStatus]::new()
    $status.Index       = [GitIndexStatus]::new()
    $status.Working     = [GitWorkingStatus]::new()
    $status.RepoState   = [GitRepoState]::new()

    foreach ($line in $Lines) {
        # Branch header lines begin with '#'
        if ($line -match '^# branch\.head (.+)$') {
            $head = $Matches[1]
            if ($head -eq '(detached)') {
                $status.Branch.IsDetached = $true
                # Get short hash for detached HEAD display
                $hash = & git rev-parse --short HEAD 2>$null
                $status.Branch.Name = if ($hash) { $hash } else { 'HEAD' }
            } else {
                $status.Branch.Name = $head
            }
            continue
        }

        if ($line -match '^# branch\.upstream (.+)$') {
            $status.Branch.Upstream = $Matches[1]
            continue
        }

        if ($line -match '^# branch\.ab \+(\d+) -(\d+)$') {
            $status.Branch.AheadBy  = [int]$Matches[1]
            $status.Branch.BehindBy = [int]$Matches[2]
            continue
        }

        if ($line -eq '# branch.upstream (gone)' -or
            ($line -match '^# branch\.upstream' -and $status.Branch.Upstream -eq $null)) {
            # handled above
            continue
        }

        # Detect gone upstream via ab line missing (upstream set, ab not present = gone)
        # This is handled after parsing by checking if Upstream is set but AheadBy/BehindBy = 0
        # and git returns "gone" in the upstream line - porcelain v2 uses special header for this

        # Changed tracked entry (ordinary)
        if ($line -match '^1 (\S\S) ') {
            $xy = $Matches[1]
            $x  = $xy[0]  # Index status
            $y  = $xy[1]  # Working status
            $null = Add-XYStatus -Status $status -X $x -Y $y
            continue
        }

        # Renamed/copied entry
        if ($line -match '^2 (\S\S) ') {
            $xy = $Matches[1]
            $x  = $xy[0]
            $y  = $xy[1]
            # Index side
            if ($x -eq 'R') { $status.Index.Renamed++ }
            elseif ($x -eq 'C') { $status.Index.Copied++ }
            # Working side
            if ($y -ne '.') { $status.Working.Modified++ }
            continue
        }

        # Unmerged (conflict)
        if ($line -match '^u ') {
            $status.Working.Conflicted++
            continue
        }

        # Untracked
        if ($line -match '^\? ') {
            $status.Working.Untracked++
            $status.HasUntracked = $true
            continue
        }
    }

    # Detect gone upstream: when upstream is set but no "# branch.ab" line was present,
    # the remote branch was deleted. git porcelain v2 simply omits the ab line.
    if ($status.Branch.Upstream -and
        $status.Branch.AheadBy -eq 0 -and
        $status.Branch.BehindBy -eq 0 -and
        -not ($Lines -match '^# branch\.ab')) {
        # Only mark gone if there truly was no ab line (not just both zero)
        # git omits the ab line entirely when upstream is gone
        $hasAbLine = $false
        foreach ($l in $Lines) { if ($l -match '^# branch\.ab') { $hasAbLine = $true; break } }
        if (-not $hasAbLine) { $status.Branch.UpstreamGone = $true }
    }

    return $status
}

# Helper: accumulate X/Y status codes into index/working counts
function Add-XYStatus {
    param($Status, [char]$X, [char]$Y)

    # Index (X column)
    switch ($X) {
        'A' { $Status.Index.Added++    }
        'M' { $Status.Index.Modified++ }
        'D' { $Status.Index.Deleted++  }
        'R' { $Status.Index.Renamed++  }
        'C' { $Status.Index.Copied++   }
    }

    # Working (Y column)
    switch ($Y) {
        'M' { $Status.Working.Modified++ }
        'D' { $Status.Working.Deleted++  }
        '?' { $Status.Working.Untracked++ }
        'U' { $Status.Working.Conflicted++ }
    }
}

# Detect special repo states (MERGE, REBASE, etc.) by inspecting the .git directory
function Get-RepoState {
    [CmdletBinding()]
    [OutputType([GitRepoState])]
    param([string]$GitDir)

    $state = [GitRepoState]::new()
    $state.State = ''

    # Check for rebase-merge (interactive rebase)
    $rebaseMerge = Join-Path $GitDir 'rebase-merge'
    if (Test-Path $rebaseMerge) {
        $stepFile  = Join-Path $rebaseMerge 'msgnum'
        $totalFile = Join-Path $rebaseMerge 'end'
        if (Test-Path $stepFile)  { $state.RebaseStep  = [int](Get-Content $stepFile -Raw).Trim() }
        if (Test-Path $totalFile) { $state.RebaseTotal = [int](Get-Content $totalFile -Raw).Trim() }
        $state.State = 'REBASE-i'
        return $state
    }

    # Check for rebase-apply (am/rebase --apply)
    $rebaseApply = Join-Path $GitDir 'rebase-apply'
    if (Test-Path $rebaseApply) {
        $stepFile  = Join-Path $rebaseApply 'next'
        $totalFile = Join-Path $rebaseApply 'last'
        if (Test-Path $stepFile)  { $state.RebaseStep  = [int](Get-Content $stepFile -Raw).Trim() }
        if (Test-Path $totalFile) { $state.RebaseTotal = [int](Get-Content $totalFile -Raw).Trim() }
        if (Test-Path (Join-Path $rebaseApply 'rebasing')) { $state.State = 'REBASE' }
        else { $state.State = 'AM' }
        return $state
    }

    if (Test-Path (Join-Path $GitDir 'MERGE_HEAD'))        { $state.State = 'MERGE';          return $state }
    if (Test-Path (Join-Path $GitDir 'CHERRY_PICK_HEAD'))  { $state.State = 'CHERRY-PICK';     return $state }
    if (Test-Path (Join-Path $GitDir 'REVERT_HEAD'))       { $state.State = 'REVERT';          return $state }
    if (Test-Path (Join-Path $GitDir 'BISECT_LOG'))        { $state.State = 'BISECT';          return $state }

    return $state
}

# Main function: get current git status with optional caching
function Get-GitStatus {
    [CmdletBinding()]
    [OutputType([GitStatus])]
    param(
        [string]$Path     = (Get-Location).Path,
        [switch]$NoCache,
        [switch]$NoFileStatus
    )

    $settings = $global:PowerGitSettings

    # Find the git directory
    $gitDir = & git -C $Path rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $gitDir) {
        return $null  # Not in a repo
    }

    # Resolve to absolute path
    if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
        $gitDir = [System.IO.Path]::GetFullPath((Join-Path $Path $gitDir))
    }

    $workDir = & git -C $Path rev-parse --show-toplevel 2>$null

    # Check per-repo file status disable setting
    $showFiles = -not $NoFileStatus
    if ($showFiles -and $settings -and $settings.DisableFileStatusRepos.Contains($workDir)) {
        $showFiles = $false
    }
    if ($showFiles -and $settings -and -not $settings.ShowFileStatus) {
        $showFiles = $false
    }

    # Cache key = gitdir + fileStatus mode
    $cacheKey = "${gitDir}|${showFiles}"

    # Check cache
    if (-not $NoCache -and
        $settings -and
        $settings.StatusCacheMs -gt 0 -and
        $script:StatusCache.ContainsKey($cacheKey)) {
        $entry = $script:StatusCache[$cacheKey]
        if (-not $entry.IsExpired()) {
            return $entry.Status
        }
    }

    # Build git command
    $gitArgs = @('status', '--porcelain=v2', '--branch')
    if (-not $showFiles) {
        # Only get branch info, skip file status enumeration
        $gitArgs += '--untracked-files=no'
    }

    $lines = & git -C $Path @gitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }

    $status = ConvertFrom-GitPorcelainV2 -Lines $lines -GitDir $gitDir -WorkingDir $workDir

    # Get repo special state (merge, rebase, etc.)
    $status.RepoState = Get-RepoState -GitDir $gitDir

    # Get stash count (fast: count lines in refs/stash)
    if ($settings -and $settings.ShowStashCount) {
        $stashRef = Join-Path $gitDir 'refs/stash'
        if (Test-Path $stashRef) {
            $stashLines = & git -C $Path stash list --format='%H' 2>$null
            $status.StashCount = @($stashLines).Count
        }
    }

    # Store in cache
    if ($settings -and $settings.StatusCacheMs -gt 0) {
        $entry = [StatusCacheEntry]::new()
        $entry.Key       = $cacheKey
        $entry.Status    = $status
        $entry.FetchedAt = Get-Date
        $entry.TtlMs     = $settings.StatusCacheMs
        $script:StatusCache[$cacheKey] = $entry
    }

    return $status
}

# Invalidate the status cache (call after git operations)
function Clear-GitStatusCache {
    [CmdletBinding()]
    param()
    $script:StatusCache.Clear()
}

# Exports are controlled from power-git.psm1
