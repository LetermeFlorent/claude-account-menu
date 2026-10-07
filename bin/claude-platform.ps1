function Get-OsName {
  if ($PSVersionTable.PSEdition -ne "Core" -or $IsWindows) { return "Windows" }
  if ($IsMacOS) { return "MacOS" }
  return "Linux"
}
$script:OsName = Get-OsName
$script:PathSeps = [char[]]"\/"

function Read-EnvVar {
  param([string]$Name, $Vars = $null)
  if ($Vars -ne $null) { return [string]$Vars[$Name] }
  return [string][Environment]::GetEnvironmentVariable($Name)
}

function Join-OsPath {
  param([string]$Os, [string[]]$Parts)
  $sep = "/"
  if ($Os -eq "Windows") { $sep = "\" }
  $out = $Parts[0].TrimEnd($script:PathSeps)
  for ($i = 1; $i -lt $Parts.Count; $i++) { $out += $sep + $Parts[$i].Trim($script:PathSeps) }
  return $out
}

function Get-HomeDir {
  param($Vars = $null)
  $h = Read-EnvVar "USERPROFILE" $Vars
  if ($h -eq "") { $h = Read-EnvVar "HOME" $Vars }
  return $h
}

function Get-LocalAppData {
  param($Vars = $null)
  $d = Read-EnvVar "LOCALAPPDATA" $Vars
  if ($d -eq "") { $d = Join-OsPath "Windows" @((Get-HomeDir $Vars), "AppData", "Local") }
  return $d
}

function Get-XdgDir {
  param([string]$Name, [string[]]$Default, $Vars = $null)
  $d = Read-EnvVar $Name $Vars
  if ($d -ne "") { return $d }
  return Join-OsPath "Linux" (@(Get-HomeDir $Vars) + $Default)
}

function Get-StatusStatePath {
  param([string]$Os = $script:OsName, $Vars = $null)
  if ($Os -eq "Windows") { return Join-OsPath $Os @((Get-LocalAppData $Vars), "claude-statusline", "state") }
  if ($Os -eq "MacOS") { return Join-OsPath $Os @((Get-HomeDir $Vars), "Library", "Application Support", "claude-statusline", "state") }
  return Join-OsPath $Os @((Get-XdgDir "XDG_STATE_HOME" @(".local", "state") $Vars), "claude-statusline", "state")
}

function Get-StateTag {
  param([string]$ConfigDir)
  $name = (("" + $ConfigDir).TrimEnd($script:PathSeps) -split "[\\/]")[-1]
  $name = $name.ToLowerInvariant().TrimStart(".")
  $tag = [regex]::Replace($name, "[\uD800-\uDBFF][\uDC00-\uDFFF]|[^a-z0-9._-]", "_")
  if ($tag -eq "") { return "claude" }
  return $tag
}

function Get-UsageCachePath {
  param([string]$Os = $script:OsName, $Vars = $null)
  if ($Os -eq "Windows") { return Join-OsPath $Os @((Get-LocalAppData $Vars), "claude-menu", "usage.json") }
  if ($Os -eq "MacOS") { return Join-OsPath $Os @((Get-HomeDir $Vars), "Library", "Caches", "claude-menu", "usage.json") }
  return Join-OsPath $Os @((Get-XdgDir "XDG_CACHE_HOME" @(".cache") $Vars), "claude-menu", "usage.json")
}

function Get-ClaudeExeName {
  param([string]$Os = $script:OsName)
  if ($Os -eq "Windows") { return "claude.exe" }
  return "claude"
}

function Find-ClaudeExe {
  $exe = Join-OsPath $script:OsName @((Get-HomeDir), ".local", "bin", (Get-ClaudeExeName))
  if (Test-Path -LiteralPath $exe) { return $exe }
  $found = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { return $found.Source }
  return $exe
}

function Get-DirLinkType {
  if ($script:OsName -eq "Windows") { return "Junction" }
  return "SymbolicLink"
}

function ConvertTo-PathKey {
  param([string]$Path, [string]$Os = $script:OsName)
  $k = $Path.Replace("\", "/").TrimEnd("/")
  if ($Os -eq "Windows") { $k = $k.ToLower() }
  return $k
}

function Invoke-Captured {
  param([string]$Path, [string]$Arguments, [int]$TimeoutMs = 3000)
  $psi = New-Object Diagnostics.ProcessStartInfo
  $psi.FileName = $Path
  $psi.Arguments = $Arguments
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  try { $p = [Diagnostics.Process]::Start($psi) } catch { return $null }
  try {
    try { $p.StandardInput.Close() } catch {}
    $out = $p.StandardOutput.ReadToEndAsync()
    $err = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutMs)) {
      try { $p.Kill() } catch {}
      return $null
    }
    $p.WaitForExit()
    return [PSCustomObject]@{ Code = $p.ExitCode; Out = $out.Result }
  } finally { $p.Dispose() }
}
