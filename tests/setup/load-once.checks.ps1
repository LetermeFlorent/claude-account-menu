$onceLine = [regex]'^if \(\$null -eq \$script:ClmOnce -or \$script:ClmOnce\.Add\("([^"]+)"\)\) \{ \. \(Join-Path \$PSScriptRoot "([^"]+)"\) \}$'
$bad = New-Object 'System.Collections.Generic.List[string]'
foreach ($f in Get-ChildItem -LiteralPath $bin -Filter "*.ps1") {
  foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
    if ($line -notmatch 'Join-Path \$PSScriptRoot "[^"]+\.ps1"' -or $line -notmatch '^\s*(if .*)?\. ') { continue }
    $m = $onceLine.Match($line)
    if (-not $m.Success -or $m.Groups[1].Value -cne $m.Groups[2].Value -or -not (Test-Path -LiteralPath (Join-Path $bin $m.Groups[1].Value))) { $bad.Add($f.Name + " : " + $line) }
  }
}
Assert-Equal "" ($bad -join " | ") "chargement unique : chaque fichier charge par la meme garde, sous son propre nom"

$probe = @'
param([string]$Bin, [string]$Out, [switch]$Once)
$ProgressPreference = "SilentlyContinue"
$known = @{}
foreach ($v in (Get-Variable -Scope Script)) { $known[$v.Name] = 1 }
$roots = foreach ($line in [IO.File]::ReadAllLines((Join-Path $Bin "claude-menu.ps1"))) { if ($line -match '^if \(\$null -eq \$script:ClmOnce -or \$script:ClmOnce\.Add\("([^"]+)"\)\)') { $Matches[1] } }
if ($Once) { $script:ClmOnce = New-Object 'System.Collections.Generic.HashSet[string]' }
foreach ($r in $roots) { . (Join-Path $Bin $r) }
$lines = New-Object 'System.Collections.Generic.List[string]'
foreach ($v in (Get-Variable -Scope Script | Sort-Object Name)) {
  if ($known.ContainsKey($v.Name) -or $v.Name -in @("known", "roots", "r", "line", "lines", "v", "ClmOnce")) { continue }
  $shape = "null"
  if ($null -ne $v.Value) { $shape = $v.Value.GetType().FullName }
  if ($v.Value -is [string] -or $v.Value -is [ValueType]) { $shape += "=" + $v.Value }
  elseif ($v.Value -is [Collections.ICollection]) { $shape += "#" + $v.Value.Count }
  $lines.Add("var " + $v.Name + " " + $shape)
}
foreach ($f in (Get-ChildItem function: | Sort-Object Name)) { $lines.Add("fn " + $f.Name + " " + $f.Definition.Length) }
[IO.File]::WriteAllLines($Out, $lines)
'@
$probeFile = New-SandboxFile "load-once-probe.ps1" $probe
$exe = (Get-Process -Id $PID).Path
$full = Join-Path $script:Sandbox "load-full.txt"
$once = Join-Path $script:Sandbox "load-once.txt"
& $exe -NoProfile -ExecutionPolicy Bypass -File $probeFile -Bin $bin -Out $full | Out-Null
& $exe -NoProfile -ExecutionPolicy Bypass -File $probeFile -Bin $bin -Out $once -Once | Out-Null
$a = @(); $b = @()
if (Test-Path -LiteralPath $full) { $a = [IO.File]::ReadAllLines($full) }
if (Test-Path -LiteralPath $once) { $b = [IO.File]::ReadAllLines($once) }
Assert-True (@($a | Where-Object { $_ -like "fn Invoke-AccountMenu *" }).Count -eq 1) "chargement unique : le menu se charge en entier"
$diff = @(Compare-Object $a $b | ForEach-Object { $_.SideIndicator + " " + $_.InputObject })
Assert-Equal "" ($diff -join " | ") "chargement unique : memes fonctions et memes variables qu'en rechargeant tout"
