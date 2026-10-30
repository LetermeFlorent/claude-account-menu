function Save-RemoteConflict {
  param($Ctx, [string]$Rel)
  $R = $Ctx.Remote[$Rel]
  $pc = $R.Pc
  if (-not $pc) { $pc = "drive" }
  Receive-DriveFile $R.Id (Get-SyncLocalPath (Get-ConflictPath $Rel $pc)) ($script:SealedFilesArea + $Rel) $Ctx.Keys
}

function Save-LocalConflict {
  param($Ctx, [string]$Rel)
  [IO.File]::WriteAllBytes((Get-SyncLocalPath (Get-ConflictPath $Rel $Ctx.Pc)), (Read-SharedBytes $Ctx.Local[$Rel].Full))
}
