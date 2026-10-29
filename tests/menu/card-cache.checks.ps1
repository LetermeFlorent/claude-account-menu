$cardKept = (Get-Item "function:Get-CardBody").ScriptBlock
$cardInk = $script:Ink

function New-CacheCard {
  param([string]$Label, $P5, $P7)
  $u = [PSCustomObject]@{ Label = $Label; Email = ($Label + "@exemple.fr"); Plan = "Max 5x"; Error = $null; Age = $null; Expired = $false; LimitedUntil = $null
    Pct5 = $P5; Reset5 = [DateTimeOffset]::Now.AddHours(2); Pct7 = $P7; Reset7 = [DateTimeOffset]::Now.AddDays(3) }
  $e = @{ U = $u; Pending = $false; Seen = $true; In = $null; View = $null; T5 = (New-Tween ([double]$P5) ([double]$P5) 0 0); T7 = (New-Tween ([double]$P7) ([double]$P7) 0 0) }
  Update-EntryView $e
  return $e
}

function Get-CacheFrame {
  param($State, $L, [double]$Now)
  $script:CardBuilds = 0
  $f = Get-MenuRows $State $L $Now
  $h = $State.Hit
  $cardRows = $f.Rows.GetRange($h.Start, ($h.Last - $h.Top) * $h.Per)
  return (@(foreach ($r in $cardRows) { @($r | ForEach-Object { $_[0] + ":" + ($_[1] -join ",") + ":" + [int][bool]$_[2] }) -join "" }) -join "`n")
}

try {
  $script:CacheClock = 0
  Set-Item -Path "function:Get-Date" -Value { $script:CacheClock++; return ("12:{0:D2}" -f ($script:CacheClock % 60)) }
  Set-Item -Path "function:Get-CardBody" -Value { $script:CardBuilds++; & $cardKept @args }
  $cards = @((New-CacheCard "perso" 20 40), (New-CacheCard "pro" 10 5), (New-CacheCard "test" 90 70))
  $st = @{ Entries = $cards; Sel = 1; SelTween = (New-Tween 1 1 0 0); Top = 0; Msg = @("  pret", $script:Ink.Dim); Moved = $false }
  $L = Get-MenuLayout 120 40 3
  $one = Get-CacheFrame $st $L 0
  Assert-Equal 3 $script:CardBuilds "cartes : trois construites au premier dessin"
  $two = Get-CacheFrame $st $L 0
  Assert-Equal 0 $script:CardBuilds "cartes immobiles : aucune reconstruite"
  Assert-Equal $one $two "cartes immobiles : meme image, repere compris"
  $cards[1].U.Email = "autre@exemple.fr"
  $three = Get-CacheFrame $st $L 0
  Assert-Equal 1 $script:CardBuilds "e-mail change : seule sa carte refaite"
  Assert-True ($three -match "autre@exemple\.fr") "e-mail change : nouvelle valeur affichee"
  $cards[2].T5 = New-Tween 90 50 400 1000
  $null = Get-CacheFrame $st $L 1100
  Assert-Equal 1 $script:CardBuilds "barre animee : seule sa carte refaite"
  $null = Get-CacheFrame $st $L 1200
  Assert-Equal 1 $script:CardBuilds "barre animee : refaite a chaque image"
  $null = Get-CacheFrame $st $L 2000
  $null = Get-CacheFrame $st $L 2100
  Assert-Equal 0 $script:CardBuilds "barre arrivee : plus rien a refaire"
  $cards[0].Timer = @("maj 30s", $script:Ink.Dim)
  $null = Get-CacheFrame $st $L 2200
  Assert-Equal 1 $script:CardBuilds "compteur change : sa carte refaite"
  $cards[0].Timer = @("maj 29s", $script:Ink.Dim)
  $null = Get-CacheFrame $st $L 2300
  Assert-Equal 1 $script:CardBuilds "compteur qui defile : sa carte refaite"
  $st.Sel = 0
  $st.SelTween = New-Tween 1 0 200 3000
  $null = Get-CacheFrame $st $L 3100
  Assert-Equal 2 $script:CardBuilds "selection qui glisse : les deux cartes concernees refaites"
  $script:Ink = $script:Palettes["light"]
  $null = Get-CacheFrame $st $L 4000
  Assert-Equal 3 $script:CardBuilds "theme change : toutes les cartes refaites"
  $cards[2].U.Error = ""
  $null = Get-CacheFrame $st $L 4050
  Assert-Equal 1 $script:CardBuilds "erreur vide : sa carte refaite"
  $cards[1].U.Pct5 = 60
  $cards[1].T5 = New-Tween 10 60 0 0
  Update-EntryView $cards[1]
  $fresh = Get-CacheFrame $st $L 4100
  Assert-Equal 1 $script:CardBuilds "nouvelle valeur lue : sa carte refaite"
  $cards[1].Remove("CardRows")
  Assert-Equal $fresh (Get-CacheFrame $st $L 4100) "nouvelle valeur lue : meme image que sans cache"
} finally {
  Remove-Item -Path "function:Get-Date"
  Set-Item -Path "function:Get-CardBody" -Value $cardKept
  $script:Ink = $cardInk
}
