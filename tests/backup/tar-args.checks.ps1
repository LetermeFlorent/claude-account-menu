. (Join-Path $bin "claude-menu-archive.ps1")
. (Join-Path $bin "claude-menu-save.ps1")
$argCases = [ordered]@{ "abc" = "abc"; "a b" = '"a b"'; "" = '""'; 'a"b' = '"a\"b"'; 'a\b' = 'a\b'; 'a\"b' = '"a\\\"b"'; 'C:\x y\' = '"C:\x y\\"'; 'a\\' = 'a\\'; "a`tb" = "`"a`tb`"" }
foreach ($k in $argCases.Keys) { Assert-Equal $argCases[$k] (ConvertTo-ProcessArgument $k) ("argument de processus echappe : [" + $k + "]") }
Assert-Equal 'a "b c" ""' (ConvertTo-ProcessCommandLine @("a", "b c", "")) "ligne de commande : arguments joints"

if ($script:OsName -eq "Windows") {
  if (-not ("ClmArgvProbe" -as [type])) {
    Add-Type -Namespace "" -Name "ClmArgvProbe" -MemberDefinition '[System.Runtime.InteropServices.DllImport("shell32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)] public static extern System.IntPtr CommandLineToArgvW(string line, out int count); [System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern System.IntPtr LocalFree(System.IntPtr p); public static string[] Split(string line) { int n; System.IntPtr p = CommandLineToArgvW(line, out n); string[] r = new string[n]; for (int i = 0; i < n; i++) { r[i] = System.Runtime.InteropServices.Marshal.PtrToStringUni(System.Runtime.InteropServices.Marshal.ReadIntPtr(p, i * System.IntPtr.Size)); } LocalFree(p); return r; }'
  }
  $argv = @("prog") + @($argCases.Keys) + @('\\srv\a b\', '"', '\"\', 'x y z')
  $back = [ClmArgvProbe]::Split("prog " + (ConvertTo-ProcessCommandLine @($argv | Select-Object -Skip 1)))
  Assert-Equal ($argv -join "|") ($back -join "|") "ligne de commande : relue a l'identique par Windows"
}

$tarHome = Join-Path $script:Sandbox "tar args"
$null = New-SandboxFile "tar args/sous dossier/a.txt" "a"
$null = New-SandboxFile "tar args/.claude-a b/x.txt" "x"
$null = New-SandboxFile "tar args/.claude/y.txt" "y"
Initialize-Tar
$tarZip = Join-Path $script:Sandbox ("tar args" + (Get-ArchiveExtension $script:TarFlavor))
$script:Sizes = @{}
$null = Invoke-Tar @("-a", "-c", "-f", $tarZip, "-C", $tarHome, "--exclude", 'q"z', "sous dossier", ".claude-a b", ".claude") 3 "test"
$tarNames = @(& $script:Tar -tf $tarZip)
Assert-True ($tarNames -contains "sous dossier/a.txt") "tar : chemin avec espace et motif avec guillemet passes intacts"
Assert-Equal ".claude" ((@(Get-ZipAccounts $tarZip) | ForEach-Object { $_.Dir }) -join "|") "archive : dossier de compte refuse ignore"
Assert-Throws { Restore-Accounts $tarZip @([PSCustomObject]@{ Label = "x"; Dir = ".claude-a b" }) 3>$null } "aucun compte" "restauration : dossier de compte refuse"
Remove-Item -LiteralPath $tarHome, $tarZip -Recurse -Force
