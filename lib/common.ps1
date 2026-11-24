# Shared functions for install.ps1 / uninstall.ps1 (Windows). The counterpart of lib/common.sh.
# The caller sets $ZgtRoot (the repository root) and dot-sources this file.
#
# Runs on Windows PowerShell 5.1 and PowerShell 7. Keep every .ps1 file ASCII-only:
# Windows PowerShell 5.1 reads a script without a BOM in the ANSI code page. Text files are
# always read and written as UTF-8 explicitly (5.1 would otherwise write a BOM or ANSI).

$ZgtName = 'zed-git-graph-tasks'
$ZgtBegin = "// >>> $ZgtName"
$ZgtEnd = "// <<< $ZgtName"
$ZgtPlaceholder = '__ZGT_RUN__'
$ZgtUtf8 = New-Object System.Text.UTF8Encoding $false
$ZgtIndentChars = [char[]]@([char]' ', [char]"`t")
# Messages from lang/<lang>.sh, keyed without the MSG_ prefix (filled by Import-ZgtLang)
$ZgtMsg = @{}

# ---- messages ----

function Stop-Zgt([string]$Message) {
  $Host.UI.WriteErrorLine("error: $Message")
  exit 1
}

# Parse the MSG_<KEY>=<value> assignments of a lang/*.sh file into a hashtable.
# Supports the two forms used there: "..." (with \" \\ \$ \` escapes) and '...' (may span lines).
function Read-ZgtLangFile([string]$Path) {
  $text = (Read-ZgtText $Path).Replace("`r`n", "`n")
  $table = @{}
  $rx = New-Object System.Text.RegularExpressions.Regex '(?m)^MSG_([A-Z0-9_]+)='
  $pos = 0
  while ($pos -lt $text.Length) {
    $m = $rx.Match($text, $pos)
    if (-not $m.Success) { break }
    $i = $m.Index + $m.Length
    $sb = New-Object System.Text.StringBuilder
    $q = if ($i -lt $text.Length) { $text[$i] } else { [char]0 }
    if ($q -eq [char]'"') {
      $i++
      while ($i -lt $text.Length -and $text[$i] -ne [char]'"') {
        if ($text[$i] -eq [char]'\' -and $i + 1 -lt $text.Length -and '"\$`'.IndexOf($text[$i + 1]) -ge 0) {
          $i++
        }
        [void]$sb.Append($text[$i])
        $i++
      }
      $i++
    } elseif ($q -eq [char]"'") {
      $close = $text.IndexOf([char]"'", $i + 1)
      if ($close -lt 0) { $close = $text.Length }
      [void]$sb.Append($text.Substring($i + 1, $close - $i - 1))
      $i = $close + 1
    } else {
      while ($i -lt $text.Length -and -not [char]::IsWhiteSpace($text[$i])) {
        [void]$sb.Append($text[$i])
        $i++
      }
    }
    $table[$m.Groups[1].Value] = $sb.ToString()
    $pos = $i
  }
  return $table
}

# Load lang/<Lang>.sh on top of the messages loaded so far. Returns $false for an unknown language
function Import-ZgtLang([string]$Lang) {
  if ($Lang -cnotmatch '^[a-zA-Z_-]+$') { return $false }
  $path = Join-Path $ZgtRoot "lang\$Lang.sh"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
  $table = Read-ZgtLangFile $path
  foreach ($k in $table.Keys) { $ZgtMsg[$k] = $table[$k] }
  return $true
}

# The available languages (lang/*.sh), separated by spaces
function Get-ZgtLanguages {
  $names = @(Get-ChildItem -LiteralPath (Join-Path $ZgtRoot 'lang') -Filter '*.sh' -File |
      Sort-Object Name | ForEach-Object { $_.BaseName })
  return ($names -join ' ')
}

# printf-style formatting as in zgt_msg: %s / %d take the next value, %% is a literal %
function Format-ZgtMessage([string]$Format, [object[]]$Values) {
  $sb = New-Object System.Text.StringBuilder
  $vi = 0
  $i = 0
  while ($i -lt $Format.Length) {
    $c = $Format[$i]
    if ($c -eq [char]'%' -and $i + 1 -lt $Format.Length) {
      $d = $Format[$i + 1]
      if ($d -eq [char]'%') {
        [void]$sb.Append('%')
        $i += 2
        continue
      }
      if ($d -ceq [char]'s' -or $d -ceq [char]'d') {
        if ($null -ne $Values -and $vi -lt $Values.Count) { [void]$sb.Append([string]$Values[$vi]) }
        $vi++
        $i += 2
        continue
      }
    }
    [void]$sb.Append($c)
    $i++
  }
  return $sb.ToString()
}

# Get-ZgtMessage <KEY> [values...]: MSG_<KEY> of the language file, formatted with the values
function Get-ZgtMessage([string]$Key) {
  $fmt = $ZgtMsg[$Key]
  if ($null -eq $fmt) { $fmt = $Key }
  return (Format-ZgtMessage $fmt $args)
}

# Write-ZgtMessage <KEY> [values...]: print the formatted message and a newline
function Write-ZgtMessage([string]$Key) {
  $fmt = $ZgtMsg[$Key]
  if ($null -eq $fmt) { $fmt = $Key }
  Write-Host (Format-ZgtMessage $fmt $args)
}

# Write-ZgtRaw <KEY>: print the message as is (usage texts)
function Write-ZgtRaw([string]$Key) {
  Write-Host $ZgtMsg[$Key]
}

# ---- environment ----

function Assert-ZgtWindows {
  # $IsWindows exists only on PowerShell 6+; Windows PowerShell 5.1 always runs on Windows
  if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
    Stop-Zgt (Get-ZgtMessage WINDOWS_ONLY_PS)
  }
}

# A full path (relative paths are resolved against the current PowerShell location)
function Resolve-ZgtPath([string]$Path) {
  return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
}

# Zed's config directory. Matches paths::config_dir() of Zed on Windows: %APPDATA%\Zed
# (the Roaming AppData folder). ZED_CONFIG_DIR overrides it (e.g. when Zed runs with --user-data-dir)
function Get-ZgtConfigDir {
  if ($env:ZED_CONFIG_DIR) { return (Resolve-ZgtPath $env:ZED_CONFIG_DIR) }
  $appData = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
  if (-not $appData) { $appData = $env:APPDATA }
  return (Join-Path $appData 'Zed')
}

# bash.exe of Git for Windows, which runs zgt-run. Returns $null if it is not found.
# "bash" on PATH is never used: C:\Windows\System32\bash.exe is the WSL launcher.
# <Git>\bin\bash.exe (not usr\bin\bash.exe) sets up PATH so that git and coreutils are found.
function Find-ZgtBash {
  $candidates = New-Object 'System.Collections.Generic.List[string]'
  if ($env:GIT_INSTALL_ROOT) { $candidates.Add((Join-Path $env:GIT_INSTALL_ROOT 'bin\bash.exe')) }
  # From git.exe on PATH: <Git>\cmd\git.exe, <Git>\bin\git.exe or <Git>\mingw64\bin\git.exe
  foreach ($git in @(Get-Command git.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
    $dir = Split-Path -Parent $git.Path
    for ($level = 0; $level -lt 3 -and $dir; $level++) {
      $candidates.Add((Join-Path $dir 'bin\bash.exe'))
      $dir = Split-Path -Parent $dir
    }
  }
  foreach ($root in @($env:ProgramW6432, $env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if ($root) { $candidates.Add((Join-Path $root 'Git\bin\bash.exe')) }
  }
  if ($env:LOCALAPPDATA) { $candidates.Add((Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe')) }
  $scoop = $env:SCOOP
  if (-not $scoop -and $env:USERPROFILE) { $scoop = Join-Path $env:USERPROFILE 'scoop' }
  if ($scoop) { $candidates.Add((Join-Path $scoop 'apps\git\current\bin\bash.exe')) }

  foreach ($c in $candidates) {
    if ($env:SystemRoot -and $c.StartsWith($env:SystemRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
      continue
    }
    if (Test-Path -LiteralPath $c -PathType Leaf) { return [System.IO.Path]::GetFullPath($c) }
  }
  return $null
}

# git.exe for showing diffs: the one on PATH, or the one next to Git Bash
function Find-ZgtGit([string]$Bash) {
  $cmd = @(Get-Command git.exe -CommandType Application -ErrorAction SilentlyContinue)
  if ($cmd.Count -gt 0) { return $cmd[0].Path }
  if (-not $Bash) { $Bash = Find-ZgtBash }
  if ($Bash) {
    $git = Join-Path (Split-Path -Parent $Bash) 'git.exe'
    if (Test-Path -LiteralPath $git -PathType Leaf) { return $git }
  }
  return $null
}

# ---- files ----

function Read-ZgtText([string]$Path) {
  # A UTF-8 BOM, if any, is dropped
  return [System.IO.File]::ReadAllText($Path, $ZgtUtf8)
}

function Write-ZgtText([string]$Path, [string]$Text, [bool]$Bom = $false) {
  # WriteAllText opens the existing file, so a symbolic link stays a link
  [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $Bom))
}

function Test-ZgtBom([string]$Path) {
  $bytes = New-Object byte[] 3
  $fs = [System.IO.File]::OpenRead($Path)
  try { $n = $fs.Read($bytes, 0, 3) } finally { $fs.Dispose() }
  return ($n -eq 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
}

# The line ending to keep when rewriting: CRLF if the file uses it, otherwise LF
function Get-ZgtNewline([string]$Text) {
  if ($Text.Contains("`r`n")) { return "`r`n" }
  return "`n"
}

# Split text into lines without CR / LF (a final newline does not add an empty line)
function Split-ZgtLines([string]$Text) {
  $list = New-Object 'System.Collections.Generic.List[string]'
  if ($Text.Length -gt 0) {
    $parts = $Text.Split([char]"`n")
    $last = $parts.Length - 1
    if ($parts[$last].Length -eq 0) { $last-- }
    for ($i = 0; $i -le $last; $i++) { $list.Add($parts[$i].TrimEnd([char]"`r")) }
  }
  return , $list
}

# Join lines, ending each with $Newline (no lines: empty text)
function Join-ZgtLines($Lines, [string]$Newline) {
  if ($Lines.Count -eq 0) { return '' }
  return ([string]::Join($Newline, [string[]]@($Lines)) + $Newline)
}

# Copy a file that bash reads, as UTF-8 with LF line endings (a Windows checkout may have CRLF)
function Copy-ZgtLf([string]$Source, [string]$Dest) {
  $tmp = "$Dest.tmp"
  Write-ZgtText $tmp ((Read-ZgtText $Source).Replace("`r`n", "`n"))
  Move-Item -LiteralPath $tmp -Destination $Dest -Force
}

function New-ZgtTempDir {
  $path = Join-Path ([System.IO.Path]::GetTempPath()) ('zgt.' + [System.IO.Path]::GetRandomFileName())
  [void][System.IO.Directory]::CreateDirectory($path)
  return $path
}

function Remove-ZgtEmptyDir([string]$Path) {
  if ((Test-Path -LiteralPath $Path -PathType Container) -and
    @([System.IO.Directory]::GetFileSystemEntries($Path)).Count -eq 0) {
    Remove-Item -LiteralPath $Path -Force
  }
}

# The value saved at install time (empty if none)
function Get-ZgtState([string]$Path, [string]$Key) {
  $value = ''
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    foreach ($line in (Split-ZgtLines (Read-ZgtText $Path))) {
      if ($line.StartsWith("$Key=", [System.StringComparison]::Ordinal)) { $value = $line.Substring($Key.Length + 1) }
    }
  }
  return $value
}

# Back up the file before rewriting it and return the backup path
function Backup-ZgtFile([string]$Source, [string]$Dir) {
  [void][System.IO.Directory]::CreateDirectory($Dir)
  $dest = Join-Path $Dir ('tasks.json.{0}.{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $PID)
  [System.IO.File]::Copy($Source, $dest)
  return $dest
}

# Print the unified diff from $Old ('/dev/null' for a missing file) to $New with git diff --no-index.
# git's output is read as UTF-8 here; letting PowerShell decode it would garble non-ASCII text on 5.1
function Show-ZgtDiff([string]$Git, [string]$Old, [string]$New) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $Git
  $psi.Arguments = ('--no-pager -c core.quotepath=false diff --no-index --no-color -- "{0}" "{1}"' -f $Old, $New)
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.StandardOutputEncoding = $ZgtUtf8
  $proc = [System.Diagnostics.Process]::Start($psi)
  $out = $proc.StandardOutput.ReadToEnd()
  $proc.WaitForExit()
  if ($out.Length -gt 0) { Write-Host $out.TrimEnd([char]"`n") }
}

# ---- tasks.json (JSON with comments) ----

# Convert Zed's tasks.json (comments and trailing commas allowed) to strict JSON.
# A port of zgt_jsonc_to_json in lib/common.sh
function ConvertFrom-ZgtJsonc([string]$Text) {
  $out = New-Object System.Text.StringBuilder
  $pbuf = New-Object System.Text.StringBuilder # whitespace after a comma, held until we know it is not trailing
  $pending = $false
  $inStr = $false
  $esc = $false
  $inBlock = $false
  foreach ($line in (Split-ZgtLines $Text)) {
    $n = $line.Length
    $i = 0
    while ($i -lt $n) {
      $c = $line[$i]
      $next = if ($i + 1 -lt $n) { $line[$i + 1] } else { [char]0 }
      if ($inBlock) {
        if ($c -eq [char]'*' -and $next -eq [char]'/') { $inBlock = $false; $i += 2 } else { $i++ }
        continue
      }
      if ($inStr) {
        [void]$out.Append($c)
        if ($esc) { $esc = $false }
        elseif ($c -eq [char]'\') { $esc = $true }
        elseif ($c -eq [char]'"') { $inStr = $false }
        $i++
        continue
      }
      if ($c -eq [char]'/' -and $next -eq [char]'/') { break }
      if ($c -eq [char]'/' -and $next -eq [char]'*') { $inBlock = $true; $i += 2; continue }
      if ($c -eq [char]' ' -or $c -eq [char]"`t") {
        if ($pending) { [void]$pbuf.Append($c) } else { [void]$out.Append($c) }
        $i++
        continue
      }
      if ($c -eq [char]',') {
        if ($pending) { [void]$out.Append(',').Append($pbuf.ToString()) }
        $pending = $true
        [void]$pbuf.Clear()
        $i++
        continue
      }
      if ($c -eq [char]']' -or $c -eq [char]'}') {
        # A trailing comma: drop it and keep the whitespace
        if ($pending) { [void]$out.Append($pbuf.ToString()); $pending = $false; [void]$pbuf.Clear() }
        [void]$out.Append($c)
        $i++
        continue
      }
      if ($pending) { [void]$out.Append(',').Append($pbuf.ToString()); $pending = $false; [void]$pbuf.Clear() }
      if ($c -eq [char]'"') { $inStr = $true }
      [void]$out.Append($c)
      $i++
    }
    if ($pending) { [void]$pbuf.Append("`n") } else { [void]$out.Append("`n") }
  }
  if ($pending) { [void]$out.Append(',').Append($pbuf.ToString()) }
  return $out.ToString()
}

# Parse strict JSON whose top level must be an array. Returns the array, or $null if it is not one.
# The text is wrapped in an object so that 5.1 and 7 return the array the same way
# (ConvertFrom-Json enumerates a top-level array on 6+ but not on 5.1)
function ConvertFrom-ZgtJsonArray([string]$Json) {
  try {
    $wrapped = ConvertFrom-Json -InputObject ('{"v":' + $Json + "`n}") -ErrorAction Stop
  } catch {
    return $null
  }
  if ($wrapped -isnot [System.Management.Automation.PSCustomObject] -or
    @($wrapped.PSObject.Properties).Count -ne 1) {
    return $null
  }
  $value = $wrapped.v
  if ($value -is [array]) { return , $value }
  return $null
}

# Whether the text can be read as tasks.json (the top level is an array)
function Test-ZgtJsonc([string]$Text) {
  return ($null -ne (ConvertFrom-ZgtJsonArray (ConvertFrom-ZgtJsonc $Text)))
}

# The value of the property $Name (case-sensitive) of a JSON object, or $null
function Get-ZgtJsonProp($Object, [string]$Name) {
  if ($Object -is [System.Management.Automation.PSCustomObject]) {
    foreach ($p in $Object.PSObject.Properties) {
      if ($p.Name -ceq $Name) { return , $p.Value }
    }
  }
  return $null
}

# The number of tasks in tasks.json text that run zgt-run with Git Bash
function Measure-ZgtManaged([string]$Text, [string]$Bash, [string]$Runner) {
  $count = 0
  foreach ($e in (ConvertFrom-ZgtJsonArray (ConvertFrom-ZgtJsonc $Text))) {
    $cmd = Get-ZgtJsonProp $e 'command'
    $taskArgs = Get-ZgtJsonProp $e 'args'
    if ($cmd -is [string] -and $cmd -eq $Bash -and $taskArgs -is [array] -and
      $taskArgs.Count -gt 0 -and $taskArgs[0] -ceq $Runner) {
      $count++
    }
  }
  return $count
}

# ---- building the block ----

function ConvertTo-ZgtJsonString([string]$Text) {
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append('"')
  foreach ($c in $Text.ToCharArray()) {
    $code = [int]$c
    if ($code -eq 0x22) { [void]$sb.Append('\"') }
    elseif ($code -eq 0x5C) { [void]$sb.Append('\\') }
    elseif ($code -eq 0x0A) { [void]$sb.Append('\n') }
    elseif ($code -eq 0x0D) { [void]$sb.Append('\r') }
    elseif ($code -eq 0x09) { [void]$sb.Append('\t') }
    elseif ($code -eq 0x08) { [void]$sb.Append('\b') }
    elseif ($code -eq 0x0C) { [void]$sb.Append('\f') }
    elseif ($code -lt 0x20 -or $code -eq 0x7F) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
    else { [void]$sb.Append($c) }
  }
  [void]$sb.Append('"')
  return $sb.ToString()
}

# JSON text in jq's layout (2-space indent, non-ASCII kept as is). Lines after the first are
# indented for nesting level $Level
function ConvertTo-ZgtJson($Value, [int]$Level) {
  $pad = '  ' * ($Level + 1)
  $close = '  ' * $Level
  if ($null -eq $Value) { return 'null' }
  if ($Value -is [string]) { return (ConvertTo-ZgtJsonString $Value) }
  if ($Value -is [bool]) {
    if ($Value) { return 'true' }
    return 'false'
  }
  if ($Value -is [System.Collections.IDictionary]) {
    if ($Value.Count -eq 0) { return '{}' }
    $items = @(foreach ($k in $Value.Keys) {
        $pad + (ConvertTo-ZgtJsonString ([string]$k)) + ': ' + (ConvertTo-ZgtJson $Value[$k] ($Level + 1))
      })
    return "{`n" + ($items -join ",`n") + "`n$close}"
  }
  if ($Value -is [System.Management.Automation.PSCustomObject]) {
    $items = @(foreach ($p in $Value.PSObject.Properties) {
        $pad + (ConvertTo-ZgtJsonString $p.Name) + ': ' + (ConvertTo-ZgtJson $p.Value ($Level + 1))
      })
    if ($items.Count -eq 0) { return '{}' }
    return "{`n" + ($items -join ",`n") + "`n$close}"
  }
  if ($Value -is [System.Collections.IEnumerable]) {
    $items = @(foreach ($v in $Value) { $pad + (ConvertTo-ZgtJson $v ($Level + 1)) })
    if ($items.Count -eq 0) { return '[]' }
    return "[`n" + ($items -join ",`n") + "`n$close]"
  }
  return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

# A task of tasks.d for Windows. Tasks with "command": "__ZGT_RUN__" run zgt-run with Git Bash:
#   "command": <bash.exe>, "args": [<zgt-run>, <the original args>...]
function ConvertTo-ZgtWindowsTask($Task, [string]$Bash, [string]$Runner) {
  $ours = (Get-ZgtJsonProp $Task 'command') -ceq $ZgtPlaceholder
  $hasArgs = $false
  foreach ($p in $Task.PSObject.Properties) {
    if ($p.Name -ceq 'args') { $hasArgs = $true }
  }
  $result = [ordered]@{}
  foreach ($p in $Task.PSObject.Properties) {
    if ($ours -and $p.Name -ceq 'command') {
      $result['command'] = $Bash
      if (-not $hasArgs) { $result['args'] = @($Runner) }
    } elseif ($ours -and $p.Name -ceq 'args') {
      $result['args'] = @($Runner) + @($p.Value)
    } else {
      $result[$p.Name] = $p.Value
    }
  }
  return $result
}

# Combine tasks.d/*.json in name order and convert them for Windows (build.sh for install.ps1)
function Get-ZgtTasks([string]$Bash, [string]$Runner) {
  $files = @(Get-ChildItem -LiteralPath (Join-Path $ZgtRoot 'tasks.d') -File |
      Where-Object { $_.Extension -eq '.json' } | Sort-Object Name)
  if ($files.Count -eq 0) { Stop-Zgt (Get-ZgtMessage NO_FRAGMENTS) }
  $tasks = New-Object 'System.Collections.Generic.List[object]'
  foreach ($f in $files) {
    $arr = ConvertFrom-ZgtJsonArray (Read-ZgtText $f.FullName)
    if ($null -eq $arr) { Stop-Zgt (Get-ZgtMessage BAD_FRAGMENT $f.FullName) }
    foreach ($e in $arr) {
      if (-not ((Get-ZgtJsonProp $e 'label') -is [string]) -or
        -not ((Get-ZgtJsonProp $e 'command') -is [string])) {
        Stop-Zgt (Get-ZgtMessage BAD_FRAGMENT $f.FullName)
      }
    }
    foreach ($e in $arr) { $tasks.Add((ConvertTo-ZgtWindowsTask $e $Bash $Runner)) }
  }
  return , $tasks
}

# The managed block inserted into tasks.json (marker lines included), as a list of lines
function New-ZgtBlock($Tasks) {
  $lines = New-Object 'System.Collections.Generic.List[string]'
  $lines.Add('  ' + $ZgtBegin + ' ' + (Get-ZgtMessage BLOCK_NOTE_PS))
  foreach ($t in $Tasks) {
    $json = '  ' + (ConvertTo-ZgtJson $t 1) + ','
    foreach ($l in $json.Split([char]"`n")) { $lines.Add($l) }
  }
  $lines.Add('  ' + $ZgtEnd)
  return , $lines
}

# ---- the managed block in tasks.json (ports of the awk scripts in lib/common.sh) ----

function Test-ZgtMarker([string]$Line, [string]$Marker) {
  return $Line.TrimStart($ZgtIndentChars).StartsWith($Marker, [System.StringComparison]::Ordinal)
}

# none / ok / broken
function Get-ZgtMarkerState($Lines) {
  $nb = 0; $ne = 0; $lb = 0; $le = 0; $n = 0
  foreach ($line in $Lines) {
    $n++
    if (Test-ZgtMarker $line $ZgtBegin) { $nb++; if ($lb -eq 0) { $lb = $n } }
    if (Test-ZgtMarker $line $ZgtEnd) { $ne++; if ($le -eq 0) { $le = $n } }
  }
  if ($nb -eq 0 -and $ne -eq 0) { return 'none' }
  if ($nb -eq 1 -and $ne -eq 1 -and $lb -lt $le) { return 'ok' }
  return 'broken'
}

# The lines without the managed block (marker lines included)
function Remove-ZgtBlock($Lines) {
  $out = New-Object 'System.Collections.Generic.List[string]'
  $skip = $false
  foreach ($line in $Lines) {
    if (-not $skip -and (Test-ZgtMarker $line $ZgtBegin)) { $skip = $true; continue }
    if ($skip -and (Test-ZgtMarker $line $ZgtEnd)) { $skip = $false; continue }
    if (-not $skip) { $out.Add($line) }
  }
  return , $out
}

# The lines with the existing managed block replaced by $Block
function Set-ZgtBlock($Lines, $Block) {
  $out = New-Object 'System.Collections.Generic.List[string]'
  $skip = $false
  foreach ($line in $Lines) {
    if (-not $skip -and (Test-ZgtMarker $line $ZgtBegin)) { $out.AddRange($Block); $skip = $true; continue }
    if ($skip -and (Test-ZgtMarker $line $ZgtEnd)) { $skip = $false; continue }
    if (-not $skip) { $out.Add($line) }
  }
  return , $out
}

# The lines with $Block inserted right after the "[" that opens the top-level array.
# Returns $null if the first token is not "["
function Add-ZgtBlock($Lines, $Block) {
  $out = New-Object 'System.Collections.Generic.List[string]'
  $done = $false
  $inBlock = $false
  foreach ($line in $Lines) {
    if ($done) { $out.Add($line); continue }
    $n = $line.Length
    $i = 0
    while ($i -lt $n) {
      $c = $line[$i]
      $next = if ($i + 1 -lt $n) { $line[$i + 1] } else { [char]0 }
      if ($inBlock) {
        if ($c -eq [char]'*' -and $next -eq [char]'/') { $inBlock = $false; $i += 2 } else { $i++ }
        continue
      }
      if ($c -eq [char]' ' -or $c -eq [char]"`t") { $i++; continue }
      if ($c -eq [char]'/' -and $next -eq [char]'/') { break }
      if ($c -eq [char]'/' -and $next -eq [char]'*') { $inBlock = $true; $i += 2; continue }
      if ($c -eq [char]'[') {
        $out.Add($line.Substring(0, $i + 1))
        $out.AddRange($Block)
        $rest = $line.Substring($i + 1)
        if ($rest.Trim($ZgtIndentChars).Length -gt 0) { $out.Add($rest) }
        $done = $true
        break
      }
      return $null
    }
    if (-not $done) { $out.Add($line) }
  }
  if (-not $done) { return $null }
  return , $out
}
