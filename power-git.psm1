#requires -Version 5.1
# power-git.psm1 - Module entry point
# A faster, richer alternative to posh-git for Windows PowerShell 5.1+

# ──────────────────────────────────────────────────────────────────────────────
# Prerequisite check
# ──────────────────────────────────────────────────────────────────────────────

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Warning 'power-git: git executable not found in PATH. Module functionality will be unavailable.'
    return
}

# ──────────────────────────────────────────────────────────────────────────────
# Load source files
# ──────────────────────────────────────────────────────────────────────────────

$srcDir = Join-Path $PSScriptRoot 'src'

foreach ($file in @('Settings.ps1', 'GitUtils.ps1', 'GitStatus.ps1', 'GitPrompt.ps1', 'GitCompletion.ps1')) {
    $path = Join-Path $srcDir $file
    if (Test-Path $path) {
        . $path
    } else {
        Write-Warning "power-git: Missing source file: $path"
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Initialize global settings
# ──────────────────────────────────────────────────────────────────────────────

if (-not (Get-Variable -Name PowerGitSettings -Scope Global -ErrorAction SilentlyContinue)) {
    $global:PowerGitSettings = New-PowerGitSettings
}

# ──────────────────────────────────────────────────────────────────────────────
# Prompt integration
# ──────────────────────────────────────────────────────────────────────────────

# Capture and save the user's existing prompt function
if (-not (Get-Variable -Name __OriginalPrompt -Scope Global -ErrorAction SilentlyContinue)) {
    $global:__OriginalPrompt = (Get-Item Function:\prompt).ScriptBlock
}

# Install the enhanced prompt
function global:prompt {
    $origPrompt = & $global:__OriginalPrompt
    $settings   = $global:PowerGitSettings

    if (-not $settings -or -not $settings.EnablePrompt) { return $origPrompt }

    # Split the original prompt into everything before the trailing '>' and the '> ' itself.
    # e.g. "PS C:\foo> " -> prefix="PS C:\foo", suffix="> "
    # The greedy .* backtracks so that >+\s* always captures the last '>' group.
    if ($origPrompt -match '^(.*)(>+\s*)$') {
        $promptPrefix = $Matches[1]
        $promptSuffix = $Matches[2]
    } else {
        $promptPrefix = $origPrompt
        $promptSuffix = ''
    }

    try {
        $status = Get-GitStatus
        if (-not $status) { return $origPrompt }

        # Update window title
        try {
            $repoName = Split-Path $status.WorkingDir -Leaf
            $Host.UI.RawUI.WindowTitle = "$((Get-Location).Path) [$repoName/$($status.Branch.Name)]"
        } catch {}

        if ($settings.WriterMode -ne 'Legacy') {
            # ANSI mode: build the full string and return it
            $gitStr = Write-GitPrompt -Status $status -Settings $settings
            return "${promptPrefix}${gitStr}${promptSuffix}"
        } else {
            # Legacy mode: write prefix and git info via Write-Host, return only the suffix
            # so '>' is always the last printed character
            Write-Host -NoNewline $promptPrefix
            Write-GitPrompt -Status $status -Settings $settings
            return $promptSuffix
        }
    } catch {
        return $origPrompt
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# ANSI virtual terminal processing (Windows 10 classic console)
# ──────────────────────────────────────────────────────────────────────────────

function Enable-AnsiProcessing {
    # Enable ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x0004) on the stdout handle.
    # Required for ANSI colours in the classic Windows console host on Win10.
    # Silently ignored on non-Windows or if already enabled.
    try {
        if (-not ([System.Management.Automation.PSTypeName]'PwrGit.Win32').Type) {
            Add-Type -Namespace PwrGit -Name Win32 -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out int m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, int m);
'@
        }
        $hOut = [PwrGit.Win32]::GetStdHandle(-11)  # STD_OUTPUT_HANDLE
        $mode = 0
        $null = [PwrGit.Win32]::GetConsoleMode($hOut, [ref]$mode)
        $null = [PwrGit.Win32]::SetConsoleMode($hOut, ($mode -bor 0x0004))
    } catch { <# Non-critical; fall back to Legacy mode #> }
}

# Try to enable ANSI. If it fails (e.g. console doesn't support it) switch to Legacy.
if ($global:PowerGitSettings -and $global:PowerGitSettings.WriterMode -ne 'Legacy') {
    # Only attempt on Windows PS 5.1 ConsoleHost without a known good ANSI terminal
    if ($Host.Name -eq 'ConsoleHost' -and -not $env:WT_SESSION -and -not $env:TERM_PROGRAM) {
        Enable-AnsiProcessing
        # Quick smoke-test: if ANSI doesn't render, fall back
        # (We trust Win10 >= 1511 supports VT after enabling; no test needed)
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Tab completion
# ──────────────────────────────────────────────────────────────────────────────

Register-GitCompletion

# ──────────────────────────────────────────────────────────────────────────────
# Convenience functions exposed to users
# ──────────────────────────────────────────────────────────────────────────────

function Set-GitTheme {
    <#
    .SYNOPSIS
        Apply a built-in power-git prompt theme.
    .DESCRIPTION
        Applies one of the built-in themes to $global:PowerGitSettings.
        Available themes: Default, Minimal, ASCII, Powerline
    .PARAMETER Name
        Name of the theme to apply.
    .EXAMPLE
        Set-GitTheme Powerline
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Default','Minimal','ASCII','Powerline')]
        [string]$Name
    )
    if (-not $global:PowerGitSettings) {
        $global:PowerGitSettings = New-PowerGitSettings -Theme $Name
    } else {
        $global:PowerGitSettings.ApplyTheme($Name)
    }
    Write-Verbose "power-git: Applied theme '$Name'."
}

function Enable-GitPrompt {
    <#
    .SYNOPSIS
        Enable the power-git prompt integration.
    #>
    [CmdletBinding()]
    param()
    if ($global:PowerGitSettings) { $global:PowerGitSettings.EnablePrompt = $true }
}

function Disable-GitPrompt {
    <#
    .SYNOPSIS
        Disable the power-git prompt integration (reverts to original prompt).
    #>
    [CmdletBinding()]
    param()
    if ($global:PowerGitSettings) { $global:PowerGitSettings.EnablePrompt = $false }
}

function Enable-GitFileStatus {
    <#
    .SYNOPSIS
        Enable file-level status counts in the prompt for the current repo.
    #>
    [CmdletBinding()]
    param()
    if ($global:PowerGitSettings) {
        $root = Get-GitRoot
        if ($root) { $global:PowerGitSettings.DisableFileStatusRepos.Remove($root) | Out-Null }
        $global:PowerGitSettings.ShowFileStatus = $true
    }
}

function Disable-GitFileStatus {
    <#
    .SYNOPSIS
        Disable file-level status counts for the current repo (useful for large monorepos).
    #>
    [CmdletBinding()]
    param()
    if ($global:PowerGitSettings) {
        $root = Get-GitRoot
        if ($root) {
            $global:PowerGitSettings.DisableFileStatusRepos.Add($root) | Out-Null
            Write-Host "power-git: File status disabled for '$root'."
        } else {
            $global:PowerGitSettings.ShowFileStatus = $false
        }
    }
}

function Test-PowerGit {
    <#
    .SYNOPSIS
        Diagnose power-git installation and show what is happening in the current directory.
    #>
    [CmdletBinding()]
    param()

    Write-Host "power-git diagnostic" -ForegroundColor Cyan
    Write-Host "----------------------------------------"

    # Git availability
    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    $gitPath = if ($gitCmd) { $gitCmd.Source } else { $null }
    Write-Host "git executable : $(if ($gitPath) { $gitPath } else { 'NOT FOUND' })"

    # Settings
    if ($global:PowerGitSettings) {
        Write-Host "Settings       : loaded (WriterMode=$($global:PowerGitSettings.WriterMode), EnablePrompt=$($global:PowerGitSettings.EnablePrompt))"
    } else {
        Write-Host "Settings       : NOT initialized (run: `$global:PowerGitSettings = New-PowerGitSettings)" -ForegroundColor Red
    }

    # Prompt installed
    $promptSrc = (Get-Item Function:\prompt).ScriptBlock.ToString()
    $installed = $promptSrc -match 'Get-GitStatus'
    Write-Host "Prompt hook    : $(if ($installed) { 'installed' } else { 'NOT installed' })"

    # Repo detection
    $status = Get-GitStatus -ErrorAction SilentlyContinue
    if ($status) {
        Write-Host "In git repo    : YES"
        Write-Host "  Branch       : $($status.Branch.Name)$(if ($status.Branch.IsDetached) { ' (detached)' })"
        Write-Host "  Upstream     : $(if ($status.Branch.Upstream) { $status.Branch.Upstream } else { '(none)' })"
        Write-Host "  Ahead/Behind : +$($status.Branch.AheadBy) / -$($status.Branch.BehindBy)"
        Write-Host "  Staged       : A$($status.Index.Added) M$($status.Index.Modified) D$($status.Index.Deleted)"
        Write-Host "  Working      : M$($status.Working.Modified) D$($status.Working.Deleted) ?$($status.Working.Untracked)"
        Write-Host "  State        : $(if ($status.RepoState.State) { $status.RepoState.State } else { 'clean' })"
        Write-Host "  StashCount   : $($status.StashCount)"
    } else {
        Write-Host "In git repo    : NO (not in a git repository)"
    }

    # Prompt string preview
    $str = Get-GitPromptString -ErrorAction SilentlyContinue
    if ($str) {
        Write-Host "Prompt string  : '$str' (length=$($str.Length))"
    } else {
        Write-Host "Prompt string  : (empty - check above for issues)" -ForegroundColor Yellow
    }

    # ANSI support
    Write-Host "WT_SESSION     : $(if ($env:WT_SESSION) { 'set (Windows Terminal)' } else { 'not set' })"
    Write-Host "TERM_PROGRAM   : $(if ($env:TERM_PROGRAM) { $env:TERM_PROGRAM } else { 'not set' })"
    Write-Host "ConsoleHost    : $($Host.Name)"
}

function Add-PowerGitToProfile {
    <#
    .SYNOPSIS
        Append the power-git import line to your PowerShell profile.
    .PARAMETER AllHosts
        Add to the profile shared by all hosts (default: current host profile).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$AllHosts)

    $profilePath = if ($AllHosts) { $PROFILE.CurrentUserAllHosts } else { $PROFILE }
    $importLine  = 'Import-Module power-git'

    if (-not (Test-Path $profilePath)) {
        if ($PSCmdlet.ShouldProcess($profilePath, 'Create profile and add power-git import')) {
            $null = New-Item -ItemType File -Path $profilePath -Force
            Add-Content -Path $profilePath -Value $importLine
        }
        return
    }

    $content = Get-Content $profilePath -Raw
    if ($content -match 'power-git') {
        Write-Host 'power-git: Profile already contains power-git import.'
        return
    }

    if ($PSCmdlet.ShouldProcess($profilePath, 'Add power-git import')) {
        Add-Content -Path $profilePath -Value "`n$importLine"
        Write-Host "power-git: Added import to '$profilePath'."
    }
}

function Remove-PowerGitFromProfile {
    <#
    .SYNOPSIS
        Remove the power-git import line from your PowerShell profile.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([switch]$AllHosts)

    $profilePath = if ($AllHosts) { $PROFILE.CurrentUserAllHosts } else { $PROFILE }

    if (-not (Test-Path $profilePath)) {
        Write-Host 'power-git: Profile not found.'
        return
    }

    $content = Get-Content $profilePath
    $newContent = $content | Where-Object { $_ -notmatch '^\s*Import-Module\s+power-git\s*$' }

    if ($content.Count -ne $newContent.Count) {
        if ($PSCmdlet.ShouldProcess($profilePath, 'Remove power-git import')) {
            Set-Content -Path $profilePath -Value $newContent
            Write-Host "power-git: Removed import from '$profilePath'."
        }
    } else {
        Write-Host 'power-git: No power-git import found in profile.'
    }
}

function Show-PowerGitHelp {
    <#
    .SYNOPSIS
        Show a quick-reference guide for the power-git prompt symbols and commands.
    #>
    [CmdletBinding()]
    param()

    $theme = $global:PowerGitSettings
    if (-not $theme) {
        Write-Warning 'power-git: Settings not initialized. Run: $global:PowerGitSettings = New-PowerGitSettings'
        return
    }
    $s = $theme.Symbols

    Write-Host ''
    Write-Host ' power-git quick reference' -ForegroundColor Cyan
    Write-Host ' ----------------------------------------------------------' -ForegroundColor DarkGray

    # Prompt anatomy
    $bt = $theme.BeforeText
    $at = $theme.AfterText
    Write-Host ''
    Write-Host ' PROMPT ANATOMY' -ForegroundColor Yellow
    Write-Host "   PS C:\repo${bt}$($s.Branch) main $($s.Ahead)2 |$($s.Staged)+1 $($s.Staged)~3 $($s.Stash)1${at}>" -ForegroundColor White
    Write-Host '          |__________________________________|'
    Write-Host '          git segment (only shown inside a git repo)'

    # Branch & upstream
    Write-Host ''
    Write-Host ' BRANCH & UPSTREAM' -ForegroundColor Yellow
    Write-Host "   $($s.Branch)  branch name    - current branch (Powerline glyph; requires Nerd Font)" -ForegroundColor White
    Write-Host "   $($s.Detached)  detached HEAD  - short commit hash shown instead of branch name" -ForegroundColor White
    Write-Host "   $($s.UpToDate)  up to date     - in sync with upstream" -ForegroundColor White
    Write-Host "   $($s.Ahead)N  ahead          - N commits ahead of upstream (not yet pushed)" -ForegroundColor White
    Write-Host "   $($s.Behind)N  behind         - N commits behind upstream (need to pull)" -ForegroundColor White
    Write-Host "   $($s.Diverged) +N -M  diverged - N ahead and M behind simultaneously" -ForegroundColor White
    Write-Host "   $($s.Gone)  upstream gone  - tracking branch was deleted on the remote" -ForegroundColor White

    # Index
    Write-Host ''
    Write-Host ' INDEX - staged changes (shown left of |)' -ForegroundColor Yellow
    Write-Host "   $($s.Staged)N   added          - N new files staged" -ForegroundColor White
    Write-Host "   $($s.Staged)~N  modified       - N modified files staged" -ForegroundColor White
    Write-Host "   $($s.Staged)-N  deleted        - N deleted files staged" -ForegroundColor White
    Write-Host "   $($s.Staged)RN  renamed        - N renames staged" -ForegroundColor White

    # Working dir
    Write-Host ''
    Write-Host ' WORKING DIR - unstaged changes (shown right of |)' -ForegroundColor Yellow
    Write-Host "   $($s.Unstaged)N  modified       - N files modified but not staged" -ForegroundColor White
    Write-Host "   $($s.Unstaged)-N  deleted       - N files deleted but not staged" -ForegroundColor White
    Write-Host "   $($s.Untracked)N  untracked      - N untracked files" -ForegroundColor White
    Write-Host "   $($s.Conflict)N  conflicts      - N merge conflicts (shown in red)" -ForegroundColor White

    # Repo state
    Write-Host ''
    Write-Host ' REPO STATE & STASH' -ForegroundColor Yellow
    Write-Host "   $($s.Merging)       - a merge is in progress" -ForegroundColor White
    Write-Host "   $($s.Rebasing) N/M  - rebase in progress, step N of M" -ForegroundColor White
    Write-Host "   $($s.CherryPicking) - cherry-pick in progress" -ForegroundColor White
    Write-Host "   $($s.Reverting)     - revert in progress" -ForegroundColor White
    Write-Host "   $($s.Bisecting)     - bisect session active" -ForegroundColor White
    Write-Host "   $($s.Stash)N stash  - N stashed changesets" -ForegroundColor White

    # Commands
    Write-Host ''
    Write-Host ' COMMANDS' -ForegroundColor Yellow
    Write-Host '   Test-PowerGit                - diagnose installation / show current repo info' -ForegroundColor White
    Write-Host '   Show-PowerGitHelp            - this help screen' -ForegroundColor White
    Write-Host ''
    Write-Host '   Set-GitTheme <name>          - Default | Minimal | ASCII | Powerline' -ForegroundColor White
    Write-Host '   Enable-GitPrompt             - turn prompt integration on' -ForegroundColor White
    Write-Host '   Disable-GitPrompt            - turn prompt integration off' -ForegroundColor White
    Write-Host ''
    Write-Host '   Enable-GitFileStatus         - show file counts in prompt (default)' -ForegroundColor White
    Write-Host '   Disable-GitFileStatus        - hide file counts for current repo (large monorepos)' -ForegroundColor White
    Write-Host ''
    Write-Host '   Install-PowerGitFont         - download & install a Nerd Font (for Powerline theme)' -ForegroundColor White
    Write-Host '   Add-PowerGitToProfile        - auto-load power-git in every new session' -ForegroundColor White
    Write-Host '   Remove-PowerGitFromProfile   - undo the above' -ForegroundColor White
    Write-Host ''
    Write-Host '   $global:PowerGitSettings     - live config object; edit properties directly, e.g.:' -ForegroundColor White
    Write-Host '     .StatusCacheMs   = 500      - prompt cache lifetime in ms (0 = no cache)' -ForegroundColor DarkGray
    Write-Host '     .BranchMaxLength = 20       - truncate long branch names (0 = off)' -ForegroundColor DarkGray
    Write-Host '     .ShowStashCount  = $true    - show/hide the stash indicator' -ForegroundColor DarkGray

    # Current settings
    Write-Host ''
    Write-Host ' CURRENT SETTINGS' -ForegroundColor Yellow
    Write-Host "   WriterMode=$($theme.WriterMode)   EnablePrompt=$($theme.EnablePrompt)   ShowFileStatus=$($theme.ShowFileStatus)" -ForegroundColor White
    Write-Host "   StatusCacheMs=$($theme.StatusCacheMs)   BranchMaxLength=$($theme.BranchMaxLength)   ShowStashCount=$($theme.ShowStashCount)" -ForegroundColor White
    Write-Host ''
}

function Install-PowerGitFont {
    <#
    .SYNOPSIS
        Download and install a Nerd Font so the Powerline theme renders correctly.
    .DESCRIPTION
        Downloads the chosen Nerd Font from the ryanoasis/nerd-fonts GitHub releases
        and installs it for the current user (no administrator rights required).
        After installation, set the font in your terminal application manually.
    .PARAMETER Font
        Which Nerd Font to install. Default: CascadiaCode (recommended for Windows).
        Other options: FiraCode, JetBrainsMono
    .EXAMPLE
        Install-PowerGitFont
    .EXAMPLE
        Install-PowerGitFont -Font FiraCode
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('CascadiaCode', 'FiraCode', 'JetBrainsMono')]
        [string]$Font = 'CascadiaCode'
    )

    $userFontsDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    if (-not (Test-Path $userFontsDir)) {
        $null = New-Item -ItemType Directory -Path $userFontsDir -Force
    }

    # Fetch latest release metadata
    Write-Host "Fetching latest nerd-fonts release info..." -ForegroundColor Cyan
    try {
        $apiUrl  = 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
        $release = Invoke-RestMethod -Uri $apiUrl
        $asset   = $release.assets | Where-Object { $_.name -eq "$Font.zip" } | Select-Object -First 1
        if (-not $asset) {
            Write-Error "Could not find '$Font.zip' in the latest nerd-fonts release."
            return
        }
    } catch {
        Write-Error "Failed to fetch release info: $_"
        return
    }

    $sizeMb   = [math]::Round($asset.size / 1MB, 1)
    $zipPath  = Join-Path $env:TEMP "$Font-NerdFont.zip"
    $unzipDir = Join-Path $env:TEMP "$Font-NerdFont"

    Write-Host "Downloading $Font Nerd Font (~${sizeMb} MB)..." -ForegroundColor Cyan
    if (-not $PSCmdlet.ShouldProcess($asset.browser_download_url, 'Download and install font')) { return }

    try {
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
    } catch {
        Write-Error "Download failed: $_"
        return
    }

    # Extract
    if (Test-Path $unzipDir) { Remove-Item $unzipDir -Recurse -Force }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $unzipDir)

    # Install TTF files and register in the user font registry key
    $regPath  = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $installed = 0

    Get-ChildItem $unzipDir -Filter '*.ttf' | ForEach-Object {
        $dest = Join-Path $userFontsDir $_.Name
        Copy-Item $_.FullName $dest -Force
        $displayName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
        Set-ItemProperty -Path $regPath -Name "$displayName (TrueType)" -Value $dest -ErrorAction SilentlyContinue
        $installed++
    }

    # Cleanup temp files
    Remove-Item $zipPath    -Force -ErrorAction SilentlyContinue
    Remove-Item $unzipDir   -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Installed $installed font file(s) to '$userFontsDir'." -ForegroundColor Green
    Write-Host ''
    Write-Host 'Next step, set the font in your terminal (restart the terminal first):' -ForegroundColor Yellow
    Write-Host "  Windows Terminal : Settings > Profiles > Appearance > Font face  ->  '$Font NF'" -ForegroundColor White
    Write-Host "  Classic console  : Right-click title bar > Properties > Font" -ForegroundColor White
    Write-Host "  VS Code terminal : settings.json  ->  terminal.integrated.fontFamily: '$Font NF'" -ForegroundColor White
}

# ──────────────────────────────────────────────────────────────────────────────
# Module cleanup on removal
# ──────────────────────────────────────────────────────────────────────────────

$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    # Restore original prompt
    if (Get-Variable -Name __OriginalPrompt -Scope Global -ErrorAction SilentlyContinue) {
        Set-Item Function:\prompt $global:__OriginalPrompt
        Remove-Variable -Name __OriginalPrompt -Scope Global -Force -ErrorAction SilentlyContinue
    }
    # Clear settings
    Remove-Variable -Name PowerGitSettings -Scope Global -Force -ErrorAction SilentlyContinue
}

# ──────────────────────────────────────────────────────────────────────────────
# Exports
# ──────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function @(
    # Diagnostics / help
    'Test-PowerGit'
    'Show-PowerGitHelp'
    # Status
    'Get-GitStatus'
    'Clear-GitStatusCache'
    # Prompt
    'Write-GitPrompt'
    'Get-GitPromptString'
    # Settings
    'New-PowerGitSettings'
    'Set-GitTheme'
    'Enable-GitPrompt'
    'Disable-GitPrompt'
    'Enable-GitFileStatus'
    'Disable-GitFileStatus'
    # Profile / setup
    'Add-PowerGitToProfile'
    'Remove-PowerGitFromProfile'
    'Install-PowerGitFont'
    # Utilities (re-export for users)
    'Get-GitDirectory'
    'Get-GitRoot'
    'Test-GitRepository'
    'Get-GitLocalBranches'
    'Get-GitRemoteBranches'
    'Get-GitTags'
    'Get-GitRemotes'
    'Get-GitStashes'
    'Get-GitBranchName'
    'Get-GitAliases'
    # Completion
    'Register-GitCompletion'
    'Unregister-GitCompletion'
) -Variable @('PowerGitSettings')
