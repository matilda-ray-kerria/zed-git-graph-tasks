# Removes the managed block and the wrapper added by install.ps1 (Windows).
# The Windows counterpart of uninstall.sh.
#
#   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 [-DryRun] [-Purge]
#
# Runs on Windows PowerShell 5.1 and PowerShell 7. Keep this file ASCII-only (see lib\common.ps1).
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Purge,
  [switch]$Help
)

$ErrorActionPreference = 'Stop'
$ZgtRoot = $PSScriptRoot
. (Join-Path $ZgtRoot 'lib\common.ps1')

$configDir = Get-ZgtConfigDir
$tasksFile = Join-Path $configDir 'tasks.json'
$installDir = Join-Path $configDir $ZgtName
$state = Join-Path $installDir 'state'

# Messages in the language chosen at install time (English if none)
[void](Import-ZgtLang 'en')
[void](Import-ZgtLang (Get-ZgtState $state 'lang'))

if ($Help) {
  Write-ZgtRaw UNINSTALL_USAGE_PS
  exit 0
}
Assert-ZgtWindows

$action = 'none' # none / rewrite / delete
$bom = $false
$newText = ''
if (Test-Path -LiteralPath $tasksFile -PathType Leaf) {
  $text = Read-ZgtText $tasksFile
  $current = Split-ZgtLines $text
  switch (Get-ZgtMarkerState $current) {
    'none' { }
    'ok' {
      $bom = Test-ZgtBom $tasksFile
      $newText = Join-ZgtLines (Remove-ZgtBlock $current) (Get-ZgtNewline $text)
      $action = 'rewrite'
      if ((Get-ZgtState $state 'created_tasks_json') -eq '1' -and ($newText -replace '\s', '') -ceq '[]') {
        # install.ps1 created the file and nothing else was added: delete the whole file
        $action = 'delete'
      } elseif ($newText -match '\S') {
        if (-not (Test-ZgtJsonc $newText)) { Stop-Zgt (Get-ZgtMessage STRIP_VERIFY_FAILED) }
      }
    }
    default { Stop-Zgt (Get-ZgtMessage BROKEN_MARKERS $tasksFile $ZgtBegin $ZgtEnd) }
  }
}

$hasInstallDir = Test-Path -LiteralPath $installDir -PathType Container

if ($DryRun) {
  Write-ZgtMessage DRYRUN
  switch ($action) {
    'none' { Write-ZgtMessage NO_BLOCK $tasksFile }
    'rewrite' {
      $git = Find-ZgtGit (Get-ZgtState $state 'bash')
      if (-not $git) { Stop-Zgt (Get-ZgtMessage REQUIRE_CMD 'git') }
      $tmp = New-ZgtTempDir
      try {
        $newFile = Join-Path $tmp 'tasks.json'
        Write-ZgtText $newFile $newText $bom
        Show-ZgtDiff $git $tasksFile $newFile
      } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
      }
    }
    'delete' { Write-ZgtMessage WILL_DELETE_PS $tasksFile }
  }
  if ($hasInstallDir) { Write-ZgtMessage WILL_REMOVE_RUNNER $installDir }
  if ($Purge -and $hasInstallDir) { Write-ZgtMessage WILL_PURGE $installDir }
  exit 0
}

$backup = $null
switch ($action) {
  'none' { Write-ZgtMessage NO_BLOCK $tasksFile }
  'rewrite' {
    $backup = Backup-ZgtFile $tasksFile (Join-Path $installDir 'backups')
    Write-ZgtText $tasksFile $newText $bom
    Write-ZgtMessage BLOCK_REMOVED $tasksFile
  }
  'delete' {
    $backup = Backup-ZgtFile $tasksFile (Join-Path $installDir 'backups')
    Remove-Item -LiteralPath $tasksFile -Force
    Write-ZgtMessage DELETED_PS $tasksFile
  }
}

# Backup-ZgtFile may have just created the directory
if (Test-Path -LiteralPath $installDir -PathType Container) {
  foreach ($name in @('zgt-run', 'messages.sh', 'state')) {
    $path = Join-Path $installDir $name
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
  }
  if ($Purge) {
    Remove-Item -LiteralPath $installDir -Recurse -Force
    Write-ZgtMessage PURGED $installDir
  } else {
    Remove-ZgtEmptyDir (Join-Path $installDir 'backups')
    Remove-ZgtEmptyDir $installDir
    if ($backup) { Write-ZgtMessage BACKUP_AT $backup }
    if (Test-Path -LiteralPath $installDir) { Write-ZgtMessage PURGE_HINT_PS }
  }
}
exit 0
