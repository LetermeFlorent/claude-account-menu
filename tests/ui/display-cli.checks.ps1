. (Join-Path $bin "claude-menu-rename.ps1")
. (Join-Path $bin "claude-menu-remove.ps1")
. (Join-Path $bin "claude-cli.ps1")

function Invoke-DisplayCli {
  param([object[]]$ArgList)
  $lines = @(Invoke-CliCommand (Get-CliCommand $ArgList) $ArgList 6>&1 | ForEach-Object { "" + $_ })
  return @{ Code = $lines[-1]; Text = (@($lines | Select-Object -First ($lines.Count - 1)) -join "|") }
}

$dcPath = Get-DisplayPath
try {
  Remove-Item -LiteralPath $dcPath -Force -ErrorAction SilentlyContinue
  $r = Invoke-DisplayCli @("--palette", "light")
  Assert-Equal "0 affichage de ce PC : couleurs light, animations auto" ($r.Code + " " + $r.Text) "cli affichage : couleurs claires"
  $r = Invoke-DisplayCli @("--anim", "off")
  Assert-Equal "0 affichage de ce PC : couleurs light, animations off" ($r.Code + " " + $r.Text) "cli affichage : animations coupees, couleurs gardees"
  $r = Invoke-DisplayCli @("--palette", "sombre")
  Assert-Equal "dark off" ((Read-DisplayConfig).palette + " " + (Read-DisplayConfig).anim) "cli affichage : nom francais accepte"
  $r = Invoke-DisplayCli @("--palette", "rouge")
  Assert-True ($r.Code -eq "1" -and $r.Text -like ((Get-ClmText "ui.display.badPalette" "rouge").Split(",")[0] + "*")) "cli affichage : couleur inconnue refusee"
  $r = Invoke-DisplayCli @("--anim")
  Assert-Equal "1 --anim attend auto, on ou off" ($r.Code + " " + $r.Text) "cli affichage : valeur manquante"
  $r = Invoke-DisplayCli @("--palette", "dark", "light")
  Assert-Equal "1 --palette attend auto, dark ou light" ($r.Code + " " + $r.Text) "cli affichage : deux valeurs refusees"
  Assert-Equal "dark off" ((Read-DisplayConfig).palette + " " + (Read-DisplayConfig).anim) "cli affichage : refus sans rien changer"
  try {
    $env:CLM_ANIM = "1"
    $r = Invoke-DisplayCli @("--anim", "auto")
    Assert-Equal "0|CLM_ANIM est definie et passe avant ce reglage" ($r.Code + "|" + ($r.Text -split "\|")[1]) "cli affichage : variable signalee"
    $env:STATUSLINE_BG = "clair"
    Assert-Equal "STATUSLINE_BG est definie et passe avant ce reglage" ((Invoke-DisplayCli @("--palette", "auto")).Text -split "\|")[1] "cli affichage : palette fixee par variable"
  } finally { Remove-Item Env:CLM_ANIM, Env:STATUSLINE_BG -ErrorAction SilentlyContinue }
  Assert-Equal 1 @((Invoke-DisplayCli @("--palette", "dark")).Text -split "\|").Count "cli affichage : sans variable, pas d'avertissement"
} finally { Remove-Item -LiteralPath $dcPath -Force -ErrorAction SilentlyContinue }
