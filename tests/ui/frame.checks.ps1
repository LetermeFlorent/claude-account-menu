$e = $script:Esc
$segs = @(@("ab", @(200, 10, 20), $false), @("", @(9, 9, 9), $false), @("cd", @(1, 2, 3), $true))
Assert-Equal ($e + "[0;38;2;200;10;20mab" + $e + "[0;1;38;2;1;2;3mcd" + $e + "[0m") (ConvertTo-LineText $segs 80) "ligne rendue en couleurs"
$cut = (ConvertTo-LineText @(@("abcdef", @(1, 1, 1), $false), @("gh", @(1, 1, 1), $false)) 4) -replace "$e\[[0-9;]*m", ""
Assert-Equal "abcd" $cut "ligne coupee a la largeur"
Assert-Equal ($e + "[0;38;2;130;130;130mx" + $e + "[0m") (ConvertTo-LineText @(, @("x", @(250, 250, 250), $false)) 9 0.5 @(10, 10, 10)) "fondu vers le fond"

$a = [string[]]@("un", "deux", "trois")
Assert-Equal "" (Get-FrameUpdate $a $a) "image identique, rien a ecrire"
Assert-Equal ($e + "[2;1HDEUX" + $e + "[K") (Get-FrameUpdate ([string[]]@("un", "DEUX", "trois")) $a) "seule la ligne changee est reecrite"
Assert-Equal ($e + "[3;1H" + $e + "[2K") (Get-FrameUpdate ([string[]]@("un", "deux")) $a) "ligne en trop effacee"
Assert-Equal ($e + "[1;1Hun" + $e + "[K" + $e + "[2;1Hdeux" + $e + "[K") (Get-FrameUpdate ([string[]]@("un", "deux")) $null) "premiere image complete"
