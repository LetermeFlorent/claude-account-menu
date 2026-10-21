. (Join-Path $bin "claude-web-server.ps1")
. (Join-Path $bin "claude-web-actions.ps1")

$pgRoot = Join-Path $bin "clm-web"
$pgOnDisk = @(Get-ChildItem -LiteralPath $pgRoot -File | ForEach-Object { $_.Name } | Sort-Object)
Assert-Equal ((@($script:WebFiles) | Sort-Object) -join " ") ($pgOnDisk -join " ") "page web : fichiers servis, ni plus ni moins"

$pgHtml = [IO.File]::ReadAllText((Join-Path $pgRoot "index.html"))
$pgRefs = @([regex]::Matches($pgHtml, '(?:src|href)="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Where-Object { -not $_.StartsWith("data:") })
Assert-Equal "" (@($pgRefs | Where-Object { @($script:WebFiles) -notcontains $_ }) -join " ") "page web : liens vers des fichiers servis"
$pgScripts = @([regex]::Matches($pgHtml, '<script src="([^"]+)" defer></script>') | ForEach-Object { $_.Groups[1].Value })
$pgJs = @(@($script:WebFiles) | Where-Object { $_.EndsWith(".js") })
Assert-Equal (($pgJs | Sort-Object) -join " ") (($pgScripts | Sort-Object) -join " ") "page web : chaque script charge une fois"
Assert-Equal "api.js ui.js" (($pgScripts | Select-Object -First 2) -join " ") "page web : socle charge avant les sections"
Assert-True ($pgRefs -contains "style.css") "page web : feuille de style chargee"

$pgInline = @('<script(?![^>]*\bsrc=)', '<style', '\sstyle=', '\son[a-z]+=', '<form')
Assert-Equal "" (@($pgInline | Where-Object { $pgHtml -match $_ }) -join " ") "page web : rien d'inline, la politique de contenu bloquerait"

$pgCode = (@($pgJs | ForEach-Object { [IO.File]::ReadAllText((Join-Path $pgRoot $_)) }) -join "`n")
Assert-True ($pgCode -notmatch 'innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function') "page web : textes poses sans interpretation html"
$pgDo = @([regex]::Matches($pgCode, 'do: "([a-z-]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-Equal ((@($script:WebHandlers.Keys) | Sort-Object) -join " ") ($pgDo -join " ") "page web : chaque action de clm a son bouton, aucune inconnue"
$pgViews = @([regex]::Matches($pgCode, 'clmRead\("([a-z]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-Equal "backups prefs state" ($pgViews -join " ") "page web : vues lues"
$pgMenuWeb = [IO.File]::ReadAllText((Join-Path $bin "claude-menu-web.ps1"))
Assert-Equal "" (@($pgViews | Where-Object { $pgMenuWeb -notmatch ('\b' + $_ + ' = \{') }) -join " ") "page web : vues servies par le menu"
$pgIds = @([regex]::Matches($pgCode, 'byId\("([a-z-]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-Equal "" (@($pgIds | Where-Object { $pgHtml -notmatch ('id="' + $_ + '"') }) -join " ") "page web : elements cherches presents dans la page"
