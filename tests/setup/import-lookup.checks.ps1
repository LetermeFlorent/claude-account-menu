$lookupBin = Join-Path $script:Sandbox "lookup-bin"
[void](New-Item -ItemType Directory -Path (Join-Path $lookupBin "drive\watch") -Force)
Copy-Item -LiteralPath (Join-Path $bin "claude-import.ps1") -Destination $lookupBin
[void](New-SandboxFile "lookup-bin\claude-lookup-root.ps1" 'function Get-LookupRoot { "reste a plat" }')
[void](New-SandboxFile "lookup-bin\drive\watch\claude-lookup-deep.ps1" 'function Get-LookupDeep { "profond" }')
[void](New-SandboxFile "lookup-bin\drive\claude-lookup-root.ps1" 'function Get-LookupRoot { "dossier" }')
[void](New-SandboxFile "lookup-bin\claude-lookup-entry.ps1" 'function Get-LookupEntry { "racine" }')
[void](New-SandboxFile "lookup-bin\user-tools\claude-lookup-user.ps1" 'function Get-LookupUser { "utilisateur" }')
$lookupScript = @'
param($Bin)
. (Join-Path $Bin "claude-import.ps1")
$script:ClmModuleFolders = @("drive", "drive/watch", "missing")
. Import-ClmModule claude-lookup-root, claude-lookup-deep, claude-lookup-entry
$late = Join-Path $Bin "drive\claude-lookup-late.ps1"
[IO.File]::WriteAllText($late, 'function Get-LookupLate { "tard" }')
foreach ($name in @("claude-lookup-late", "claude-lookup-user")) { try { . Import-ClmModule $name } catch { } }
$leak = @(Get-Variable | Where-Object { $_.Name -like "ClmImport*" }).Count
@((Get-LookupRoot), (Get-LookupDeep), (Get-LookupEntry), [bool](Get-Command Get-LookupLate -ErrorAction Ignore), [bool](Get-Command Get-LookupUser -ErrorAction Ignore), $leak) -join ","
'@
$ps = [PowerShell]::Create()
try {
  [void]$ps.AddScript($lookupScript).AddArgument($lookupBin)
  $got = (@($ps.Invoke()) -join "") + (@($ps.Streams.Error | ForEach-Object { " " + $_.ToString() }) -join "")
} finally { $ps.Dispose() }
Assert-Equal "dossier,profond,racine,False,False,0" $got "recherche des modules : un module se charge par son nom dans un dossier de clm, un dossier passe avant un reste a plat, la racine sert encore, la table se lit une fois, un dossier de l'utilisateur est ignore"
