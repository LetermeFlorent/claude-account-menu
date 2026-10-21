function New-OrderRemote { param([string]$Md5) return @{ Id = "i"; Md5 = $Md5; M = 10; Pc = "MAC" } }

foreach ($p in @(".claude/skills/a/SKILL.md", ".claude/agents/x.md", ".claude/commands/c.md", ".claude/hooks/h.ps1", ".claude/rules/r.md", ".claude/settings.json", ".claude-2/settings.json", ".claude/CLAUDE.md", ".claude/settings.local.json", ".claude.json", ".claude-2/.claude.json", ".mcp.json", ".claude-accounts.json", ".claude/statusline.json", ".claude/ANTI-EMPREINTE.md")) {
  Assert-True (Test-SettingsPath $p) ("reglage : " + $p)
}
foreach ($p in @(".claude/memory/m.md", ".claude/projects/p/x.jsonl", ".claude/skills", ".claude/settings.json.bak", ".claude/plugins/p.json", ".claude/sub/settings.json", "x/.claude/settings.json")) {
  Assert-True (-not (Test-SettingsPath $p)) ("pas un reglage : " + $p)
}

$orderRemote = New-PathMap
foreach ($p in @(".claude/memory/m.md", ".claude/projects/p/x.jsonl", ".claude/skills/a/SKILL.md", ".claude/a-note.md", ".claude/settings.json", ".mcp.json")) { $orderRemote[$p] = New-OrderRemote $p }
$orderBase = New-PathMap
$orderBase[".claude/old.md"] = @{ Md5 = "o"; M = 10; Size = 1; Id = "i" }
$orderPlan = Get-SyncPlan (New-PathMap) $orderBase $orderRemote
Assert-Equal ".claude/old.md|.claude/settings.json|.claude/skills/a/SKILL.md|.mcp.json|.claude/a-note.md|.claude/memory/m.md|.claude/projects/p/x.jsonl" (($orderPlan | ForEach-Object { $_.Path }) -join "|") "oublis, puis reglages, puis le reste, conversations a la fin"
Assert-Equal "forget" $orderPlan[0].Kind "oubli en premier"
