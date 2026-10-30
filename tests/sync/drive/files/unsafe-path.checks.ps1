foreach ($p in @(".claude/a.", ".claude/a /b.md", ".claude/b.md ", ".claude/CON", ".claude/con.txt", ".claude/x/Nul.json/y", ".claude/aux", ".claude/PRN.tar.gz", ".claude/com1", ".claude/LPT9.md", ".claude/x/./y", ".claude/x//y", ".claude/..")) {
  Assert-True ($script:UnsafeSyncPath.IsMatch($p)) ("chemin de synchro dangereux : [" + $p + "]")
}
foreach ($p in @(".claude/a.md", ".claude/console.md", ".claude/com10", ".claude/com0", ".claude/lpt", ".claude/null.md", ".claude/my con.md", ".claude/.hidden", ".claude/a b.md", ".claude/xcon")) {
  Assert-True (-not $script:UnsafeSyncPath.IsMatch($p)) ("chemin de synchro accepte : [" + $p + "]")
}
