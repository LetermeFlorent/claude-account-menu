function New-TarLogReader {
  param([string]$Path)
  return @{ Path = $Path; Offset = [long]0; BytesRead = [long]0; Pending = [byte[]]@() }
}

function Read-TarLogLines {
  param($Reader)
  if (-not (Test-Path -LiteralPath $Reader.Path)) { return @() }
  try {
    $fs = [IO.File]::Open($Reader.Path, "Open", "Read", "ReadWrite")
    try {
      $want = [int]($fs.Length - $Reader.Offset)
      if ($want -lt 0) { $want = 0 }
      [void]$fs.Seek($Reader.Offset, "Begin")
      $chunk = New-Object byte[] $want
      $got = 0
      while ($got -lt $want) {
        $n = $fs.Read($chunk, $got, $want - $got)
        if ($n -le 0) { break }
        $got += $n
      }
    } finally { $fs.Close() }
  } catch { return @() }
  $Reader.Offset += $got
  $Reader.BytesRead += $got
  $data = New-Object byte[] ($Reader.Pending.Length + $got)
  [Array]::Copy($Reader.Pending, 0, $data, 0, $Reader.Pending.Length)
  [Array]::Copy($chunk, 0, $data, $Reader.Pending.Length, $got)
  $cut = [Array]::LastIndexOf($data, [byte]10)
  if ($cut -lt 0) { $Reader.Pending = $data; return @() }
  $rest = New-Object byte[] ($data.Length - $cut - 1)
  [Array]::Copy($data, $cut + 1, $rest, 0, $rest.Length)
  $Reader.Pending = $rest
  $text = (New-Object Text.UTF8Encoding($false)).GetString($data, 0, $cut + 1)
  return @($text -split "`r?`n" | Where-Object { $_ -ne "" })
}
