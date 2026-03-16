@{
    # Module identity
    ModuleVersion     = '1.0.0'
    GUID              = 'a7f3c2e1-4b8d-4f9a-b6d5-1c2e3f4a5b6c'
    Author            = 'power-git contributors'
    Description       = 'A fast, feature-rich Git prompt and tab completion module for PowerShell 5.1+'
    PowerShellVersion = '5.1'

    # Root module
    RootModule        = 'power-git.psm1'

    # Exported members (full list kept in .psm1 via Export-ModuleMember)
    FunctionsToExport = @(
        'Test-PowerGit'
        'Show-PowerGitHelp'
        'Get-GitStatus'
        'Clear-GitStatusCache'
        'Write-GitPrompt'
        'Get-GitPromptString'
        'New-PowerGitSettings'
        'Set-GitTheme'
        'Enable-GitPrompt'
        'Disable-GitPrompt'
        'Enable-GitFileStatus'
        'Disable-GitFileStatus'
        'Add-PowerGitToProfile'
        'Remove-PowerGitFromProfile'
        'Install-PowerGitFont'
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
        'Register-GitCompletion'
        'Unregister-GitCompletion'
    )

    VariablesToExport = @('PowerGitSettings')
    CmdletsToExport   = @()
    AliasesToExport   = @()

    # Private data / metadata
    PrivateData = @{
        PSData = @{
            Tags         = @('git', 'prompt', 'tab-completion', 'vcs', 'terminal')
            ProjectUri   = 'https://github.com/YOUR_USERNAME/power-git'
            LicenseUri   = 'https://github.com/YOUR_USERNAME/power-git/blob/main/LICENSE'
            ReleaseNotes = @'
## 1.0.0
- Initial release
- Single-call status via git porcelain v2 (faster than posh-git's multiple calls)
- Configurable status result caching (default: 500ms)
- Four built-in themes: Default, Minimal, ASCII, Powerline
- Rebase progress indicator (step N of M)
- Per-repo file status opt-out for large monorepos
- Comprehensive tab completion for 30+ git subcommands
- ANSI and Legacy (Write-Host) rendering modes
- Auto-detects ANSI support on Windows PowerShell 5.1
'@
        }
    }
}
