$ErrorActionPreference = 'Stop'

$packageName = 'openbao'
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition

# OpenBao publishes 64-bit Windows builds only (no 32-bit x86). Pick the archive
# that matches the current processor architecture. Both URLs and their SHA256
# checksums are taken from the official `checksums.txt` for the release
# and are kept up to date by the chocolatey-au updater (update.ps1).
$amd64Url      = 'https://github.com/openbao/openbao/releases/download/v2.6.2/openbao_2.6.2_windows_amd64.zip'
$amd64Checksum = '12e8d40c71fe5a0aa23062c6c36a77a96717005980e30d0d42acdea3268d3fa2'
$arm64Url      = 'https://github.com/openbao/openbao/releases/download/v2.6.2/openbao_2.6.2_windows_arm64.zip'
$arm64Checksum = 'e4fa1edb95129c36a36cfc5ad1b96198208344df42f66371b14fe579328ec662'

# PROCESSOR_ARCHITECTURE reports the architecture of the running process; under a
# 32-bit (WOW64) process on a 64-bit OS the native architecture is exposed via
# PROCESSOR_ARCHITEW6432. Check both so ARM64 is detected reliably.
$nativeArch = $env:PROCESSOR_ARCHITEW6432
if (-not $nativeArch) { $nativeArch = $env:PROCESSOR_ARCHITECTURE }

if ($nativeArch -eq 'ARM64') {
  $url      = $arm64Url
  $checksum = $arm64Checksum
} else {
  $url      = $amd64Url
  $checksum = $amd64Checksum
}

$packageArgs = @{
  PackageName   = $packageName
  UnzipLocation = $toolsDir
  Url64bit      = $url
  Checksum64    = $checksum
  ChecksumType64 = 'sha256'
}

# Downloads, verifies the checksum, and extracts the archive. Chocolatey records
# the extracted files and automatically creates a shim for bao.exe so the `bao`
# command is available on the PATH.
Install-ChocolateyZipPackage @packageArgs

# The archive also contains documentation files alongside bao.exe. They are
# harmless (not executables, so they are not shimmed) but we don't need them on
# disk after install. Remove them if present.
foreach ($extra in 'CHANGELOG.md', 'README.md', 'LICENSE') {
  $path = Join-Path $toolsDir $extra
  if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
}
