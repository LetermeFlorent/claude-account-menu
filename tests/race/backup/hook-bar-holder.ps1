param([string]$State, [string]$Flag, [int]$HoldMs, [string]$Text = "")
$ErrorActionPreference = "Stop"
$lock = $State + ".lock"
$next = $State + ".holder"
if ($Text) { [IO.File]::WriteAllText($next, $Text, (New-Object Text.UTF8Encoding($false))) }
if ($PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows) {
  $fs = [IO.File]::Open($lock, "OpenOrCreate", "ReadWrite", "ReadWrite, Delete")
  $fs.Lock(0, 1)
  try {
    [IO.File]::WriteAllText($Flag, "x")
    Start-Sleep -Milliseconds $HoldMs
    if ($Text) { [IO.File]::Copy($next, $State, $true); [IO.File]::Delete($next) }
  } finally { $fs.Unlock(0, 1); $fs.Dispose() }
  exit 0
}
$secs = ($HoldMs / 1000.0).ToString([Globalization.CultureInfo]::InvariantCulture)
if (Get-Command flock -CommandType Application -ErrorAction SilentlyContinue) {
  & flock -x -w 30 $lock sh -c 'printf x > "$1"; sleep "$2"; if [ -f "$3" ]; then mv "$3" "$4"; fi' sh $Flag $secs $next $State
} else {
  & perl -e 'use Fcntl qw(:flock); open(my $f, ">>", $ARGV[0]) or exit 1; flock($f, LOCK_EX) or exit 1; open(my $g, ">", $ARGV[1]) or exit 1; print $g "x"; close $g; select(undef, undef, undef, $ARGV[2]); rename($ARGV[3], $ARGV[4]) if -e $ARGV[3]; exit 0' $lock $Flag $secs $next $State
}
exit $LASTEXITCODE
