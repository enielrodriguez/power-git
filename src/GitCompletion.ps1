#requires -Version 5.1
# GitCompletion.ps1 - Comprehensive tab completion for power-git
#
# Improvements over posh-git:
#  - Uses Register-ArgumentCompleter (PS 5.0+) properly
#  - Handles git aliases transparently
#  - Completes --flag=value patterns
#  - Smarter context detection (e.g. only suggest untracked files for 'git add')
#  - Handles git worktrees
#  - Subcommand delegation pattern for cleaner code

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

function New-CompletionResult {
    param(
        [string]$CompletionText,
        [string]$ListItemText   = $CompletionText,
        [string]$ToolTip        = $CompletionText,
        [System.Management.Automation.CompletionResultType]$Type =
            [System.Management.Automation.CompletionResultType]::ParameterValue
    )
    [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, $Type, $ToolTip)
}

function Get-CompletionPrefix {
    param([string]$Word)
    # Return the word as-is; used for filtering lists
    return $Word
}

function Complete-List {
    param(
        [string]$Prefix,
        [string[]]$Items,
        [System.Management.Automation.CompletionResultType]$Type =
            [System.Management.Automation.CompletionResultType]::ParameterValue
    )
    foreach ($item in $Items) {
        if ($item.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            New-CompletionResult -CompletionText $item -Type $Type
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Git ref completions (branches, tags, HEAD~n, etc.)
# ──────────────────────────────────────────────────────────────────────────────

function Complete-GitRef {
    param([string]$Prefix, [switch]$LocalOnly, [switch]$TagsOnly, [switch]$IncludeTags)

    if (-not $TagsOnly) {
        $local = Get-GitLocalBranches
        Complete-List -Prefix $Prefix -Items $local

        if (-not $LocalOnly) {
            $remote = Get-GitRemoteBranches
            Complete-List -Prefix $Prefix -Items $remote
        }
    }

    if ($TagsOnly -or $IncludeTags) {
        $tags = Get-GitTags
        Complete-List -Prefix $Prefix -Items $tags
    }

    # Special refs
    Complete-List -Prefix $Prefix -Items @('HEAD', 'ORIG_HEAD', 'FETCH_HEAD', 'MERGE_HEAD')
}

function Complete-GitRemote {
    param([string]$Prefix)
    $remotes = Get-GitRemotes
    Complete-List -Prefix $Prefix -Items $remotes
}

function Complete-GitStash {
    param([string]$Prefix)
    $stashes = Invoke-Git 'stash' 'list' '--format=%gd'
    Complete-List -Prefix $Prefix -Items @($stashes)
}

function Complete-GitFile {
    param([string]$Prefix, [switch]$Modified, [switch]$Staged, [switch]$Untracked)

    if ($Modified) {
        $files = Invoke-Git 'diff' '--name-only'
        Complete-List -Prefix $Prefix -Items @($files)
        return
    }
    if ($Staged) {
        $files = Invoke-Git 'diff' '--staged' '--name-only'
        Complete-List -Prefix $Prefix -Items @($files)
        return
    }
    if ($Untracked) {
        $files = Invoke-Git 'ls-files' '--others' '--exclude-standard'
        Complete-List -Prefix $Prefix -Items @($files)
        return
    }
    # Default: tracked + untracked
    $files = Invoke-Git 'ls-files' '--cached' '--others' '--exclude-standard'
    Complete-List -Prefix $Prefix -Items @($files)
}

function Complete-GitWorktree {
    param([string]$Prefix)
    $lines = Invoke-Git 'worktree' 'list' '--porcelain'
    $paths = $lines | Where-Object { $_ -match '^worktree ' } | ForEach-Object { ($_ -split ' ',2)[1] }
    Complete-List -Prefix $Prefix -Items @($paths)
}

# ──────────────────────────────────────────────────────────────────────────────
# Top-level git subcommands
# ──────────────────────────────────────────────────────────────────────────────

$script:GitCommands = @(
    # Porcelain commands
    'add', 'am', 'archive', 'bisect', 'branch', 'bundle', 'checkout',
    'cherry-pick', 'citool', 'clean', 'clone', 'commit', 'describe',
    'diff', 'fetch', 'format-patch', 'gc', 'grep', 'gui', 'init',
    'log', 'merge', 'mv', 'notes', 'pull', 'push', 'range-diff',
    'rebase', 'reset', 'restore', 'revert', 'rm', 'shortlog', 'show',
    'sparse-checkout', 'stash', 'status', 'submodule', 'switch', 'tag',
    'worktree',
    # Plumbing (commonly typed)
    'apply', 'cat-file', 'check-ref-format', 'checkout-index', 'commit-graph',
    'commit-tree', 'diff-index', 'diff-tree', 'for-each-ref', 'hash-object',
    'ls-files', 'ls-remote', 'ls-tree', 'merge-base', 'merge-tree',
    'pack-objects', 'read-tree', 'rev-list', 'rev-parse', 'show-ref',
    'symbolic-ref', 'unpack-objects', 'update-index', 'update-ref', 'write-tree',
    # Extra
    'bisect', 'blame', 'cherry', 'config', 'help', 'reflog', 'remote',
    'rerere', 'send-email', 'svn', 'whatchanged'
)

# ──────────────────────────────────────────────────────────────────────────────
# Per-subcommand completion delegates
# ──────────────────────────────────────────────────────────────────────────────

$script:SubcommandCompleters = @{}

# git add
$script:SubcommandCompleters['add'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-A','--all','-u','--update','-n','--dry-run','-p','--patch',
               '-e','--edit','-f','--force','-i','--interactive',
               '--chmod=+x','--chmod=-x','--intent-to-add','-N')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitFile -Prefix $Prefix -Untracked
    }
}

# git branch
$script:SubcommandCompleters['branch'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-a','--all','-r','--remotes','-v','--verbose','--merged',
               '--no-merged','-d','--delete','-D','--force-delete',
               '-m','--move','-c','--copy','-l','--list',
               '--set-upstream-to','--unset-upstream','--track','--no-track',
               '--contains','--no-contains','--points-at','--format')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -LocalOnly
    }
}

# git checkout / git switch
$script:SubcommandCompleters['checkout'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-b','-B','-t','--track','--no-track','-l','-d','--detach',
               '-f','--force','-m','--merge','-p','--patch','--ours','--theirs',
               '--orphan','--conflict','--ignore-skip-worktree-bits','--recurse-submodules')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}
$script:SubcommandCompleters['switch'] = $script:SubcommandCompleters['checkout']

# git restore
$script:SubcommandCompleters['restore'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-s','--source','-p','--patch','-W','--worktree',
               '-S','--staged','--ours','--theirs','--merge','--conflict',
               '--ignore-unmerged','--ignore-skip-worktree-bits','--recurse-submodules',
               '--overlay','--no-overlay','--pathspec-from-file','--pathspec-file-nul')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitFile -Prefix $Prefix -Modified
    }
}

# git commit
$script:SubcommandCompleters['commit'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-a','--all','-p','--patch','-C','--reuse-message',
               '-c','--reedit-message','-F','--file','-m','--message',
               '-t','--template','--signoff','-s','--squash','--fixup',
               '--reset-author','--allow-empty','--allow-empty-message',
               '--no-edit','--amend','--no-post-rewrite','-n','--no-verify',
               '-v','--verbose','-q','--quiet','--dry-run','--status','--no-status',
               '--gpg-sign','-S','--no-gpg-sign','--trailer','--cleanup')
    Complete-List -Prefix $Prefix -Items $flags
}

# git diff
$script:SubcommandCompleters['diff'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--cached','--staged','--stat','--name-only','--name-status',
               '--check','--diff-filter','--no-color','--color',
               '-U','--unified','-w','--ignore-all-space','-b','--ignore-space-change',
               '-p','--patch','--raw','--numstat','--shortstat','--summary',
               '--word-diff','--word-diff-regex','--histogram','--patience',
               '--diff-algorithm','--output','--relative','--no-relative',
               '--exit-code','--quiet','--ext-diff','--no-ext-diff',
               '--ignore-cr-at-eol','--ignore-space-at-eol')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git fetch
$script:SubcommandCompleters['fetch'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--all','--append','--depth','--deepen','--shallow-since',
               '--shallow-exclude','--unshallow','--update-shallow',
               '--dry-run','--force','-f','--keep','-k','--multiple',
               '--prune','-p','--prune-tags','--no-tags','-t','--tags',
               '--recurse-submodules','--jobs','-j','--set-upstream',
               '--no-recurse-submodules','--submodule-prefix','--update-head-ok',
               '--upload-pack','--quiet','-q','--verbose','-v','--progress',
               '--server-option','--show-forced-updates','--no-show-forced-updates',
               '--negotiate-only','--filter','--auto-maintenance','--no-auto-maintenance',
               '--auto-gc','--no-auto-gc','--write-fetch-head','--no-write-fetch-head',
               '--stdin')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } elseif ($PrevWords.Count -eq 0) {
        Complete-GitRemote -Prefix $Prefix
    } else {
        Complete-GitRef -Prefix $Prefix
    }
}

# git log
$script:SubcommandCompleters['log'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--follow','-p','--patch','--stat','--shortstat','--name-only',
               '--name-status','--abbrev-commit','--no-abbrev-commit','--oneline',
               '--format','--pretty','--date','--parents','--children',
               '--left-right','--cherry-pick','--cherry-mark','--cherry',
               '--walk-reflogs','-g','--merge','--boundary','--simplify-by-decoration',
               '--full-history','--dense','--sparse','--simplify-merges',
               '--ancestry-path','--all','--branches','--tags','--remotes',
               '--glob','--exclude','--ignore-missing','--bisect',
               '--stdin','--first-parent','--not','--no-walk','--do-walk',
               '--author','--committer','--grep','--grep-reflog',
               '--all-match','--invert-grep','-i','--regexp-ignore-case',
               '-E','--extended-regexp','-F','--fixed-strings','-P','--perl-regexp',
               '--max-count','-n','--skip','--since','--until','--after','--before',
               '--graph','--decorate','--no-decorate','--decorate-refs',
               '--decorate-refs-exclude','--source','--full-diff','--log-size',
               '--use-mailmap','--no-mailmap','--no-notes','--show-notes',
               '--standard-notes','--no-standard-notes','--show-signature',
               '--relative-date','--date=','--color','--no-color','--color-words',
               '--no-patch','-s','--reverse','--topo-order','--date-order',
               '--author-date-order')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git merge
$script:SubcommandCompleters['merge'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--commit','--no-commit','--ff','--no-ff','--ff-only',
               '-n','--stat','--no-stat','--squash','--no-squash',
               '-s','--strategy','--strategy-option','-X',
               '--verify-signatures','--no-verify-signatures',
               '-q','--quiet','-v','--verbose','--progress','--no-progress',
               '-S','--gpg-sign','--no-gpg-sign','--overwrite-ignore',
               '--signoff','--no-signoff','--log','--no-log',
               '-m','--message','--file','-F','--into-name',
               '--allow-unrelated-histories','--abort','--continue','--quit',
               '--autostash','--no-autostash')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix
    }
}

# git pull
$script:SubcommandCompleters['pull'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--rebase','--no-rebase','--ff','--no-ff','--ff-only',
               '-q','--quiet','-v','--verbose','--progress','--no-progress',
               '-n','--no-stat','--stat','--squash','--no-squash',
               '--force','-f','--autostash','--no-autostash',
               '--all','--append','-a','--depth','--deepen','--update-shallow',
               '--allow-unrelated-histories','--log','--no-log',
               '-s','--strategy','-X','--strategy-option','--verify-signatures',
               '--gpg-sign','-S','--no-gpg-sign','--recurse-submodules',
               '--no-recurse-submodules','--jobs','-j','--set-upstream',
               '--upload-pack','--prune','--dry-run','--tags','--no-tags')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } elseif ($PrevWords.Count -eq 0) {
        Complete-GitRemote -Prefix $Prefix
    } else {
        Complete-GitRef -Prefix $Prefix
    }
}

# git push
$script:SubcommandCompleters['push'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--all','--mirror','--tags','--follow-tags','--atomic',
               '--no-atomic','--force','-f','--force-with-lease',
               '--force-if-includes','--dry-run','-n','--porcelain',
               '--delete','-d','--prune','-u','--set-upstream',
               '--push-option','-o','--receive-pack','--exec','--no-verify',
               '--progress','--no-progress','--verbose','-v','--quiet','-q',
               '--recurse-submodules','--verify','--ipv4','-4','--ipv6','-6',
               '--signed','--no-signed','--gpg-sign','-S','--no-gpg-sign',
               '--thin','--no-thin','--repo')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } elseif ($PrevWords.Count -eq 0) {
        Complete-GitRemote -Prefix $Prefix
    } else {
        Complete-GitRef -Prefix $Prefix -LocalOnly
    }
}

# git rebase
$script:SubcommandCompleters['rebase'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--onto','--keep-base','--no-verify','--quiet','-q',
               '--verbose','-v','--stat','--no-stat','-n','--no-ff','-f',
               '--force-rebase','--fork-point','--no-fork-point',
               '--ignore-whitespace','--whitespace','--committer-date-is-author-date',
               '--ignore-date','--reset-author-date','--signoff',
               '-i','--interactive','-r','--rebase-merges','--no-rebase-merges',
               '-x','--exec','--root','--autosquash','--no-autosquash',
               '--autostash','--no-autostash','--reschedule-failed-exec',
               '--no-reschedule-failed-exec','--skip','--continue','--abort',
               '--quit','--edit-todo','--show-current-patch',
               '-m','--merge','-s','--strategy','-X','--strategy-option',
               '-S','--gpg-sign','--no-gpg-sign','--apply','--no-apply',
               '--empty','--keep-empty','--no-keep-empty','--rerere-autoupdate',
               '--no-rerere-autoupdate','--update-refs','--no-update-refs')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix
    }
}

# git remote
$script:SubcommandCompleters['remote'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $subCmds = @('add','rename','remove','rm','set-head','set-branches',
                 'get-url','set-url','show','prune','update')
    if ($PrevWords.Count -eq 0) {
        Complete-List -Prefix $Prefix -Items $subCmds
    } else {
        $sub = $PrevWords[0]
        switch ($sub) {
            { $_ -in 'rename','remove','rm','set-head','set-branches',
                      'get-url','set-url','show','prune' } {
                Complete-GitRemote -Prefix $Prefix
            }
        }
    }
}

# git reset
$script:SubcommandCompleters['reset'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--soft','--mixed','--hard','--merge','--keep',
               '-p','--patch','-q','--quiet','--no-quiet',
               '--pathspec-from-file','--pathspec-file-nul','--recurse-submodules',
               '--no-recurse-submodules')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git revert
$script:SubcommandCompleters['revert'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--edit','--no-edit','-n','--no-commit','-s','--signoff',
               '-m','--mainline','-S','--gpg-sign','--no-gpg-sign',
               '--strategy','--strategy-option','-X','--rerere-autoupdate',
               '--no-rerere-autoupdate','--continue','--skip','--abort','--quit',
               '--cleanup','--reference','--no-reference')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git rm
$script:SubcommandCompleters['rm'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-f','--force','-n','--dry-run','-r','--cached',
               '--ignore-unmatch','--sparse','-q','--quiet',
               '--pathspec-from-file','--pathspec-file-nul')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitFile -Prefix $Prefix -Staged
    }
}

# git show
$script:SubcommandCompleters['show'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--stat','--name-only','--name-status','--format','--pretty',
               '--oneline','--abbrev-commit','--no-abbrev-commit','--notes',
               '--no-notes','--show-notes','--no-patch','-s','--patch','-p')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git stash
$script:SubcommandCompleters['stash'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $subCmds = @('list','show','drop','pop','apply','branch','clear','push','save','create','store')
    if ($PrevWords.Count -eq 0) {
        Complete-List -Prefix $Prefix -Items $subCmds
    } else {
        $sub = $PrevWords[0]
        switch ($sub) {
            { $_ -in 'show','drop','pop','apply','branch' } { Complete-GitStash -Prefix $Prefix }
            'push'  {
                $flags = @('-p','--patch','-k','--keep-index','--no-keep-index',
                           '-u','--include-untracked','--all','-a','-q','--quiet',
                           '-m','--message','--pathspec-from-file','--pathspec-file-nul')
                Complete-List -Prefix $Prefix -Items $flags
            }
        }
    }
}

# git status
$script:SubcommandCompleters['status'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-s','--short','-b','--branch','--porcelain','--long',
               '-v','--verbose','-u','--untracked-files',
               '--ignore-submodules','--ignored','--column','--no-column',
               '--ahead-behind','--no-ahead-behind','--renames','--no-renames',
               '--find-renames','--pathspec-from-file','--pathspec-file-nul')
    Complete-List -Prefix $Prefix -Items $flags
}

# git submodule
$script:SubcommandCompleters['submodule'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $subCmds = @('add','status','init','deinit','update','set-branch',
                 'set-url','summary','foreach','sync','absorbgitdirs')
    if ($PrevWords.Count -eq 0) {
        Complete-List -Prefix $Prefix -Items $subCmds
    }
}

# git tag
$script:SubcommandCompleters['tag'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-a','--annotate','-s','--sign','-u','--local-user',
               '-f','--force','-d','--delete','-v','--verify',
               '-l','--list','--sort','--color','--no-color',
               '-m','--message','-F','--file','-e','--edit',
               '--contains','--no-contains','--merged','--no-merged',
               '--points-at','--format','--create-reflog',
               '--cleanup','--column','--no-column','--ignore-case','-i')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -TagsOnly
    }
}

# git config
$script:SubcommandCompleters['config'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--global','--system','--local','--worktree','--file','-f',
               '--blob','--get','--get-all','--get-regexp','--get-urlmatch',
               '--replace-all','--add','--unset','--unset-all','--rename-section',
               '--remove-section','-l','--list','--fixed-value','--type',
               '--bool','--int','--float','--bool-or-int','--bool-or-str','--path','--expiry-date',
               '--null','-z','--name-only','--show-origin','--show-scope',
               '-e','--edit','--no-includes','--includes',
               '--default','--comment')
    Complete-List -Prefix $Prefix -Items $flags
}

# git worktree
$script:SubcommandCompleters['worktree'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $subCmds = @('add','list','lock','move','prune','remove','repair','unlock')
    if ($PrevWords.Count -eq 0) {
        Complete-List -Prefix $Prefix -Items $subCmds
    } elseif ($PrevWords[0] -in @('remove','lock','unlock','move')) {
        Complete-GitWorktree -Prefix $Prefix
    }
}

# git cherry-pick
$script:SubcommandCompleters['cherry-pick'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-e','--edit','-x','-r','-m','--mainline','-n','--no-commit',
               '-s','--signoff','-S','--gpg-sign','--no-gpg-sign',
               '--ff','--allow-empty','--allow-empty-message','--keep-redundant-commits',
               '--strategy','--strategy-option','-X','--rerere-autoupdate',
               '--no-rerere-autoupdate','--continue','--skip','--quit','--abort',
               '--cleanup','--no-gpg-sign')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git bisect
$script:SubcommandCompleters['bisect'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $subCmds = @('start','bad','new','good','old','terms','skip','reset','visualize','replay','log','run')
    Complete-List -Prefix $Prefix -Items $subCmds
}

# git describe
$script:SubcommandCompleters['describe'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--dirty','--broken','--all','--tags','--contains',
               '--abbrev','--candidates','--exact-match','--long',
               '--match','--exclude','--always','--first-parent',
               '--debug')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git clone
$script:SubcommandCompleters['clone'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('--local','-l','--no-hardlinks','--shared','-s','--reference',
               '--reference-if-able','--dissociate','--quiet','-q','--verbose','-v',
               '--progress','--no-checkout','-n','--bare','--mirror','--origin','-o',
               '--branch','-b','--upload-pack','-u','--template','--config','-c',
               '--depth','--shallow-since','--shallow-exclude','--single-branch',
               '--no-single-branch','--no-tags','--recurse-submodules',
               '--shallow-submodules','--no-shallow-submodules','--remote-submodules',
               '--no-remote-submodules','--separate-git-dir','--jobs','-j','--bundle-uri',
               '--filter','--also-filter-submodules','--reject-shallow','--no-reject-shallow',
               '--sparse','--bundle-uri','--server-option')
    Complete-List -Prefix $Prefix -Items $flags
}

# git init
$script:SubcommandCompleters['init'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-q','--quiet','-b','--initial-branch','--bare',
               '--template','--separate-git-dir','--object-format',
               '--shared')
    Complete-List -Prefix $Prefix -Items $flags
}

# git notes
$script:SubcommandCompleters['notes'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $subCmds = @('list','add','copy','append','edit','show','merge','remove','prune','get-ref')
    if ($PrevWords.Count -eq 0) {
        Complete-List -Prefix $Prefix -Items $subCmds
    } elseif ($PrevWords[0] -in @('show','edit','copy','append','remove','add')) {
        Complete-GitRef -Prefix $Prefix -IncludeTags
    }
}

# git blame
$script:SubcommandCompleters['blame'] = {
    param([string]$Prefix, [string[]]$PrevWords)
    $flags = @('-b','-p','--porcelain','--line-porcelain','--incremental','--root',
               '--show-stats','--progress','--score-debug','-f','--show-name',
               '-n','--show-number','-s','-e','--show-email','-w',
               '--ignore-rev','--ignore-revs-file','--color-lines','--color-by-age',
               '--minimal','-S','--reverse','--first-parent','-L',
               '-M','-C','-c','--textconv','--no-textconv','--abbrev','--date',
               '--since','--until')
    if ($Prefix.StartsWith('-')) {
        Complete-List -Prefix $Prefix -Items $flags
    } else {
        Complete-GitFile -Prefix $Prefix
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Main argument completer
# ──────────────────────────────────────────────────────────────────────────────

function Complete-GitArgument {
    [CmdletBinding()]
    param(
        [string]$WordToComplete,
        [System.Management.Automation.Language.CommandAst]$CommandAst,
        [int]$CursorPosition
    )

    # Not in a git repo? Still complete subcommands and global flags
    $allWordsArr = @($CommandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() })
    $prefix      = $WordToComplete
    # Select-Object -SkipLast is PS 6+ only; use array slice for PS 5.1 compatibility
    $priorWords  = if ($allWordsArr.Count -gt 1) { $allWordsArr[0..($allWordsArr.Count - 2)] } else { @() }

    # Parse global flags and find the subcommand position
    $subCmd     = $null
    $subArgs    = [System.Collections.Generic.List[string]]::new()
    $seenSub    = $false

    foreach ($word in $priorWords) {
        if (-not $seenSub -and -not $word.StartsWith('-')) {
            $subCmd  = $word
            $seenSub = $true
        } elseif ($seenSub) {
            $subArgs.Add($word)
        }
    }

    # No subcommand yet: complete subcommands + global flags + aliases
    if (-not $seenSub -and -not $prefix.StartsWith('-')) {
        Complete-List -Prefix $prefix -Items $script:GitCommands `
            -Type ([System.Management.Automation.CompletionResultType]::ParameterValue)

        # Add user-defined aliases
        $aliases = Get-GitAliases
        foreach ($alias in $aliases.Keys) {
            if ($alias.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $tooltip = "alias: $($aliases[$alias])"
                [System.Management.Automation.CompletionResult]::new(
                    $alias, $alias,
                    [System.Management.Automation.CompletionResultType]::ParameterValue,
                    $tooltip)
            }
        }
        return
    }

    if (-not $seenSub -and $prefix.StartsWith('-')) {
        $globalFlags = @('--version','--help','-C','--exec-path','--html-path',
                         '--man-path','--info-path','-p','--paginate','--no-pager',
                         '--git-dir','--work-tree','--namespace','--super-prefix',
                         '--bare','--no-replace-objects','--literal-pathspecs',
                         '--glob-pathspecs','--noglob-pathspecs','--icase-pathspecs',
                         '--no-optional-locks','--list-cmds','--attr-source')
        Complete-List -Prefix $prefix -Items $globalFlags
        return
    }

    # Resolve alias to real command for completion purposes
    $resolvedCmd = $subCmd
    $aliases = Get-GitAliases
    if ($aliases.ContainsKey($subCmd)) {
        $aliasVal = $aliases[$subCmd]
        $resolvedCmd = ($aliasVal -split '\s+')[0]
    }

    # Dispatch to per-subcommand completer
    if ($script:SubcommandCompleters.ContainsKey($resolvedCmd)) {
        & $script:SubcommandCompleters[$resolvedCmd] $prefix $subArgs.ToArray()
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# Registration
# ──────────────────────────────────────────────────────────────────────────────

function Register-GitCompletion {
    [CmdletBinding()]
    param()

    Register-ArgumentCompleter -Native -CommandName git -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        Complete-GitArgument -WordToComplete $wordToComplete `
                             -CommandAst $commandAst `
                             -CursorPosition $cursorPosition
    }
}

function Unregister-GitCompletion {
    # PS 5.1 doesn't support unregistering native completers directly;
    # re-importing the module restores the default.
    Write-Warning 'power-git: Re-import the module (Remove-Module power-git; Import-Module power-git) to reset completion.'
}
