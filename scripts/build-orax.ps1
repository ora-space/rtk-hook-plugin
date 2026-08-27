# Build script: assembles the rtk-ai.rtk-v0.1.0-x86_64-pc-windows-msvc.orax artifact reproducibly.
#
# The .orax is a zip whose entries must use forward-slash separators so Ora's Rust archive
# extractor (and cross-platform unzip) resolve the same paths on every host. Windows
# System.IO.Compression.ZipFile::CreateFromDirectory emits backslash separators, so this
# script assembles the archive entry-by-entry with canonical forward-slash names.
#
# Inputs (env):
#   UPSTREAM_ASSET_SHA256 - expected SHA-256 of the upstream rtk-x86_64-pc-windows-msvc.zip
#   UPSTREAM_ZIP          - path to the downloaded upstream zip (verified against the pinned digest here)
# Outputs:
#   dist/rtk-ai.rtk-v0.1.0-x86_64-pc-windows-msvc.orax         - the final .orax package
#   dist/rtk-ai.rtk-v0.1.0-x86_64-pc-windows-msvc.orax.sha256  - the final .orax SHA-256
param(
  [string]$UpstreamZip = $env:UPSTREAM_ZIP,
  [string]$ExpectedSha256 = $env:UPSTREAM_ASSET_SHA256
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot/.."
$packaging = Join-Path $root "packaging"
$dist = Join-Path $root "dist"
if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Path $dist | Out-Null }

if (-not $UpstreamZip) { throw "UPSTREAM_ZIP env var or -UpstreamZip must point to the upstream zip" }
if (-not (Test-Path $UpstreamZip)) { throw "upstream zip not found at $UpstreamZip" }
if (-not $ExpectedSha256) {
  $ExpectedSha256 = "34cea9009a8099acdaf85147b971d95f65efabfa63fb3aea7d3e2b73e6f517c3"
}

# Verify the upstream asset SHA-256 against the pinned digest before unpacking.
$actual = (Get-FileHash -Algorithm SHA256 -Path $UpstreamZip).Hash.ToLower()
$expected = $ExpectedSha256.ToLower()
if ($actual -ne $expected) {
  throw "upstream asset SHA-256 mismatch: expected $expected, got $actual"
}
Write-Output "upstream asset SHA-256 verified: $actual"

# Stage a clean assembly directory and materialize the immutable declaration files plus the
# verified executable.
$stage = Join-Path $env:TEMP "rtk-orax-stage-$([System.Guid]::NewGuid().ToString('N'))"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Path $stage | Out-Null
$assets = Join-Path $stage "assets"
New-Item -ItemType Directory -Path $assets | Out-Null
Copy-Item (Join-Path $packaging "orax.toml") (Join-Path $stage "orax.toml")
Copy-Item (Join-Path (Join-Path $packaging "assets") "config.json") (Join-Path $assets "config.json")
Copy-Item (Join-Path $packaging "logo.svg") (Join-Path $stage "logo.svg")
Copy-Item (Join-Path $root "README.md") (Join-Path $stage "README.md")
Copy-Item (Join-Path $packaging "LICENSE") (Join-Path $stage "LICENSE")

# Extract the verified rtk.exe into the staged assets/ directory.
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($UpstreamZip)
try {
  $entry = $zip.Entries | Where-Object { $_.Name -eq "rtk.exe" } | Select-Object -First 1
  if (-not $entry) { throw "upstream zip does not contain rtk.exe" }
  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $assets "rtk.exe"), $true)
} finally {
  $zip.Dispose()
}

# Assemble the final .orax zip entry-by-entry with forward-slash separators. Each file is read
# from the staged tree and added with a canonical relative path so the archive is portable.
$oraxName = "rtk-ai.rtk-v0.1.0-x86_64-pc-windows-msvc.orax"
$oraxPath = Join-Path $dist $oraxName
if (Test-Path $oraxPath) { Remove-Item -Force $oraxPath
}
$orax = [System.IO.Compression.ZipFile]::Open($oraxPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  $entries = @(
    @{ Path = "orax.toml"; File = (Join-Path $stage "orax.toml") },
    @{ Path = "logo.svg"; File = (Join-Path $stage "logo.svg") },
    @{ Path = "README.md"; File = (Join-Path $stage "README.md") },
    @{ Path = "LICENSE"; File = (Join-Path $stage "LICENSE") },
    @{ Path = "assets/config.json"; File = (Join-Path $assets "config.json") },
    @{ Path = "assets/rtk.exe"; File = (Join-Path $assets "rtk.exe") }
  )
  foreach ($e in $entries) {
    $entry = $orax.CreateEntry($e.Path, [System.IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime = (Get-Item $e.File).LastWriteTime
    $stream = $entry.Open()
    try {
      $bytes = [System.IO.File]::ReadAllBytes($e.File)
      $stream.Write($bytes, 0, $bytes.Length)
    } finally {
      $stream.Dispose()
    }
  }
} finally {
  $orax.Dispose()
}

# Compute and record the final .orax SHA-256.
$oraxSha = (Get-FileHash -Algorithm SHA256 -Path $oraxPath).Hash.ToLower()
$shaPath = "$oraxPath.sha256"
Set-Content -Path $shaPath -Value "$oraxSha  $oraxName"

Write-Output "built $oraxPath"
Write-Output "final .orax SHA-256: $oraxSha"

Remove-Item -Recurse -Force $stage
