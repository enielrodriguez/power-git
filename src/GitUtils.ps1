#requires -Version 5.1
# GitUtils.ps1 - Core git utility functions for power-git

# Invoke git and return stdout lines, suppressing stderr
function Invoke-Git {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    $result = & git @Arguments 2>$null
    if ($LASTEXITCODE -eq 0) { return $result }
    return $null
}

# Invoke git and return raw output (including non-zero exit, for porcelain queries)
function Invoke-GitRaw {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    $output = & git @Arguments 2>$null
    return $output
}

# Find the root of the git repo (or worktree) for the given path
function Get-GitDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Path = (Get-Location).Path
    )

    # Fast path: ask git directly
    $gitDir = & git -C $Path rev-parse --git-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $gitDir) { return $null }

    # Make absolute
    if (-not [System.IO.Path]::IsPathRooted($gitDir)) {
        $gitDir = Join-Path $Path $gitDir
    }
    return [System.IO.Path]::GetFullPath($gitDir)
}

# Return the work-tree root (i.e. the directory containing .git)
function Get-GitRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Path = (Get-Location).Path
    )
    $root = & git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $root
}

# Test whether the current directory is inside a git repo
function Test-GitRepository {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$Path = (Get-Location).Path
    )
    $null = & git -C $Path rev-parse --git-dir 2>$null
    return $LASTEXITCODE -eq 0
}

# Return all local branch names
function Get-GitLocalBranches {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $branches = Invoke-Git 'branch' '--format=%(refname:short)'
    return @($branches)
}

# Return all remote-tracking refs as "remote/branch"
function Get-GitRemoteBranches {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $refs = Invoke-Git 'branch' '--remote' '--format=%(refname:short)'
    # Filter out HEAD pointers like "origin/HEAD"
    return @($refs | Where-Object { $_ -notmatch '/HEAD$' })
}

# Return all tag names
function Get-GitTags {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    return @(Invoke-Git 'tag' '--sort=-version:refname')
}

# Return all configured remote names
function Get-GitRemotes {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    return @(Invoke-Git 'remote')
}

# Return stash list entries (ref:message)
function Get-GitStashes {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    return @(Invoke-Git 'stash' 'list' '--format=%gd: %s')
}

# Return the current HEAD commit hash (short)
function Get-GitHeadHash {
    [CmdletBinding()]
    [OutputType([string])]
    param([switch]$Long)
    if ($Long) {
        return Invoke-Git 'rev-parse' 'HEAD'
    }
    return Invoke-Git 'rev-parse' '--short' 'HEAD'
}

# Return the current branch name (or $null if detached)
function Get-GitBranchName {
    [CmdletBinding()]
    [OutputType([string])]
    param()
    $branch = Invoke-Git 'symbolic-ref' '--short' 'HEAD'
    return $branch
}

# Return all files in the index (for path completion in add/checkout/etc.)
function Get-GitIndexFiles {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [string]$Prefix = ''
    )
    $files = Invoke-Git 'ls-files' '--cached' '--others' '--exclude-standard'
    if ($Prefix) {
        return @($files | Where-Object { $_ -like "${Prefix}*" })
    }
    return @($files)
}

# Return files with merge conflicts
function Get-GitConflictFiles {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $files = Invoke-Git 'diff' '--name-only' '--diff-filter=U'
    return @($files)
}

# Detect git executable availability
function Test-GitAvailable {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $null = Get-Command git -ErrorAction SilentlyContinue
    return $?
}

# Return a hashtable of configured merge/diff/log aliases
function Get-GitAliases {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    $lines = Invoke-Git 'config' '--get-regexp' '^alias\.'
    $aliases = @{}
    foreach ($line in $lines) {
        if ($line -match '^alias\.(\S+)\s+(.+)$') {
            $aliases[$Matches[1]] = $Matches[2]
        }
    }
    return $aliases
}

# Return the name of the configured upstream branch for the given local branch
function Get-GitUpstreamBranch {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Branch = '@'
    )
    return Invoke-Git 'rev-parse' '--abbrev-ref' "${Branch}@{upstream}"
}

# Return submodule paths relative to repo root
function Get-GitSubmodules {
    [CmdletBinding()]
    [OutputType([string[]])]
    param()
    $paths = Invoke-Git 'submodule' '--quiet' 'foreach' '--recursive' 'echo $displaypath'
    return @($paths)
}

# Return recent commits for log-based completions
function Get-GitRecentCommits {
    [CmdletBinding()]
    [OutputType([string[]])]
    param([int]$Count = 20)
    return @(Invoke-Git 'log' "--max-count=$Count" '--format=%H %s')
}
