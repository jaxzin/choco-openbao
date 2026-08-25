#requires -Modules au
# chocolatey-au updater for the OpenBao package.
#
# Detects the latest OpenBao release on GitHub, reads the official
# checksums-windows.txt to obtain the SHA256 checksums for the Windows x86_64 and
# arm64 archives, and rewrites the version, download URLs, and checksums across
# the package files.
#
# Usage:
#   Install-Module au -Scope CurrentUser
#   ./update.ps1            # update in place
#   ./update.ps1 -Force     # rebuild .nupkg even if nothing changed
[CmdletBinding()]
param([switch]$Force)

Import-Module au

$global:repo = 'openbao/openbao'

function global:au_GetLatest {
  $headers = @{ 'User-Agent' = 'choco-openbao-au' }
  if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }

  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers
  $tag = $release.tag_name                 # e.g. v2.5.4
  $version = $tag -replace '^v', ''        # e.g. 2.5.4

  # Pull the official checksums file and parse the two archives we ship. As of
  # v2.6.0 OpenBao publishes a single combined `checksums.txt` (the old
  # per-OS `checksums-windows.txt` was removed).
  # GitHub serves the asset as application/octet-stream, so Invoke-WebRequest
  # returns .Content as a byte[]. Decode it to text before parsing — otherwise
  # splitting the byte array yields per-byte garbage and no checksum is found.
  $checksumsUrl = "https://github.com/$repo/releases/download/$tag/checksums.txt"
  $checksumsRaw = (Invoke-WebRequest -Uri $checksumsUrl -Headers $headers -UseBasicParsing).Content
  $checksums = if ($checksumsRaw -is [byte[]]) {
    [System.Text.Encoding]::UTF8.GetString($checksumsRaw)
  } else {
    $checksumsRaw
  }

  function Get-Sum([string]$fileName) {
    foreach ($line in $checksums -split "`n") {
      $parts = $line.Trim() -split '\s+'
      if ($parts.Count -ge 2 -and $parts[1] -eq $fileName) { return $parts[0] }
    }
    throw "Checksum for $fileName not found in checksums-windows.txt"
  }

  # Archive naming also changed at v2.6.0: `bao_<v>_Windows_x86_64.zip` became
  # `openbao_<v>_windows_amd64.zip` (and `Windows_arm64` -> `windows_arm64`).
  $amd64File = "openbao_${version}_windows_amd64.zip"
  $arm64File = "openbao_${version}_windows_arm64.zip"

  return @{
    Version        = $version
    Tag            = $tag
    URL64          = "https://github.com/$repo/releases/download/$tag/$amd64File"
    Checksum64     = Get-Sum $amd64File
    ChecksumType64 = 'sha256'
    URLARM64       = "https://github.com/$repo/releases/download/$tag/$arm64File"
    ChecksumARM64  = Get-Sum $arm64File
    ReleaseNotes   = "https://github.com/$repo/releases/tag/$tag"
  }
}

function global:au_SearchReplace {
  @{
    'tools\chocolateyInstall.ps1' = @{
      "(?i)(\`$amd64Url\s*=\s*')[^']*(')"      = "`${1}$($Latest.URL64)`${2}"
      "(?i)(\`$amd64Checksum\s*=\s*')[^']*(')" = "`${1}$($Latest.Checksum64)`${2}"
      "(?i)(\`$arm64Url\s*=\s*')[^']*(')"      = "`${1}$($Latest.URLARM64)`${2}"
      "(?i)(\`$arm64Checksum\s*=\s*')[^']*(')" = "`${1}$($Latest.ChecksumARM64)`${2}"
    }
    'openbao.nuspec' = @{
      '(?m)(<releaseNotes>).*(</releaseNotes>)' = "`${1}$($Latest.ReleaseNotes)`${2}"
    }
  }
}

# VERIFICATION.txt embeds the full (per-release) checksums, so regenerate it from
# a template rather than trying to regex-patch individual hash values in place.
function global:au_AfterUpdate {
  $verification = @"
VERIFICATION

Verification is intended to assist the Chocolatey moderators and any user in
verifying that the binaries this package installs are the official, unmodified
OpenBao release binaries.

This package does NOT embed any binaries. At install time it downloads the
official release archive directly from the OpenBao GitHub releases page and
verifies its SHA256 checksum before extracting it.

Package version: $($Latest.Version)
Upstream release: $($Latest.ReleaseNotes)

Downloaded files and their expected SHA256 checksums:

  x86_64 (amd64):
    URL:      $($Latest.URL64)
    SHA256:   $($Latest.Checksum64)

  arm64:
    URL:      $($Latest.URLARM64)
    SHA256:   $($Latest.ChecksumARM64)

These checksums come from the official per-OS checksum file published with the
release:

    https://github.com/$repo/releases/download/$($Latest.Tag)/checksums.txt

To verify a download yourself (PowerShell):

    Get-FileHash -Algorithm SHA256 .\openbao_$($Latest.Version)_windows_amd64.zip

and compare the result to the value above, or cross-check it against
checksums.txt.

The OpenBao LICENSE (Mozilla Public License 2.0) is included in this package as
LICENSE.txt and is also available at:

    https://github.com/openbao/openbao/blob/main/LICENSE
"@

  Set-Content -Path "$PSScriptRoot\tools\VERIFICATION.txt" -Value $verification -Encoding ascii
}

# Checksums are sourced from the official checksums file, so do not let au
# recompute them from the downloaded archives.
#
# -NoReadme keeps the nuspec <description> authoritative. By default au syncs the
# description from README.md, but the full README (~4.9k chars) exceeds the
# Chocolatey gallery's 4000-char description limit; the nuspec carries its own
# trimmed description instead.
Update-Package -ChecksumFor none -NoReadme -Force:$Force
