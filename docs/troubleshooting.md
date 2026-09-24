# Troubleshooting & FAQ

Common diagnostic steps and solutions for issues with `power-git`.

---

## 🩺 Diagnostic Cmdlet

First, run the diagnostic command to view system status and module health:

```powershell
Test-PowerGit
```

---

## ❓ Frequently Asked Questions

### 1. Powerline theme characters display as broken boxes (`[?]` or `□`)

**Cause**: The Powerline theme requires a installed [Nerd Font](https://www.nerdfonts.com/).

**Solution**:
1. Run `Install-PowerGitFont` (on Windows) or download a Nerd Font manually (e.g. `CascadiaCode NF`, `FiraCode NF`).
2. Set your terminal application font to the installed Nerd Font:
   * **Windows Terminal**: `Settings > Profiles > Appearance > Font face` -> `CascadiaCode NF`
   * **VS Code Terminal**: `"terminal.integrated.fontFamily": "CascadiaCode NF"`
   * **iTerm2 / Alacritty / Kitty**: Select the installed NF variant in terminal preferences.

---

### 2. Colors look dull or raw escape codes (`^[32m`) are visible in Windows Console

**Cause**: ANSI virtual terminal processing is disabled in classic Windows ConsoleHost.

**Solution**:
`power-git` attempts to enable ANSI processing automatically. If your terminal host does not support ANSI VT100 codes, switch to Legacy rendering mode:

```powershell
$global:PowerGitSettings.WriterMode = 'Legacy'
```

---

### 3. Prompt is slow in large monorepos

**Cause**: Scanning thousands of untracked or modified files in massive monorepos can take time.

**Solution**:
Disable file status counting for the current repository:

```powershell
Disable-GitFileStatus
```

This retains branch name and ahead/behind status while bypassing file enumeration for that specific directory.

---

### 4. Reverting to original prompt

To turn off `power-git` prompt integration without removing the module:

```powershell
Disable-GitPrompt
```

To re-enable:

```powershell
Enable-GitPrompt
```
