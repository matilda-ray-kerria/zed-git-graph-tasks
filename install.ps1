# Adds the Git Graph custom commands to Zed's global tasks.json on Windows (run again to update).
# The Windows counterpart of install.sh. The tasks run "git zgt-run" with git (Git for Windows)
# on PATH; the launcher is passed as a git alias in env (see lib\common.ps1).
#
#   powershell -ExecutionPolicy Bypass -File .\install.ps1 [-Lang en|ja] [-DryRun]
#
# Runs on Windows PowerShell 5.1 and PowerShell 7. Keep this file ASCII-only (see lib\common.ps1).
[CmdletBinding()]
param(
  [string]$Lang,
  [switch]$DryRun,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ZgtRoot = $PSScriptRoot
. (Join-Path $ZgtRoot 'lib\common.ps1')

# Load English first in case a message is needed before the language is known
[void](Import-ZgtLang 'en')

$configDir = Get-ZgtConfigDir
$tasksFile = Join-Path $configDir 'tasks.json'
$installDir = Join-Path $configDir $ZgtName
$runner = Join-Path $installDir 'zgt-run'
$state = Join-Path $installDir 'state'

# Language: -Lang > the previous choice > English
if (-not $Lang) { $Lang = Get-ZgtState $state 'lang' }
if (-not $Lang) { $Lang = 'en' }
if (-not (Import-ZgtLang $Lang)) { Stop-Zgt (Get-ZgtMessage UNKNOWN_LANG $Lang (Get-ZgtLanguages)) }

if ($Help) {
  Write-ZgtRaw INSTALL_USAGE_PS
  exit 0
}
Assert-ZgtWindows

# Zed runs the tasks ("git zgt-run") from PowerShell / cmd, which find git through PATH.
# git reads the alias from GIT_CONFIG_COUNT / GIT_CONFIG_KEY_0 / GIT_CONFIG_VALUE_0 since 2.31
$git = Find-ZgtGit
if (-not $git) { Stop-Zgt (Get-ZgtMessage NO_GIT_PS) }
$gitVersion = Get-ZgtGitVersion $git
if ($null -eq $gitVersion -or $gitVersion -lt $ZgtGitMinVersion) {
  Stop-Zgt (Get-ZgtMessage GIT_TOO_OLD_PS $git ([string]$gitVersion) ([string]$ZgtGitMinVersion))
}

# zgt-run is given to bash with forward slashes ($0 is split with dirname inside zgt-run)
$runnerArg = $runner.Replace('\', '/')
$tasks = Get-ZgtTasks $runnerArg
$expected = $tasks.Count
$block = New-ZgtBlock $tasks

$exists = Test-Path -LiteralPath $tasksFile
$created = $false
$bom = $false
$newline = "`n"
$text = ''
if ($exists) { $text = Read-ZgtText $tasksFile }
if (-not $exists -or $text -notmatch '\S') {
  # A missing / empty file is created anew
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $lines.Add('[')
  $lines.AddRange($block)
  $lines.Add(']')
  if (-not $exists) { $created = $true }
} else {
  # Keep the line endings and the BOM of the existing file
  $bom = Test-ZgtBom $tasksFile
  $newline = Get-ZgtNewline $text
  if (-not (Test-ZgtJsonc $text)) { Stop-Zgt (Get-ZgtMessage TASKS_UNREADABLE $tasksFile) }
  $current = Split-ZgtLines $text
  switch (Get-ZgtMarkerState $current) {
    'ok' { $lines = Set-ZgtBlock $current $block }
    'none' {
      $lines = Add-ZgtBlock $current $block
      if ($null -eq $lines) { Stop-Zgt (Get-ZgtMessage NO_ARRAY_START $tasksFile) }
    }
    default { Stop-Zgt (Get-ZgtMessage BROKEN_MARKERS $tasksFile $ZgtBegin $ZgtEnd) }
  }
}
$newText = Join-ZgtLines $lines $newline

# Before writing, check that the result can be read and holds all of our tasks
if (-not (Test-ZgtJsonc $newText)) { Stop-Zgt (Get-ZgtMessage VERIFY_FAILED) }
$actual = Measure-ZgtManaged $newText $runnerArg
if ($actual -ne $expected) { Stop-Zgt (Get-ZgtMessage COUNT_MISMATCH $expected $actual) }

if ($DryRun) {
  Write-ZgtMessage DRYRUN_INSTALL $tasksFile
  $tmp = New-ZgtTempDir
  try {
    $newFile = Join-Path $tmp 'tasks.json'
    Write-ZgtText $newFile $newText $bom
    if ($exists) { Show-ZgtDiff $git $tasksFile $newFile } else { Show-ZgtDiff $git '/dev/null' $newFile }
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
  exit 0
}

# Put the wrapper and the messages first so that tasks.json never points to a missing file
[void][System.IO.Directory]::CreateDirectory($installDir)
Copy-ZgtLf (Join-Path $ZgtRoot "lang\$Lang.sh") (Join-Path $installDir 'messages.sh')
Copy-ZgtLf (Join-Path $ZgtRoot 'bin\zgt-run') $runner

# state: whether tasks.json was created by the installer (uninstall may delete it) and the language.
# The same file as install.sh
if (-not $created -and (Get-ZgtState $state 'created_tasks_json') -eq '1') { $created = $true }
Write-ZgtText $state ("created_tasks_json={0}`nlang={1}`n" -f [int]$created, $Lang)

if ($exists -and $text -ceq $newText) {
  Write-ZgtMessage UP_TO_DATE $expected $runner
  Write-ZgtMessage LANG_AT_PS (Get-ZgtMessage LANG_NAME)
  exit 0
}

$backup = $null
if ($exists) { $backup = Backup-ZgtFile $tasksFile (Join-Path $installDir 'backups') }
[void][System.IO.Directory]::CreateDirectory($configDir)
Write-ZgtText $tasksFile $newText $bom

Write-ZgtMessage INSTALLED $expected $tasksFile
if ($backup) { Write-ZgtMessage BACKUP_AT $backup }
Write-ZgtMessage RUNNER_AT $runner
Write-ZgtMessage GIT_AT_PS $git
Write-ZgtMessage LANG_AT_PS (Get-ZgtMessage LANG_NAME)
Write-Host ''
Write-ZgtMessage HOW_TO_USE
