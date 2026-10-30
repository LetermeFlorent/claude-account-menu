. (Join-Path $bin "claude-drive-api.ps1")

class HdrFakeFailure : Exception {
  $Response
  HdrFakeFailure([string]$Message, $Response) : base($Message) { $this.Response = $Response }
}

function New-HdrFailure {
  param([int]$Status, $Headers = @{}, [string]$Body = "")
  $stream = New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes($Body))
  $response = [PSCustomObject]@{ StatusCode = $Status; Headers = $Headers; Stream = $stream }
  $response | Add-Member -MemberType ScriptMethod -Name GetResponseStream -Value { return $this.Stream }
  return @{ Failure = [HdrFakeFailure]::new("Le serveur distant a retourne une erreur : (" + $Status + ")", $response) }
}

$script:HdrSavedToken = ${function:Get-DriveToken}
$script:HdrSavedWeb = ${function:Invoke-DriveWeb}
$script:HdrSavedSleep = $script:DriveRetrySleep
$script:HdrSavedJitter = $script:DriveRetryJitter
$script:HdrSavedMax = $script:DriveRetryMax

$script:HdrQueue = New-Object 'System.Collections.Generic.Queue[object]'
$script:HdrCalls = 0
$script:HdrSlept = New-Object 'System.Collections.Generic.List[int]'
function Get-DriveToken { param([switch]$Renew) return "tok" }
function Invoke-DriveWeb {
  param($Request)
  $script:HdrCalls++
  $item = $script:HdrQueue.Dequeue()
  if ($item -is [hashtable]) { throw $item.Failure }
  return $item
}
function Reset-HdrFakes {
  $script:HdrQueue.Clear()
  $script:HdrCalls = 0
  $script:HdrSlept.Clear()
  $script:DriveRetryMax = 5
  $script:DriveRetrySleep = { param([int]$Ms) $script:HdrSlept.Add($Ms) }
  $script:DriveRetryJitter = { param([int]$Ms) return 0 }
}
function Get-HdrError {
  param([scriptblock]$Action)
  try { $null = & $Action } catch { return $_.Exception.Message }
  return ""
}
function Add-HdrFailures {
  param([int]$Count, [int]$Status, $Headers = @{})
  foreach ($i in 1..$Count) { $script:HdrQueue.Enqueue((New-HdrFailure $Status $Headers)) }
}

Reset-HdrFakes
Add-HdrFailures 1 429
$script:HdrQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "429 sans Retry-After : la requete aboutit"
Assert-Equal 2 $script:HdrCalls "429 sans Retry-After : deux appels"
Assert-Equal "500" ($script:HdrSlept -join ",") "429 sans Retry-After : attente du recul de base"

Reset-HdrFakes
Add-HdrFailures 1 500 @{ "Retry-After" = "2" }
$script:HdrQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "500 avec Retry-After : la requete aboutit"
Assert-Equal "2000" ($script:HdrSlept -join ",") "500 avec Retry-After : l'en-tete est respecte"

Reset-HdrFakes
Add-HdrFailures 1 503 @{ "Retry-After" = "2" }
$script:HdrQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "503 avec Retry-After : la requete aboutit"
Assert-Equal "2000" ($script:HdrSlept -join ",") "503 avec Retry-After : l'en-tete est respecte"

Reset-HdrFakes
$script:DriveRetryMax = 3
Add-HdrFailures 6 429
$msg = Get-HdrError { Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" } }
Assert-Equal 4 $script:HdrCalls "429 durable : un essai et trois reprises"
Assert-Equal "500,1000,2000" ($script:HdrSlept -join ",") "429 durable : une attente par reprise"
Assert-True ($msg.Contains("(429)")) ("429 durable : l'erreur finale remonte, " + $msg)
Assert-Equal 2 $script:HdrQueue.Count "429 durable : aucun appel au dela de la limite"

Reset-HdrFakes
$script:DriveRetryMax = 3
Add-HdrFailures 6 500
$msg = Get-HdrError { Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" } }
Assert-Equal 4 $script:HdrCalls "500 durable : un essai et trois reprises"
Assert-Equal "500,1000,2000" ($script:HdrSlept -join ",") "500 durable : une attente par reprise"
Assert-True ($msg.Contains("(500)")) ("500 durable : l'erreur finale remonte, " + $msg)

Reset-HdrFakes
$script:DriveRetryMax = 0
Add-HdrFailures 2 429
$msg = Get-HdrError { Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" } }
Assert-Equal 1 $script:HdrCalls "limite zero : un seul appel"
Assert-Equal 0 $script:HdrSlept.Count "limite zero : aucune attente"
Assert-True ($msg.Contains("(429)")) ("limite zero : erreur remontee, " + $msg)

Reset-HdrFakes
Add-HdrFailures 1 429 @{ "Retry-After" = "0" }
$script:HdrQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "Retry-After 0 : la requete aboutit"
Assert-Equal "500" ($script:HdrSlept -join ",") "Retry-After 0 : le recul de base s'applique"

Reset-HdrFakes
Add-HdrFailures 1 429 @{ "Retry-After" = "bientot" }
$script:HdrQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "Retry-After illisible : la requete aboutit"
Assert-Equal 2 $script:HdrCalls "Retry-After illisible : deux appels"
Assert-Equal "500" ($script:HdrSlept -join ",") "Retry-After illisible : retour au recul"

Reset-HdrFakes
Add-HdrFailures 1 503 @{ "Retry-After" = "-5" }
$script:HdrQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "Retry-After negatif : la requete aboutit"
Assert-Equal "500" ($script:HdrSlept -join ",") "Retry-After negatif : recul de base, pas d'attente negative"

Reset-HdrFakes
Add-HdrFailures 2 500 @{ "Retry-After" = "2" }
$script:HdrQueue.Enqueue("ok")
$null = Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }
Assert-Equal "2000,2000" ($script:HdrSlept -join ",") "Retry-After repete : le recul plus court ne l'emporte pas"

Reset-HdrFakes
Add-HdrFailures 3 429 @{ "Retry-After" = "1" }
$script:HdrQueue.Enqueue("ok")
$null = Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }
Assert-Equal "1000,1000,2000" ($script:HdrSlept -join ",") "Retry-After 1 : le recul doubleur reprend le dessus"

${function:Get-DriveToken} = $script:HdrSavedToken
${function:Invoke-DriveWeb} = $script:HdrSavedWeb
$script:DriveRetrySleep = $script:HdrSavedSleep
$script:DriveRetryJitter = $script:HdrSavedJitter
$script:DriveRetryMax = $script:HdrSavedMax
Remove-Item Function:\Reset-HdrFakes, Function:\Get-HdrError, Function:\Add-HdrFailures, Function:\New-HdrFailure
