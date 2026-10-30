$script:RouteReal = @{ Path = ${function:Send-SealedPath}; File = ${function:Send-SealedFile}; Max = $script:DriveSimpleMax }
$script:RouteCalls = New-Object 'System.Collections.Generic.List[string]'
function Send-SealedPath {
  param($Item)
  $script:RouteCalls.Add("flux " + $Item.Rel)
  return @{ Id = "id-flux"; Md5 = "md5-flux" }
}
function Send-SealedFile {
  param($Item)
  $script:RouteCalls.Add("octets " + $Item.Rel + " " + $Item.Bytes.Length)
  return @{ Id = "id-octets"; Md5 = "md5-octets" }
}
try {
  $script:DriveSimpleMax = 10
  $routeBig = New-SandboxFile "route/big.bin" ("x" * 11)
  $routeSmall = New-SandboxFile "route/small.bin" ("x" * 10)
  $routeSettings = New-SandboxFile "route/settings.json" ('{"a": "' + ("x" * 20) + '"}')
  $null = Send-LocalFile @{ FolderId = "F"; Rel = ".claude/big.bin"; Path = $routeBig; Props = @{}; Id = ""; Keys = $null }
  $null = Send-LocalFile @{ FolderId = "F"; Rel = ".claude/small.bin"; Path = $routeSmall; Props = @{}; Id = ""; Keys = $null }
  $null = Send-LocalFile @{ FolderId = "F"; Rel = ".claude/settings.json"; Path = $routeSettings; Props = @{}; Id = ""; Keys = $null }
  Assert-Equal "flux .claude/big.bin" $script:RouteCalls[0] "envoi : gros fichier lu en flux"
  Assert-Equal "octets .claude/small.bin 10" $script:RouteCalls[1] "envoi : petit fichier en un seul corps"
  Assert-True $script:RouteCalls[2].StartsWith("octets .claude/settings.json ") "envoi : reglages du PC toujours adaptes en memoire"
  $script:RouteCalls.Clear()
  $routeCtx = @{ Folder = "F"; Pc = "PC"; Keys = $null; Prefetch = $null; Remote = @{}; State = @{ Files = @{} } }
  $routeCtx.Local = @{ ".claude/big.bin" = @{ Full = $routeBig; M = 5; Size = 11; Md5 = "lm" } }
  Send-SyncFile $routeCtx ".claude/big.bin"
  Assert-Equal "flux .claude/big.bin" ($script:RouteCalls -join ",") "synchro : gros fichier envoye en flux"
  Assert-Equal "id-flux|md5-flux" ($routeCtx.State.Files[".claude/big.bin"].Id + "|" + $routeCtx.State.Files[".claude/big.bin"].Md5) "synchro : id et empreinte du fichier envoye en flux"
} finally {
  Set-Item Function:\Send-SealedPath $script:RouteReal.Path
  Set-Item Function:\Send-SealedFile $script:RouteReal.File
  $script:DriveSimpleMax = $script:RouteReal.Max
}
Remove-Variable RouteReal, RouteCalls -Scope Script -ErrorAction SilentlyContinue
Remove-Variable routeBig, routeSmall, routeSettings, routeCtx -ErrorAction SilentlyContinue
