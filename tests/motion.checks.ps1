Assert-Equal 0 (Get-EaseOut 0) "ralenti au depart"
Assert-Equal 1 (Get-EaseOut 1) "ralenti a l'arrivee"
Assert-Equal 0.875 (Get-EaseOut 0.5) "ralenti a mi-course"
Assert-Equal 0 (Get-EaseOut -0.5) "ralenti borne avant le depart"
Assert-Equal 1 (Get-EaseOut 2) "ralenti borne apres l'arrivee"

$from = @(0, 0, 0)
$to = @(200, 100, 50)
Assert-Equal "0 0 0" ((Get-MixedRgb $from $to 0) -join " ") "melange au depart"
Assert-Equal "100 50 25" ((Get-MixedRgb $from $to 0.5) -join " ") "melange a mi-course"
Assert-Equal "200 100 50" ((Get-MixedRgb $from $to 1) -join " ") "melange a l'arrivee"
Assert-Equal "200 100 50" ((Get-MixedRgb $from $to 3) -join " ") "melange borne"

$script:MotionOn = $true
$tw = New-Tween 0 100 400 1000
Assert-Equal 0 (Get-TweenValue $tw 1000) "interpolation au depart"
Assert-Equal 87.5 (Get-TweenValue $tw 1200) "interpolation a mi-course"
Assert-Equal 100 (Get-TweenValue $tw 1400) "interpolation a la fin"
Assert-Equal 100 (Get-TweenValue $tw 9000) "interpolation apres la fin"
Assert-True (Test-TweenRunning $tw 1200) "interpolation en cours"
Assert-True (-not (Test-TweenRunning $tw 1400)) "interpolation finie"
Set-TweenTarget $tw 0 400 1200
Assert-Equal 87.5 (Get-TweenValue $tw 1200) "reprise depuis la valeur affichee"
Assert-Equal 0 (Get-TweenValue $tw 1600) "reprise jusqu'a la nouvelle cible"
$script:MotionOn = $false
$tw = New-Tween 0 100 400 1000
Assert-Equal 100 (Get-TweenValue $tw 1000) "animations coupees, valeur finale tout de suite"
Assert-True (-not (Test-TweenRunning $tw 1000)) "animations coupees, rien en cours"
Set-TweenTarget $tw 40 300 1000
Assert-Equal 40 (Get-TweenValue $tw 1000) "animations coupees, nouvelle cible tout de suite"
$script:MotionOn = $true

Assert-True (-not (ConvertTo-MotionFlag "Windows" $false)) "Windows, animations coupees"
Assert-True (ConvertTo-MotionFlag "Windows" $true) "Windows, animations actives"
Assert-True (-not (ConvertTo-MotionFlag "Linux" "false`n")) "GNOME, animations coupees"
Assert-True (ConvertTo-MotionFlag "Linux" "true") "GNOME, animations actives"
Assert-True (-not (ConvertTo-MotionFlag "MacOS" "1`n")) "macOS, mouvement reduit"
Assert-True (ConvertTo-MotionFlag "MacOS" "0") "macOS, mouvement normal"
Assert-True (ConvertTo-MotionFlag "Linux" $null) "reglage absent"
Assert-True (-not (Get-MotionEnabled $script:OsName @{ CLM_ANIM = "0" })) "CLM_ANIM=0 coupe"
Assert-True (Get-MotionEnabled $script:OsName @{ CLM_ANIM = "1" }) "CLM_ANIM=1 force"
