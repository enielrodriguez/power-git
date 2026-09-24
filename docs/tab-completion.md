# Tab Completion

`power-git` registers a high-performance native PowerShell argument completer for the `git` command (`Register-ArgumentCompleter -Native -CommandName git`).

---

## ✨ Features

* **30+ Supported Subcommands**: Rich argument completion for `add`, `branch`, `checkout`, `commit`, `diff`, `fetch`, `log`, `merge`, `pull`, `push`, `rebase`, `reset`, `restore`, `revert`, `rm`, `stash`, `status`, `switch`, `tag`, `worktree`, and more.
* **Context-Aware Completion**:
  * `git add` suggests untracked/modified files.
  * `git restore` suggests modified files.
  * `git branch -d` suggests local branches.
  * `git push` suggests configured remotes and local branches.
  * `git pull` / `git fetch` suggests remotes and tracking refs.
  * `git worktree remove` suggests active git worktrees.
* **Alias Resolution**: Automatically parses your `git config --get-regexp ^alias\.` and resolves custom git aliases to complete arguments seamlessly.
* **Flag Completion**: Option flags (e.g. `--staged`, `--rebase`, `--no-ff`, `-i`) are suggested when pressing `Tab` after `-` or `--`.

---

## 💡 Example Interactive Workflows

### Branch & Ref Completion
```powershell
git checkout fe<Tab>          # Completes local/remote branch names starting with 'fe'
git switch -c fe<Tab>         # Completes branch creation flags and base refs
git merge origin/<Tab>        # Completes remote tracking refs from 'origin'
```

### File & Stash Completion
```powershell
git add <Tab>                 # Suggests untracked or modified files in current directory
git stash pop stash@{<Tab>    # Completes stash indices (e.g. stash@{0}, stash@{1})
```

### Custom Git Aliases
If you have configured aliases in git:

```bash
git config --global alias.co checkout
git config --global alias.br branch
```

Pressing `git co fe<Tab>` automatically resolves `co` to `checkout` and completes branch names.
