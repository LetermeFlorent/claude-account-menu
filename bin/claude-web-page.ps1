. Import-ClmModule claude-json
$script:WebRoot = Join-Path $PSScriptRoot "clm-web"
$script:WebLangRoot = Join-Path $PSScriptRoot "lang"
$script:WebTypes = @{ ".html" = "text/html; charset=utf-8"; ".css" = "text/css; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"; ".json" = "application/json; charset=utf-8" }
$script:WebTokenBlock = New-Object regex ':root\[data-theme="(light|dark)"\]\s*\{([^}]*)\}'
$script:WebTokenLine = New-Object regex '--([a-z0-9-]+):\s*([^;]+);'

function Add-WebPageFiles {
  param($Page, [string]$Root, [string]$Prefix, [IO.SearchOption]$Depth)
  if (-not [IO.Directory]::Exists($Root)) { return }
  $full = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]"\/")
  foreach ($f in [IO.Directory]::GetFiles($full, "*", $Depth)) {
    $type = $script:WebTypes[[IO.Path]::GetExtension($f).ToLowerInvariant()]
    if ($null -eq $type) { continue }
    $name = $Prefix + $f.Substring($full.Length + 1).Replace("\", "/")
    $Page[$name] = @{ Type = $type; Bytes = [IO.File]::ReadAllBytes($f) }
  }
}

function Read-WebPage {
  param([string]$Root = $script:WebRoot, [string]$LangRoot = $script:WebLangRoot)
  $page = New-PathMap
  Add-WebPageFiles $page $Root "" ([IO.SearchOption]::AllDirectories)
  Add-WebPageFiles $page $LangRoot "lang/" ([IO.SearchOption]::TopDirectoryOnly)
  return $page
}

function Get-WebPageText {
  param($Page, [string]$Name)
  if (-not $Page.ContainsKey($Name)) { return "" }
  return [Text.Encoding]::UTF8.GetString($Page[$Name].Bytes)
}

function Get-ThemeTokens {
  param([string]$Css)
  $out = @{}
  foreach ($block in $script:WebTokenBlock.Matches($Css)) {
    $set = @{}
    foreach ($line in $script:WebTokenLine.Matches($block.Groups[2].Value)) { $set[$line.Groups[1].Value] = $line.Groups[2].Value.Trim() }
    $out[$block.Groups[1].Value] = $set
  }
  return $out
}

function Set-WebPage {
  param([string]$Root = $script:WebRoot, [string]$LangRoot = $script:WebLangRoot)
  $script:WebPage = Read-WebPage $Root $LangRoot
  $script:WebTokens = Get-ThemeTokens (Get-WebPageText $script:WebPage "css/tokens.css")
}

try { Set-WebPage } catch {
  Write-Verbose $_.Exception.Message
  $script:WebPage = New-PathMap
  $script:WebTokens = @{}
}
