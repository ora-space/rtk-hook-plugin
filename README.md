# RTK Hook Plugin

This repository packages the [RTK](https://github.com/rtk-ai/rtk) command-rewrite tool as an Ora
**Hook Plugin** `.orax` artifact. It is the build-and-release host for the
`official/rtk-ai.rtk` marketplace listing; the marketplace repository itself only carries the
listing, README, and logo.

## What this packages

- **RTK `v0.45.0`** Windows x86_64 executable (`rtk.exe`), downloaded and SHA-256 verified from
  the upstream [`rtk-ai/rtk` v0.45.0 release](https://github.com/rtk-ai/rtk/releases/tag/v0.45.0).
- The Ora `orax.toml` installed manifest declaring `kind = "hook"` and the
  `x86_64-pc-windows-msvc` artifact target.
- The immutable `assets/config.json` Hook Configuration declaring the `rtk-rewrite-v1` protocol,
  the bare `rtk` command alias, the package-relative executable, and the embedded tool version.
- The upstream Apache-2.0 `LICENSE`, a user-facing `README.md`, and a safe SVG `logo.svg`.

The package contains **no** `main.js`, no RTK source, and no Rust toolchain: installation never
executes the payload, and runnability is proven by this repository's release workflow and isolated
end-to-end tests.

## Reproducible build

The release workflow (`.github/workflows/release.yml`) is pinned to:

- Upstream RTK tag: `v0.45.0`
- Upstream commit: `b34be37caf3796b69a50952a28e60e32b5daad43`
- Upstream asset: `rtk-x86_64-pc-windows-msvc.zip`
- Upstream asset SHA-256: `34cea9009a8099acdaf85147b971d95f65efabfa63fb3aea7d3e2b73e6f517c3`

It downloads and verifies the upstream archive, extracts `rtk.exe`, assembles the `.orax` zip
from the immutable declaration files plus the executable, computes the final `.orax` SHA-256,
runs Windows smoke tests on the exact produced archive, and only then publishes the release.

## Hook Configuration

```json
{
  "schemaVersion": 1,
  "hook": {
    "protocol": "rtk-rewrite-v1",
    "executable": "assets/rtk.exe",
    "command": "rtk",
    "toolVersion": "0.45.0"
  }
}
```

The Hook Plugin version is `0.1.0`, independent from the embedded RTK tool version `0.45.0`.

## Local tracking behavior disclosure

RTK `0.45.0` stores local command-tracking data in a SQLite database and does not honor its
declared tracking-disable setting. This Hook is inert in the installation-only milestone, but a
future Agent Plugin consumer must redirect RTK's database to Ora-managed data, disable tee and
telemetry, and disclose the local retention of original commands and project paths.
