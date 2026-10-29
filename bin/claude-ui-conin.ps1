$script:ConInSource = @'
using System;
using System.Runtime.InteropServices;

public static class ClmConIn {
  [StructLayout(LayoutKind.Explicit, Size = 20)]
  struct Rec {
    [FieldOffset(0)] public ushort Type;
    [FieldOffset(4)] public int KeyDown;
    [FieldOffset(10)] public ushort Vk;
    [FieldOffset(14)] public ushort Ch;
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
  [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);

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

  public static bool IsDown(int vk) {
    return (GetAsyncKeyState(vk) & 0x8000) != 0;
  }

  static bool IsModifier(ushort v) {
    return v == 0x10 || v == 0x11 || v == 0x12 || v == 0x14 || v == 0x5B || v == 0x5C || v == 0x90 || v == 0x91;
  }

  static bool Counts(Rec e) {
    if (e.Type == 1) { return e.KeyDown != 0 && !IsModifier(e.Vk); }
    return e.Type == 2 && e.Flags != 1;
  }

  public static bool Pending() {
    Rec[] r = new Rec[64];
    uint n;
    if (!PeekConsoleInput(In, r, 64, out n)) { return false; }
    for (int i = 0; i < (int)n; i++) { if (Counts(r[i])) { return true; } }
    return n == 64;
  }

  public static int[] Next() {
    Rec[] r = new Rec[1];
    uint n;
    while (GetNumberOfConsoleInputEvents(In, out n) && n > 0) {
      if (!PeekConsoleInput(In, r, 1, out n) || n == 0) { return null; }
      if (r[0].Type == 1 && r[0].KeyDown != 0 && !IsModifier(r[0].Vk)) { return new int[] { 1 }; }
      if (!ReadConsoleInput(In, r, 1, out n) || n == 0) { return null; }
      if (r[0].Type == 1 && !IsModifier(r[0].Vk)) { return new int[] { 3, r[0].Vk, r[0].Ch }; }
      if (r[0].Type != 2) { continue; }
      if (r[0].Flags == 4) { return new int[] { 2, r[0].X, r[0].Y, 3, (short)(r[0].Buttons >> 16) }; }
      if (r[0].Flags == 2 && (r[0].Buttons & 1) != 0) { return new int[] { 2, r[0].X, r[0].Y, 2, 0 }; }
      if (r[0].Flags == 0 && (r[0].Buttons & 1) != 0) { return new int[] { 2, r[0].X, r[0].Y, 1, 0 }; }
    }
    return null;
  }
}
'@
$script:EnterKeyCodes = @(13) + @(49..57) + @(97..105)

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

function Get-HeldKeys {
  if ($script:MouseMode -lt 0 -or $env:SSH_CONNECTION -or $env:SSH_CLIENT) { return @(13) }
  try { return @($script:EnterKeyCodes | Where-Object { [ClmConIn]::IsDown($_) }) } catch { return @(13) }
}

function Test-ConsoleInputPending {
  try {
    if ($script:MouseMode -ge 0) { return [ClmConIn]::Pending() }
    return [Console]::KeyAvailable
  } catch { return $false }
}
