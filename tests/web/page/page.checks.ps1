. (Join-Path $bin "web/server/claude-web-server.ps1")
. (Join-Path $bin "web/actions/claude-web-actions.ps1")

$pgRoot = Join-Path $bin "clm-web"
$pgFull = [IO.Path]::GetFullPath($pgRoot)
$pgOnDisk = @(Get-ChildItem -LiteralPath $pgRoot -Recurse -File | ForEach-Object { $_.FullName.Substring($pgFull.Length + 1).Replace("\", "/") })
$pgServed = @($script:WebPage.Keys | ForEach-Object { [string]$_ } | Sort-Object)
Assert-Equal ((@($pgOnDisk) + @("lang/en.json", "lang/fr.json") | Sort-Object) -join " ") ($pgServed -join " ") "page web : fichiers servis, ni plus ni moins"
$pgBig = @($pgOnDisk | Where-Object { @(Get-Content -LiteralPath (Join-Path $pgRoot $_)).Count -gt 150 })
Assert-Equal "" ($pgBig -join " ") "page web : fichiers de 150 lignes au plus"
$pgCrowded = @(@(Get-Item -LiteralPath $pgRoot) + @(Get-ChildItem -LiteralPath $pgRoot -Recurse -Directory) | Where-Object { @(Get-ChildItem -LiteralPath $_.FullName).Count -gt 8 } | ForEach-Object { $_.Name })
Assert-Equal "" ($pgCrowded -join " ") "page web : dossiers de 8 entrees au plus"

$pgHtml = Get-WebPageText $script:WebPage "index.html"
$pgRefs = @([regex]::Matches($pgHtml, '(?:src|href)="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Equal "" (@($pgRefs | Where-Object { -not $_.StartsWith("data:") -and $pgServed -notcontains $_ }) -join " ") "page web : liens vers des fichiers servis seulement"
$pgScripts = @([regex]::Matches($pgHtml, '<script src="([^"]+)" defer></script>') | ForEach-Object { $_.Groups[1].Value })
$pgJs = @($pgServed | Where-Object { $_.EndsWith(".js") })
Assert-Equal ($pgJs -join " ") (($pgScripts | Sort-Object) -join " ") "page web : chaque script charge une fois"
Assert-Equal "core/api.js core/dom.js" (($pgScripts | Select-Object -First 2) -join " ") "page web : socle charge avant les sections"
$pgCss = @([regex]::Matches($pgHtml, '<link rel="stylesheet" href="([^"]+)">') | ForEach-Object { $_.Groups[1].Value })
Assert-Equal (@($pgServed | Where-Object { $_.EndsWith(".css") }) -join " ") (($pgCss | Sort-Object) -join " ") "page web : chaque feuille de style chargee une fois"
Assert-Equal "css/tokens.css" @($pgCss)[0] "page web : palette chargee en premier"

$pgInline = @('<script(?![^>]*\bsrc=)', '<style', '\sstyle=', '\son[a-z]+=', '<form', 'javascript:')
Assert-Equal "" (@($pgInline | Where-Object { $pgHtml -match $_ }) -join " ") "page web : ni script ni style en ligne, la politique de contenu bloquerait"
$pgCode = (@($pgJs | ForEach-Object { Get-WebPageText $script:WebPage $_ }) -join "`n")
Assert-True ($pgCode -notmatch 'innerHTML|outerHTML|insertAdjacentHTML|document\.write|eval\(|new Function|setTimeout\("') "page web : textes poses sans interpretation html"
Assert-True ($pgCode -cnotmatch 'setAttribute\("style"|"style":|\bstyle: ') "page web : aucun attribut style pose par le code"
$pgStyles = (@($pgServed | Where-Object { $_.EndsWith(".css") } | ForEach-Object { Get-WebPageText $script:WebPage $_ }) -join "`n")
$pgAll = $pgHtml + "`n" + $pgCode + "`n" + $pgStyles
Assert-True ($pgAll -notmatch 'https?:|//[a-z0-9.-]+\.[a-z]{2,}/|@import|@font-face|url\((?!data:)') "page web : aucune ressource exterieure"
Assert-True ($pgStyles -notmatch '(?i)\bInter\b|indigo|violet|backdrop-filter|linear-gradient|radial-gradient') "page web : ni police Inter, ni degrade, ni verre depoli"
Assert-True ($pgStyles -match '--font: "Segoe UI Variable Text", "Segoe UI Variable", "Segoe UI", -apple-system') "page web : polices du systeme"

$pgDo = @([regex]::Matches($pgCode, 'do: "([a-z-]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-Equal ((@($script:WebHandlers.Keys) | Sort-Object) -join " ") ($pgDo -join " ") "page web : chaque action de clm a son bouton, aucune inconnue"
$pgViews = @([regex]::Matches($pgCode, 'clmRead\("([a-z]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-Equal "backups prefs state" ($pgViews -join " ") "page web : vues lues"
$pgMenuWeb = [IO.File]::ReadAllText((Join-Path $bin "menu/loop/claude-menu-web.ps1"))
Assert-Equal "" (@($pgViews | Where-Object { $pgMenuWeb -notmatch ('\b' + $_ + ' = \{') }) -join " ") "page web : vues servies par le menu"
$pgNav = @([regex]::Matches([regex]::Match($pgCode, 'navNames = \[([^\]]*)\]').Groups[1].Value, '"([a-z]+)"') | ForEach-Object { $_.Groups[1].Value })
Assert-Equal "accounts drive backups settings" ($pgNav -join " ") "page web : navigation dans l'ordre"
$pgLost = @($pgNav | Where-Object { $pgHtml -notmatch ('id="tab-' + $_ + '" [^>]*aria-controls="part-' + $_ + '"') -or $pgHtml -notmatch ('<section id="part-' + $_ + '" class="part" role="tabpanel" aria-labelledby="tab-' + $_ + '"') })
Assert-Equal "" ($pgLost -join " ") "page web : chaque entree de navigation a sa partie"
Assert-Equal $pgNav.Count ([regex]::Matches($pgHtml, '<section ').Count) "page web : chaque partie a son entree"
$pgIds = @([regex]::Matches($pgCode, 'byId\("([a-z-]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Assert-Equal "" (@($pgIds | Where-Object { $pgHtml -notmatch ('id="' + $_ + '"') }) -join " ") "page web : elements cherches presents dans la page"
Assert-True ($pgHtml -match '<p id="busy" class="notice quiet" role="status"') "page web : annonce d'occupation lue par les lecteurs d'ecran"
Assert-True ($pgHtml -match 'id="lang-pick"' -and $pgHtml -match 'id="theme-pick"') "page web : choix de la langue et du theme dans l'en-tete"
foreach ($v in @("auto", "en", "fr")) { Assert-True ($pgHtml -match ('<option value="' + $v + '" data-text="lang\.' + $v + '">')) ("page web : langue " + $v + " proposee") }
foreach ($v in @("system", "light", "dark")) { Assert-True ($pgHtml -match ('<option value="' + $v + '" data-text="theme\.' + $v + '">')) ("page web : theme " + $v + " propose") }

$pgCopy = Join-Path $script:Sandbox "page-copy"
$pgLang = Join-Path $script:Sandbox "page-lang"
$null = New-SandboxFile "page-copy/core/a.js" "one"
$null = New-SandboxFile "page-copy/notes.txt" "no"
$null = New-SandboxFile "page-lang/en.json" "{}"
$pgKept = @{ Page = $script:WebPage; Tokens = $script:WebTokens }
try {
  Set-WebPage $pgCopy $pgLang
  $null = New-SandboxFile "page-copy/core/a.js" "two"
  Assert-Equal "one" (Get-WebPageText $script:WebPage "core/a.js") "page web : fichiers lus une fois au demarrage, servis depuis la memoire"
  Assert-Equal "core/a.js lang/en.json" ((@($script:WebPage.Keys) | Sort-Object) -join " ") "page web : seuls les types connus sont servis"
} finally {
  $script:WebPage = $pgKept.Page
  $script:WebTokens = $pgKept.Tokens
}
