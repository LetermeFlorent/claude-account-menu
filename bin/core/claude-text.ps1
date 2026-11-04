if (-not (Test-Path Function:\Import-ClmModule)) { . (Join-Path $PSScriptRoot "../claude-import.ps1") }
. Import-ClmModule claude-json, claude-lang
$script:TextRoot = Join-Path $script:ClmModuleDir "lang"
$script:TextTables = @{}
$script:TextCache = $null
$script:TextCacheOf = $null

function Read-ClmTextTable {
  param([string]$Path)
  try { $data = ConvertFrom-JsonText ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)) } catch { $data = $null }
  if ($data -is [Collections.IDictionary]) { return $data }
  return @{}
}

function Set-ClmTexts {
  param([string]$Root = $script:TextRoot)
  $tables = @{}
  foreach ($code in $script:LangCodes) { $tables[$code] = Read-ClmTextTable (Join-Path $Root ($code + ".json")) }
  $script:TextTables = $tables
}

function Format-ClmText {
  param([string]$Text, [object[]]$Values)
  for ($i = 0; $i -lt $Values.Count; $i++) { $Text = $Text.Replace("{" + $i + "}", [string]$Values[$i]) }
  return $Text
}

function Get-ClmText {
  param([string]$Key, [object[]]$Values = @(), [string]$Lang = "")
  if (-not $Lang) { $Lang = Get-ClmLang }
  if (-not [object]::ReferenceEquals($script:TextCacheOf, $script:TextTables)) {
    $script:TextCache = New-PathMap
    $script:TextCacheOf = $script:TextTables
  }
  $id = $Lang + [char]1 + $Key
  $hit = $script:TextCache[$id]
  if ($null -eq $hit) {
    $hit = @($Key, $false)
    foreach ($code in @($Lang, $script:LangFallback)) {
      $table = $script:TextTables[$code]
      if ($null -ne $table -and $null -ne $table[$Key]) { $hit = @([string]$table[$Key], $true); break }
    }
    $script:TextCache[$id] = $hit
  }
  if (-not $hit[1] -or $Values.Count -eq 0) { return $hit[0] }
  return Format-ClmText $hit[0] $Values
}

Set-ClmTexts
