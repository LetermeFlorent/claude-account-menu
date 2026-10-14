$script:MouseMode = -1
$script:ConInSource = @'
using System;
using System.Runtime.InteropServices;

public static class ClmConIn {
  [StructLayout(LayoutKind.Explicit, Size = 20)]
  struct Rec {
    [FieldOffset(0)] public ushort Type;
    [FieldOffset(4)] public int KeyDown;
    [FieldOffset(10)] public ushort Vk;
    [FieldOffset(4)] public short X;
    [FieldOffset(6)] public short Y;
    [FieldOffset(8)] public uint Buttons;
    [FieldOffset(16)] public uint Flags;
  }

  [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
  [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
  [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
  [DllImport("kernel32.dll")] static extern bool GetNumberOfConsoleInputEvents(IntPtr h, out uint n);
  [DllImport("kernel32.dll", EntryPoint = "PeekConsoleInputW")] static extern bool PeekConsoleInput(IntPtr h, [Out] Rec[] r, uint len, out uint read);
  [DllImport("kernel32.dll", EntryPoint = "ReadConsoleInputW")] static extern bool ReadConsoleInput(IntPtr h, [Out] Rec[] r, uint len, out uint read);

  static IntPtr In { get { return GetStdHandle(-10); } }

  public static long Enable() {
    uint m;
    if (!GetConsoleMode(In, out m)) { return -1; }
    if (!SetConsoleMode(In, (m | 0x90u) & ~0x40u)) { return -1; }
    return m;
  }

  public static void Restore(long m) {
    if (m >= 0) { SetConsoleMode(In, (uint)m); }
  }

  static bool IsModifier(ushort v) {
    return v == 0x10 || v == 0x11 || v == 0x12 || v == 0x14 || v == 0x5B || v == 0x5C || v == 0x90 || v == 0x91;
  }

  public static int[] Next() {
    Rec[] r = new Rec[1];
    uint n;
    while (GetNumberOfConsoleInputEvents(In, out n) && n > 0) {
      if (!PeekConsoleInput(In, r, 1, out n) || n == 0) { return null; }
      if (r[0].Type == 1 && r[0].KeyDown != 0 && !IsModifier(r[0].Vk)) { return new int[] { 1 }; }
      if (!ReadConsoleInput(In, r, 1, out n) || n == 0) { return null; }
      if (r[0].Type != 2) { continue; }
      if (r[0].Flags == 4) { return new int[] { 2, r[0].X, r[0].Y, 3, (short)(r[0].Buttons >> 16) }; }
      if (r[0].Flags == 2 && (r[0].Buttons & 1) != 0) { return new int[] { 2, r[0].X, r[0].Y, 2, 0 }; }
      if (r[0].Flags == 0 && (r[0].Buttons & 1) != 0) { return new int[] { 2, r[0].X, r[0].Y, 1, 0 }; }
    }
    return null;
  }
}
'@

function Initialize-ConIn {
  if ("ClmConIn" -as [type]) { return $true }
  try {
    $sha = [Security.Cryptography.SHA1]::Create()
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($script:ConInSource))).Replace("-", "").Substring(0, 8)
    $dir = Split-Path (Get-UsageCachePath)
    $dll = Join-Path $dir ("clm-conin-" + $hash + ".dll")
    if (-not (Test-Path -LiteralPath $dll)) {
      if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
      Add-Type -TypeDefinition $script:ConInSource -OutputAssembly $dll -OutputType Library
    }
    if (-not ("ClmConIn" -as [type])) { Add-Type -Path $dll }
    return [bool]("ClmConIn" -as [type])
  } catch { return $false }
}

function Enable-UiMouse {
  if ($script:OsName -ne "Windows" -or $script:MouseMode -ge 0 -or -not (Test-RichTerminal)) { return }
  if (-not (Initialize-ConIn)) { return }
  try { $script:MouseMode = [ClmConIn]::Enable() } catch { $script:MouseMode = -1 }
}

function Disable-UiMouse {
  if ($script:MouseMode -lt 0) { return }
  try { [ClmConIn]::Restore($script:MouseMode) } catch {}
  $script:MouseMode = -1
}

function New-KeyInfo {
  param([string]$Name)
  if ($Name -match "^Entree") { return New-Object System.ConsoleKeyInfo ([char]13), ([ConsoleKey]::Enter), $false, $false, $false }
  if ($Name -eq "Espace") { return New-Object System.ConsoleKeyInfo ([char]32), ([ConsoleKey]::Spacebar), $false, $false, $false }
  if ($Name -eq "Echap" -or $Name -eq "autre touche") { return New-Object System.ConsoleKeyInfo ([char]27), ([ConsoleKey]::Escape), $false, $false, $false }
  if ($Name -eq "up") { return New-Object System.ConsoleKeyInfo ([char]0), ([ConsoleKey]::UpArrow), $false, $false, $false }
  if ($Name -eq "down") { return New-Object System.ConsoleKeyInfo ([char]0), ([ConsoleKey]::DownArrow), $false, $false, $false }
  if ($Name.Length -ne 1) { return $null }
  $c = $Name[0]
  return New-Object System.ConsoleKeyInfo $c, ([ConsoleKey][int][char]::ToUpperInvariant($c)), $false, $false, $false
}

function Get-FooterKeyAt {
  param($Rows, [int]$X, [int]$Y)
  if ($null -eq $Rows -or $Y -lt 0 -or $Y -ge $Rows.Count) { return $null }
  $pos = 0
  foreach ($s in $Rows[$Y]) {
    $len = ([string]$s[0]).Length
    if ($X -ge $pos -and $X -lt $pos + $len) {
      if ($s.Count -gt 3) { return $s[3] }
      return $null
    }
    $pos += $len
  }
  return $null
}

function ConvertFrom-MouseEvent {
  param([int[]]$Ev, $Rows, [int]$Top = 0)
  $x = $Ev[1]
  $y = $Ev[2] - $Top
  if ($Ev[3] -eq 3) {
    if ($Ev[4] -gt 0) { return New-KeyInfo "up" }
    return New-KeyInfo "down"
  }
  $name = Get-FooterKeyAt $Rows $x $y
  if ($name) {
    if ($Ev[3] -eq 2) { return $null }
    return New-KeyInfo $name
  }
  $kind = "click"
  if ($Ev[3] -eq 2) { $kind = "double" }
  return @{ Mouse = $kind; X = $x; Y = $y }
}

function Read-UiInput {
  if ($script:MouseMode -lt 0) {
    if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) }
    return $null
  }
  while ($true) {
    $ev = [ClmConIn]::Next()
    if ($null -eq $ev) { return $null }
    if ($ev[0] -eq 1) {
      if ([Console]::KeyAvailable) { return [Console]::ReadKey($true) }
      return $null
    }
    $top = 0
    try { $top = [Console]::WindowTop } catch {}
    $m = ConvertFrom-MouseEvent $ev $script:LastRows $top
    if ($null -ne $m) { return $m }
  }
}
