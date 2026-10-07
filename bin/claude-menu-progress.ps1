$script:SkipNames = @("cache", "paste-cache", "session-env", "shell-snapshots", "ide")
$script:Sizes = @{}

function Measure-Tree {
  param([IO.FileSystemInfo]$Node, [string]$Rel, [string[]]$SkipPaths)
  if ($script:SkipNames -contains $Node.Name -or $Node.Name -like "*.lock" -or $SkipPaths -contains $Rel) { return 0 }
  if (-not ($Node -is [IO.DirectoryInfo])) {
    $len = [long]$Node.Length + 1
    $script:Sizes[$Rel] = $len
    return $len
  }
  $n = [long]1
  $script:Sizes[$Rel + "/"] = 1
  try { $children = $Node.EnumerateFileSystemInfos() } catch { return $n }
  foreach ($c in $children) { $n += Measure-Tree $c ($Rel + "/" + $c.Name) $SkipPaths }
  return $n
}

function Measure-Entries {
  param([string[]]$Items, [string[]]$SkipPaths)
  $script:Sizes = @{}
  $total = [long]0
  foreach ($i in $Items) {
    $full = Join-Path $env:USERPROFILE $i
    if (Test-Path -LiteralPath $full) { $total += Measure-Tree (Get-Item -LiteralPath $full -Force) $i $SkipPaths }
  }
  return $total
}

function Read-TarLog {
  param([string]$Log)
  if (-not (Test-Path -LiteralPath $Log)) { return @() }
  try {
    $fs = [IO.File]::Open($Log, "Open", "Read", "ReadWrite")
    $sr = New-Object IO.StreamReader($fs)
    $txt = $sr.ReadToEnd()
    $sr.Close()
    return @($txt -split "`r?`n" | Where-Object { $_ -ne "" })
  } catch { return @() }
}

function Write-TarProgress {
  param([string]$Label, [int]$Pct)
  $n = [math]::Floor($Pct / 5)
  $bar = ([string][char]0x25A0) * $n + ([string][char]0x25A1) * (20 - $n)
  Write-Host ("`r  " + $Label + "  " + $bar + "  " + ("" + $Pct + " %").PadLeft(5) + "   ") -NoNewline
}

function Get-EntryWeight {
  param([string]$Line)
  $path = $Line.Substring(2)
  if ($script:Sizes.ContainsKey($path)) { return $script:Sizes[$path] }
  if ($script:Sizes.Count -gt 0) { return 0 }
  return 1
}

function Wait-Tar {
  param($Proc, [string]$Log, [long]$Total, [string]$Label)
  $last = -1; $seen = 0; $done = [long]0
  while (-not $Proc.HasExited) {
    Start-Sleep -Milliseconds 400
    $lines = @(Read-TarLog $Log | Where-Object { $_ -match "^[ax] " })
    for ($i = $seen; $i -lt $lines.Count; $i++) { $done += Get-EntryWeight $lines[$i] }
    $seen = $lines.Count
    $pct = 0
    if ($Total -gt 0) { $pct = [int][math]::Min(99, [math]::Floor($done * 100 / $Total)) }
    if ($pct -ne $last) { Write-TarProgress $Label $pct; $last = $pct }
  }
  Write-TarProgress $Label 100
  Write-Host ""
}
