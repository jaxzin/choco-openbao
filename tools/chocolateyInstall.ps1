$ErrorActionPreference = 'Stop'

$packageName = 'openbao'
$toolsDir    = Split-Path -Parent $MyInvocation.MyCommand.Definition

# OpenBao publishes 64-bit Windows builds only (no 32-bit x86). Pick the archive
# that matches the current processor architecture. Both URLs and their SHA256
# checksums are taken from the official `checksums.txt` for the release
# and are kept up to date by the chocolatey-au updater (update.ps1).
$amd64Url      = 'https://github.com/openbao/openbao/releases/download/v2.5.5/bao_2.5.5_Windows_x86_64.zip'
$amd64Checksum = 'ed412b3233cb5d870ed8bec4cb1bdd3cdfeefa193c6c21f7c7d2055481b140bc'
$arm64Url      = 'https://github.com/openbao/openbao/releases/download/v2.5.5/bao_2.5.5_Windows_arm64.zip'
$arm64Checksum = 'e59bf87f3dbcf840059cbb03dcce275ccd04ea42d5efe615ebf329f09b73227d'

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
