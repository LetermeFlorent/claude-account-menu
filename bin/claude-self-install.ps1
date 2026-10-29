. Import-ClmModule claude-platform, claude-self-version
$script:ClmBadHashText = "empreinte du paquet clm invalide, installation refusee"

function New-ClmPrivateDir {
  $dir = Join-Path ([IO.Path]::GetTempPath()) ("clm-update-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $dir | Out-Null
  if ($script:OsName -ne "Windows") {
    & /bin/chmod 700 $dir
    if ($LASTEXITCODE -ne 0) { throw "dossier temporaire impossible a proteger" }
    return $dir
  }
  $acl = New-Object Security.AccessControl.DirectorySecurity
  $acl.SetAccessRuleProtection($true, $false)
  $me = [Security.Principal.WindowsIdentity]::GetCurrent().User
  $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($me, "FullControl", "ContainerInherit, ObjectInherit", "None", "Allow")))
  Set-Acl -LiteralPath $dir -AclObject $acl
  return $dir
}

function Get-ClmAssetUrl {
  param($Version)
  $tag = "v" + [int]$Version.Number
  return "https://github.com/" + $script:ClmRepo + "/releases/download/" + $tag + "/clm-" + $tag + ".zip"
}

function Read-ClmSum {
  param([string]$Path)
  $text = [IO.File]::ReadAllText($Path)
  if ($text -notmatch "^\s*([0-9A-Fa-f]{64})(\s|$)") { throw $script:ClmBadHashText }
  return $Matches[1]
}

function Assert-ClmHash {
  param([string]$Zip, [string]$Sum)
  $expected = Read-ClmSum $Sum
  $actual = (Get-FileHash -LiteralPath $Zip -Algorithm SHA256).Hash
  if ($actual -ne $expected) { throw $script:ClmBadHashText }
}

function Get-ClmInstallerCommand {
  param([string]$Src, [string]$Os = $script:OsName)
  if ($Os -eq "Windows") {
    $exe = $env:SystemRoot + "\System32\WindowsPowerShell\v1.0\powershell.exe"
    return @{ Exe = $exe; Arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", [IO.Path]::Combine($Src, "install.ps1")) }
  }
  return @{ Exe = "/bin/sh"; Arguments = @([IO.Path]::Combine($Src, "install.sh")) }
}

function Invoke-ClmProcess {
  param([string]$Exe, [string[]]$Arguments)
  $out = & $Exe @Arguments 2>&1
  return @{ Code = $LASTEXITCODE; Last = ("" + (@($out) | Select-Object -Last 1)) }
}

function Invoke-ClmInstaller {
  param([string]$Src)
  $cmd = Get-ClmInstallerCommand $Src
  $saved = $env:CLM_PWSH
  $env:CLM_PWSH = (Get-Process -Id $PID).Path
  try { $r = Invoke-ClmProcess $cmd.Exe $cmd.Arguments } finally { $env:CLM_PWSH = $saved }
  if ($r.Code -ne 0) { throw ("installeur en echec : " + $r.Last) }
}

function Install-ClmVersion {
  param($Version)
  $tmp = New-ClmPrivateDir
  try {
    $url = Get-ClmAssetUrl $Version
    $zip = Join-Path $tmp "clm.zip"
    $sum = Join-Path $tmp "clm.zip.sha256"
    $null = Invoke-GitHubGet ($url + ".sha256") 10 $sum
    $null = Invoke-GitHubGet $url 60 $zip
    Assert-ClmHash $zip $sum
    $src = Join-Path $tmp "pkg"
    Expand-Archive -LiteralPath $zip -DestinationPath $src
    Invoke-ClmInstaller $src
  } finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}
