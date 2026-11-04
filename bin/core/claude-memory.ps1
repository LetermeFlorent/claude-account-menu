$script:ClmPsapi = $null

function Get-ClmPsapi {
  if ($null -ne $script:ClmPsapi) { return $script:ClmPsapi }
  $asm = [Reflection.Emit.AssemblyBuilder]::DefineDynamicAssembly((New-Object Reflection.AssemblyName "ClmPsapi"), [Reflection.Emit.AssemblyBuilderAccess]::Run)
  $type = $asm.DefineDynamicModule("ClmPsapi").DefineType("ClmPsapi", "Public, Class")
  $m = $type.DefinePInvokeMethod("EmptyWorkingSet", "psapi.dll", "Public, Static, PinvokeImpl", "Standard", [bool], [Type[]]@([IntPtr]), "Winapi", "Auto")
  $m.SetImplementationFlags("PreserveSig")
  $script:ClmPsapi = $type.CreateType()
  return $script:ClmPsapi
}

function Clear-ClmMemory {
  [Runtime.GCSettings]::LargeObjectHeapCompactionMode = "CompactOnce"
  [GC]::Collect()
  if ([Environment]::OSVersion.Platform -ne "Win32NT") { return $false }
  try { return [bool](Get-ClmPsapi)::EmptyWorkingSet([Diagnostics.Process]::GetCurrentProcess().Handle) }
  catch { Write-Verbose $_.Exception.Message; return $false }
}
