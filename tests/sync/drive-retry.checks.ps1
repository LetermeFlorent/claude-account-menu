. (Join-Path $bin "claude-drive-api.ps1")

class FakeHttpFailure : Exception {
  $Response
  FakeHttpFailure([string]$Message, $Response) : base($Message) { $this.Response = $Response }
}

function New-FakeFailure {
  param([int]$Status, $Headers = @{}, [string]$Body = "")
  $stream = New-Object IO.MemoryStream(, [Text.Encoding]::UTF8.GetBytes($Body))
  $response = [PSCustomObject]@{ StatusCode = $Status; Headers = $Headers; Stream = $stream }
  $response | Add-Member -MemberType ScriptMethod -Name GetResponseStream -Value { return $this.Stream }
  return @{ Failure = [FakeHttpFailure]::new("Le serveur distant a retourne une erreur : (" + $Status + ")", $response) }
}

$script:WebQueue = New-Object 'System.Collections.Generic.Queue[object]'
$script:WebCalls = 0
$script:TokenRenews = @()
$script:Slept = New-Object 'System.Collections.Generic.List[int]'
function Get-DriveToken { param([switch]$Renew) $script:TokenRenews += [bool]$Renew; return "tok" }
function Invoke-DriveWeb {
  param($Request)
  $script:WebCalls++
  $item = $script:WebQueue.Dequeue()
  if ($item -is [hashtable]) { throw $item.Failure }
  return $item
}
function Reset-RetryFakes {
  $script:WebQueue.Clear()
  $script:WebCalls = 0
  $script:TokenRenews = @()
  $script:Slept.Clear()
  $script:DriveRetrySleep = { param([int]$Ms) $script:Slept.Add($Ms) }
  $script:DriveRetryJitter = { param([int]$Ms) return 0 }
}
function Get-RetryError {
  param([scriptblock]$Action)
  try { $null = & $Action } catch { return $_.Exception.Message }
  return ""
}

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 429 @{ "Retry-After" = "3" }))
$script:WebQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "429 : la requete repart et aboutit"
Assert-Equal 2 $script:WebCalls "429 : deux appels"
Assert-Equal "3000" ($script:Slept -join ",") "429 : attente du Retry-After"

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 503))
$script:WebQueue.Enqueue((New-FakeFailure 500))
$script:WebQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "5xx : la requete aboutit apres deux erreurs"
Assert-Equal "500,1000" ($script:Slept -join ",") "5xx : attente doublee a chaque essai"

Reset-RetryFakes
$script:DriveRetryJitter = { param([int]$Ms) return 120 }
$script:WebQueue.Enqueue((New-FakeFailure 502))
$script:WebQueue.Enqueue("ok")
$null = Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }
Assert-Equal "620" ($script:Slept -join ",") "5xx : alea ajoute a l'attente"

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 503 @{ "Retry-After" = "1" }))
$script:WebQueue.Enqueue("ok")
$null = Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }
Assert-Equal "1000" ($script:Slept -join ",") "Retry-After court : l'attente de 500 ms ne le raccourcit pas"
Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 503 @{ "Retry-After" = ([DateTime]::UtcNow.AddSeconds(8).ToString("r")) }))
$script:WebQueue.Enqueue("ok")
$null = Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }
Assert-True ($script:Slept[0] -ge 5000 -and $script:Slept[0] -le 9000) ("Retry-After en date : attente proche de 8 s, " + $script:Slept[0])

Reset-RetryFakes
$script:DriveRetryMax = 8
foreach ($i in 1..9) { $script:WebQueue.Enqueue((New-FakeFailure 500 @{} '{"error":{"code":500,"message":"Backend Error"}}')) }
$msg = Get-RetryError { Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" } }
Assert-Equal 9 $script:WebCalls "5xx durable : un essai et huit reprises"
Assert-Equal "500,1000,2000,4000,8000,16000,30000,30000" ($script:Slept -join ",") "5xx durable : attente plafonnee a 30 s"
Assert-True ($msg.Contains("(500)") -and $msg.Contains("Backend Error")) ("5xx durable : erreur avec le corps, " + $msg)
$script:DriveRetryMax = 5

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 403 @{} '{"error":{"errors":[{"reason":"userRateLimitExceeded"}]}}'))
$script:WebQueue.Enqueue((New-FakeFailure 403 @{} '{"error":{"errors":[{"reason":"rateLimitExceeded"}]}}'))
$script:WebQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "403 de quota : repris"
Assert-Equal 3 $script:WebCalls "403 de quota : trois appels"

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 403 @{} '{"error":{"errors":[{"reason":"insufficientFilePermissions"}],"message":"pas le droit"}}'))
$msg = Get-RetryError { Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" } }
Assert-Equal 1 $script:WebCalls "403 de droits : pas de reprise"
Assert-Equal 0 $script:Slept.Count "403 de droits : pas d'attente"
Assert-True ($msg.Contains("pas le droit")) ("403 de droits : corps garde, " + $msg)

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 404))
$null = Get-RetryError { Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" } }
Assert-Equal 1 $script:WebCalls "404 : pas de reprise"

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 429 @{ "Retry-After" = "3600" }))
$null = Get-RetryError { Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" } }
Assert-Equal 1 $script:WebCalls "Retry-After d'une heure : abandon sans attendre"
Assert-Equal 0 $script:Slept.Count "Retry-After d'une heure : aucune attente"

Reset-RetryFakes
$script:WebQueue.Enqueue((New-FakeFailure 401))
$script:WebQueue.Enqueue((New-FakeFailure 503))
$script:WebQueue.Enqueue("ok")
Assert-Equal "ok" (Invoke-DriveRequest @{ Method = "GET"; Uri = "https://x/y" }) "401 puis 503 : jeton renouvele puis reprise"
Assert-Equal "False,True,True" ($script:TokenRenews -join ",") "401 : jeton renouvele une fois, garde ensuite"

Remove-Item Function:\Get-DriveToken, Function:\Invoke-DriveWeb, Function:\Reset-RetryFakes, Function:\Get-RetryError, Function:\New-FakeFailure
. (Join-Path $bin "claude-drive-auth.ps1")
. (Join-Path $bin "claude-drive-api.ps1")
