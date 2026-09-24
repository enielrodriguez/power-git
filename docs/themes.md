# Themes & Styling

`power-git` features four built-in themes tailored for different fonts, terminals, and aesthetic preferences.

---

## 🎨 Built-in Themes

Switch themes instantly with `Set-GitTheme`:

```powershell
Set-GitTheme Default
Set-GitTheme Minimal
Set-GitTheme ASCII
Set-GitTheme Powerline
```

### 1. Default Theme
Uses clean Unicode symbols compatible with standard system fonts (Segoe UI, Consolas, Menlo, Fira Code).

```
PS C:\repo [main ↑2 | +1 ~3 ?2 ≡1]>
```

### 2. Minimal Theme
Compact representation with lightweight symbols and disabled stash count.

```
PS C:\repo [main ^2 | +1 ~3 ?2]>
```

### 3. ASCII Theme
Pure 7-bit ASCII characters for maximum compatibility across legacy console host environments and serial terminals.

```
PS C:\repo [main ^2 | +1 *3 ?2]>
```

### 4. Powerline Theme
Uses specialized glyphs from [Nerd Fonts](https://www.nerdfonts.com/).

```
PS C:\repo  main ↑2 | +1 ~3 ?2 ≡1 >
```

> **Note**: The **Powerline** theme requires a installed Nerd Font (e.g. `CascadiaCode NF`, `FiraCode NF`, `JetBrainsMono NF`). Run `Install-PowerGitFont` on Windows to install one automatically.

---

## 🔣 Symbol Reference

| Symbol Name | Default | Minimal | ASCII | Powerline | Description |
| :--- | :---: | :---: | :---: | :---: | :--- |
| `Branch` | *(text)* | *(text)* | *(text)* | `` | Branch indicator |
| `Detached` | `➦` | `➦` | `➦` | `` | Detached HEAD indicator |
| `Ahead` | `↑` | `^` | `^` | `↑` | Commits ahead of upstream |
| `Behind` | `↓` | `v` | `v` | `↓` | Commits behind upstream |
| `Diverged` | `⇅` | `<>` | `<>` | `⇅` | Diverged state (ahead and behind) |
| `UpToDate` | `✔` | `=` | `=` | `✔` | In sync with upstream |
| `Gone` | `✗` | `x` | `x` | `✗` | Upstream branch deleted |
| `Staged` | `+` | `+` | `+` | `` | Staged changes |
| `Unstaged` | `~` | `~` | `*` | `` | Unstaged changes in working tree |
| `Untracked` | `?` | `?` | `?` | `` | Untracked files |
| `Conflict` | `!` | `!` | `!` | `` | Merge conflicts |
| `Stash` | `≡` | `$` | `$` | `` | Stashed changesets |

---

## 🛠️ Overriding Individual Symbols

You can customize individual symbols programmatically:

```powershell
# Change branch symbol to custom string
$global:PowerGitSettings.Symbols.Branch = '🌿'

# Change conflict symbol to warning emoji
$global:PowerGitSettings.Symbols.Conflict = '⚠️'
```
