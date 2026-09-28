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

### 1. The prompt did not change after running `Install-Module`

**Cause**: In PowerShell, `Install-Module` only downloads the module files to your machine. It does not import the module into your active terminal session or configure shell startup automatically.

**Solution**:
1. **Activate immediately in current session**:
   ```powershell
   Import-Module power-git
   ```
2. **Auto-load on startup**: Add the module to your `$PROFILE` so it activates in every new PowerShell window:
   ```powershell
   Add-PowerGitToProfile
   ```
3. **Verify with diagnostics**:
   ```powershell
   Test-PowerGit
   ```
4. **Execution Policy (Windows)**: If your profile cannot be loaded due to script execution restrictions, allow local scripts:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
5. **Using Oh My Posh or Starship?** Ensure `Import-Module power-git` appears **after** their initialization lines in `$PROFILE` so `power-git` can wrap around the prompt.

---

### 2. Powerline theme characters display as broken boxes (`[?]` or `□`)

**Cause**: The Powerline theme requires a installed [Nerd Font](https://www.nerdfonts.com/).

**Solution**:
1. Run `Install-PowerGitFont` (on Windows) or download a Nerd Font manually (e.g. `CascadiaCode NF`, `FiraCode NF`).
2. Set your terminal application font to the installed Nerd Font:
   * **Windows Terminal**: `Settings > Profiles > Appearance > Font face` -> `CascadiaCode NF`
   * **VS Code Terminal**: `"terminal.integrated.fontFamily": "CascadiaCode NF"`
   * **iTerm2 / Alacritty / Kitty**: Select the installed NF variant in terminal preferences.

---

### 3. Colors look dull or raw escape codes (`^[32m`) are visible in Windows Console

**Cause**: ANSI virtual terminal processing is disabled in classic Windows ConsoleHost.

**Solution**:
`power-git` attempts to enable ANSI processing automatically. If your terminal host does not support ANSI VT100 codes, switch to Legacy rendering mode:

```powershell
$global:PowerGitSettings.WriterMode = 'Legacy'
```

---

### 4. Prompt is slow in large monorepos

**Cause**: Scanning thousands of untracked or modified files in massive monorepos can take time.

**Solution**:
Disable file status counting for the current repository:

```powershell
Disable-GitFileStatus
```

This retains branch name and ahead/behind status while bypassing file enumeration for that specific directory.

---

### 5. Reverting to original prompt

To turn off `power-git` prompt integration without removing the module:

```powershell
Disable-GitPrompt
```

To re-enable:

```powershell
Enable-GitPrompt
```
