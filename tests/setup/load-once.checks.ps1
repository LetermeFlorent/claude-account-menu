$importBoot = '. (Join-Path $PSScriptRoot "claude-import.ps1")'
$importBootLine = 'if (-not (Test-Path Function:\Import-ClmModule)) { ' + $importBoot + ' }'
$importEntries = @("claude-menu.ps1", "claude-statusline-seed.ps1", "claude-drive-watcher.ps1")
$importStarters = $importEntries + @("claude-usage.ps1", "claude-self-update.ps1", "claude-drive-sync.ps1", "claude-drive-actions.ps1")

function Get-ImportedNames {
  param($Command)
  foreach ($e in @($Command.CommandElements | Select-Object -Skip 1)) {
    if ($e -is [Management.Automation.Language.ArrayLiteralAst]) { foreach ($x in $e.Elements) { $x.Extent.Text } } else { $e.Extent.Text }
  }
}

$bad = New-Object 'System.Collections.Generic.List[string]'
foreach ($f in Get-ChildItem -LiteralPath $bin -Filter "*.ps1" | Where-Object { $_.Name -ne "claude-import.ps1" }) {
  $tk = $null; $er = $null
  $ast = [Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tk, [ref]$er)
  $calls = 0
  foreach ($d in $ast.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq "Dot" }, $true)) {
    if ($d.GetCommandName() -eq "Import-ClmModule") {
      $names = @(Get-ImportedNames $d)
      if (@($names | Where-Object { $_ -notlike '$*' }).Count -gt 0) { $calls++ }
      foreach ($n in $names) { if ($n -notlike '$*' -and -not (Test-Path -LiteralPath (Join-Path $bin ($n + ".ps1")))) { $bad.Add($f.Name + " : module inconnu " + $n) } }
    } elseif ($d.CommandElements[0] -is [Management.Automation.Language.ParenExpressionAst] -and $d.Extent.Text -cne $importBoot) { $bad.Add($f.Name + " : " + $d.Extent.Text) }
  }
  if ($calls -gt 1 -and $f.Name -notin $importEntries) { $bad.Add($f.Name + " : " + $calls + " appels") }
  if ($f.Name -in $importStarters) {
    $first = 0
    if ($f.Name -eq "claude-menu.ps1") { $first = 1 }
    if ($ast.EndBlock.Statements[$first].Extent.Text -cne $importBootLine) { $bad.Add($f.Name + " : ne charge pas Import-ClmModule en premier") }
  }
}
Assert-Equal "" ($bad -join " | ") "chargement unique : chaque fichier charge ses modules par un seul appel a Import-ClmModule"

$oldLoader = 'param($Source, $Reader) $ProgressPreference = "SilentlyContinue"; . $Source; [bool](Get-Command $Reader -CommandType Function -ErrorAction SilentlyContinue)'
foreach ($pair in @(@("claude-usage.ps1", "Get-AccountUsage"), @("claude-self-update.ps1", "Get-LatestClm"), @("claude-drive-sync.ps1", "Invoke-DriveSync"), @("claude-drive-actions.ps1", "Save-SealedMedia"))) {
  $ps = [PowerShell]::Create()
  try {
    [void]$ps.AddScript($oldLoader).AddArgument((Join-Path $bin $pair[0])).AddArgument($pair[1])
    $got = @($ps.Invoke())
    $errs = @($ps.Streams.Error | ForEach-Object { $_.ToString() }) -join " | "
    Assert-Equal "True" (($got -join ",") + $errs) ("chargement unique : un ancien clm charge encore " + $pair[0] + " dans un espace neuf")
  } finally { $ps.Dispose() }
}

$probe = @'
param([string]$Bin, [string]$Out, [switch]$Once)
$ProgressPreference = "SilentlyContinue"
$known = @{}
foreach ($v in (Get-Variable -Scope Script)) { $known[$v.Name] = 1 }
$tk = $null; $er = $null
$menu = [Management.Automation.Language.Parser]::ParseFile((Join-Path $Bin "claude-menu.ps1"), [ref]$tk, [ref]$er)
$roots = foreach ($c in $menu.FindAll({ param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq "Import-ClmModule" }, $true)) {
  foreach ($e in @($c.CommandElements | Select-Object -Skip 1)) { if ($e -is [Management.Automation.Language.ArrayLiteralAst]) { foreach ($x in $e.Elements) { $x.Extent.Text } } else { $e.Extent.Text } }
}
if ($Once) { $script:ClmOnce = New-Object 'System.Collections.Generic.HashSet[string]' }
. (Join-Path $Bin "claude-import.ps1")
. Import-ClmModule $roots
$lines = New-Object 'System.Collections.Generic.List[string]'
foreach ($v in (Get-Variable -Scope Script | Sort-Object Name)) {
  if ($known.ContainsKey($v.Name) -or $v.Name -in @("known", "tk", "er", "menu", "roots", "c", "e", "x", "lines", "v", "ClmOnce")) { continue }
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
Assert-True (@($a | Where-Object { $_ -like "var ClmImport*" }).Count -eq 0) "chargement unique : Import-ClmModule ne laisse aucune variable derriere lui"
$diff = @(Compare-Object $a $b | ForEach-Object { $_.SideIndicator + " " + $_.InputObject })
Assert-Equal "" ($diff -join " | ") "chargement unique : memes fonctions et memes variables qu'en rechargeant tout"
