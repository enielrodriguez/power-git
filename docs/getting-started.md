# Getting Started

Learn how to install, import, and configure **power-git** in your PowerShell environment.

---

## 📋 System Requirements

* **PowerShell**: Windows PowerShell 5.1 or PowerShell 7.0+ (Windows, Linux, macOS).
* **Git**: `git` executable available in your `$env:PATH`.
* **Font** *(Optional)*: A [Nerd Font](https://www.nerdfonts.com/) if using the **Powerline** theme.

---

## 📥 Installation

### Option 1: PowerShell Gallery (Recommended)

```powershell
Install-Module power-git -Scope CurrentUser
```

### Option 2: Manual Installation

1. Clone or download the repository into a directory named `power-git`:
   ```bash
   git clone https://github.com/power-git/power-git.git power-git
   ```

2. Copy the `power-git` directory into one of your `$env:PSModulePath` locations:
   * **Windows**: `%USERPROFILE%\Documents\WindowsPowerShell\Modules\power-git\` (PS 5.1) or `%USERPROFILE%\Documents\PowerShell\Modules\power-git\` (PS 7+)
   * **Linux**: `~/.local/share/powershell/Modules/power-git/`
   * **macOS**: `~/.local/share/powershell/Modules/power-git/`

3. Import the module into your current session:
   ```powershell
   Import-Module power-git
   ```

---

## 🔄 Auto-Loading on Shell Startup

To load `power-git` automatically whenever a new PowerShell session starts, execute:

```powershell
Add-PowerGitToProfile
```

This appends `Import-Module power-git` to your PowerShell `$PROFILE`. To revert:

```powershell
Remove-PowerGitFromProfile
```

---

## 🩺 Verifying Installation

Run the diagnostic cmdlet to verify that `power-git` is properly installed, git is located, and the prompt hook is attached:

```powershell
Test-PowerGit
```

Output preview:

```
power-git diagnostic
----------------------------------------
git executable : /usr/bin/git
Settings       : loaded (WriterMode=Ansi, EnablePrompt=True)
Prompt hook    : installed
In git repo    : YES
  Branch       : main
  Upstream     : (none)
  Ahead/Behind : +0 / -0
  Staged       : A0 M0 D0
  Working      : M0 D0 ?0
  State        : clean
  StashCount   : 0
Prompt string  : ' [main]' (length=26)
```
