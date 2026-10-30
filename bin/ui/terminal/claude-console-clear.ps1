function Clear-ConsoleScreen {
  try { Clear-Host } catch { Write-Verbose $_.Exception.Message }
}
