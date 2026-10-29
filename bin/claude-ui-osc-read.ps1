$script:OscQuery = [string][char]27 + "]11;?" + [char]27 + "\" + [char]27 + "[c"
$script:DaReplyPattern = "\?[\d;]*c"
$script:ReplyDrainMax = 256
$script:TtySaveScript = 'exec 2>/dev/null; exec </dev/tty || exit 0; stty -g'
$script:TtyRestoreScript = 'exec 2>/dev/null; exec </dev/tty || exit 0; stty "$1"'
$script:TtyScript = @'
exec 2>/dev/null
exec </dev/tty || exit 0
query=$1
old=$2
trap 'stty "$old"' EXIT
trap 'exit 1' HUP INT TERM
got=
ready=0
grab() {
  chunk=$(dd bs=256 count=1 2>/dev/null | od -An -v -tx1)
  got="$got $chunk"
  set -- $got
  case " $* " in *" 1b 5b 3f "*" 63 "*) ready=1 ;; esac
}
stty raw -echo min 0 time 1 || exit 0
printf '%s' "$query" >/dev/tty || exit 0
grab
if [ "$ready" = 0 ]; then
  stty min 0 time 0
  for pass in 1 2 3; do
    sleep 0.05 || :
    grab
    if [ "$ready" = 1 ] || [ -z "$chunk" ]; then break; fi
  done
fi
set -- $got
printf '%s' "$*"
'@

function Get-TtyScript {
  return $script:TtyScript.Replace("`r", "")
}

function Read-ReplyText {
  param([scriptblock]$TestKey, [scriptblock]$ReadKey, [scriptblock]$Clock, [int]$LimitMs = 100, [int]$QuietMs = 50, [int]$MaxMs = 250)
  $text = New-Object Text.StringBuilder
  $last = $LimitMs
  try {
    while ($text.Length -lt $script:ReplyDrainMax) {
      $now = & $Clock
      if ($now -ge $MaxMs -or $now - $last -ge $QuietMs) { break }
      if (-not (& $TestKey)) {
        Start-Sleep -Milliseconds 5
        continue
      }
      [void]$text.Append([string](& $ReadKey))
      if ($text.ToString() -match $script:DaReplyPattern) { break }
      $last = [math]::Max($now, $LimitMs)
    }
  } catch { Write-Verbose $_.Exception.Message }
  return $text.ToString()
}

function Read-ConsoleKeyChar {
  $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp")
  if ($k.KeyDown -and [int]$k.Character -ne 0) { return [string]$k.Character }
  return ""
}

function Read-ConsoleReply {
  try {
    [Console]::Out.Write($script:OscQuery)
    [Console]::Out.Flush()
  } catch {
    Write-Verbose $_.Exception.Message
    return ""
  }
  $watch = [Diagnostics.Stopwatch]::StartNew()
  $clock = { $watch.ElapsedMilliseconds }.GetNewClosure()
  return Read-ReplyText -TestKey { $Host.UI.RawUI.KeyAvailable } -ReadKey ${function:Read-ConsoleKeyChar} -Clock $clock
}

function ConvertFrom-ByteHex {
  param([string]$Hex)
  $text = New-Object Text.StringBuilder
  foreach ($h in ("" + $Hex).Split([char[]]" `t`r`n", [StringSplitOptions]::RemoveEmptyEntries)) {
    if ($h -notmatch "^[0-9a-fA-F]{2}$") { return "" }
    [void]$text.Append([char][Convert]::ToByte($h, 16))
  }
  return $text.ToString()
}

function Invoke-TtyShell {
  param([string]$Script, [string[]]$Arguments, [int]$LimitMs)
  $psi = New-Object Diagnostics.ProcessStartInfo
  if ($null -eq $psi.PSObject.Properties["ArgumentList"]) { return $null }
  $psi.FileName = "/bin/sh"
  foreach ($a in @("-c", $Script, "clm-osc") + @($Arguments)) { $psi.ArgumentList.Add($a) }
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  try { $p = [Diagnostics.Process]::Start($psi) } catch { return $null }
  try {
    $out = $p.StandardOutput.ReadToEndAsync()
    $null = $p.StandardError.ReadToEndAsync()
    if ($p.WaitForExit($LimitMs)) {
      $p.WaitForExit()
      return $out.Result
    }
    try { $p.Kill($true) } catch { Write-Verbose $_.Exception.Message }
    return $null
  } catch {
    Write-Verbose $_.Exception.Message
    return $null
  } finally { $p.Dispose() }
}

function Read-TtyReply {
  param([scriptblock]$Shell = $null, [int]$LimitMs = 500)
  if ($null -eq $Shell) { $Shell = ${function:Invoke-TtyShell} }
  $old = ("" + (& $Shell $script:TtySaveScript @() 200)).Trim()
  if ($old -eq "") { return "" }
  $hex = & $Shell (Get-TtyScript) @($script:OscQuery, $old) $LimitMs
  if ($null -eq $hex) {
    $null = & $Shell $script:TtyRestoreScript @($old) 200
    return ""
  }
  return ConvertFrom-ByteHex $hex
}
