$ErrorActionPreference = 'Stop'

# Install-ChocolateyZipPackage records every file it extracts in a
# `<packageName>.zip.txt` manifest and Chocolatey automatically removes those
# files (and the auto-generated bao.exe shim) when the package is uninstalled.
#
# This script only cleans up any stragglers that might remain in the tools
# directory so an uninstall leaves nothing behind.
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

$leftovers = Get-ChildItem -Path $toolsDir -Filter 'bao.exe' -ErrorAction SilentlyContinue
foreach ($item in $leftovers) {
  Remove-Item $item.FullName -Force -ErrorAction SilentlyContinue
}
