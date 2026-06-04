$ErrorActionPreference = 'Stop'

$packageName = 'openbao'
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition

# OpenBao publishes 64-bit Windows builds only (no 32-bit x86). Pick the archive
# that matches the current processor architecture. Both URLs and their SHA256
# checksums are taken from the official `checksums-windows.txt` for the release
# and are kept up to date by the chocolatey-au updater (update.ps1).
$amd64Url      = 'https://github.com/openbao/openbao/releases/download/v2.5.4/bao_2.5.4_Windows_x86_64.zip'
$amd64Checksum = 'abe759dec0b0aa7c6733f456a8a59c91840b5b4ec3db297567900cd7e298e3d4'
$arm64Url      = 'https://github.com/openbao/openbao/releases/download/v2.5.4/bao_2.5.4_Windows_arm64.zip'
$arm64Checksum = 'e313470be790417f1765f3a718308f2c2c4811f45800f26f22b943e6201d57d5'

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
