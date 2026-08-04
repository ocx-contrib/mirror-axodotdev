---
title: cargo-dist
description: Shippable application packaging — plans, builds and publishes cross-platform release artifacts and installers
keywords: cargo-dist,dist,axo,packaging,release,distribution,installer,artifacts,cross-platform,ci,rust
---

# cargo-dist

[cargo-dist](https://github.com/axodotdev/cargo-dist) takes an application and
produces a complete, reproducible set of release artifacts for every platform
you target: platform-specific archives, checksums, a machine-readable
`dist-manifest.json`, and the installers that fetch them — shell, PowerShell,
Homebrew formula and npm wrapper. It plans the whole release up front, so what
CI builds is decided before a single compiler runs.

The tool began life as a `cargo` subcommand and still publishes under the name
`cargo-dist`, but the executable it installs is **`dist`**, and it is no longer
Rust-only: a *generic* workspace hands `dist` any `build-command` you like, so
Go, Zig, C and shell projects get the same artifact matrix, checksums and
installers as a Cargo workspace does.

`dist init` writes the configuration and the release workflow; `dist plan` shows
exactly which artifacts a release would produce (and, with
`--output-format=json`, in a form other tools can consume); `dist build` runs a
local build of them; `dist host` uploads. Because `plan` is pure computation it
needs no toolchain, no network and no git repository — it is the fast way to
answer "what would this release actually ship?".

## What's included

- **dist** — the packaging CLI. `dist init` to set up or update a project,
  `dist plan` to see the artifact matrix, `dist build` to produce it locally,
  `dist manifest` for the build manifest without building, `dist linkage` to
  report the dynamic libraries a built artifact pulls in, and `dist host` to
  publish.

The mirrored archives also carry upstream's `README.md`, `CHANGELOG.md` and
both license files (`LICENSE-MIT`, `LICENSE-APACHE`) alongside the binary.

## Install with ocx

```sh
ocx install ocx.sh/axodotdev/cargo-dist
```

```sh
# or pin a specific version
ocx install ocx.sh/axodotdev/cargo-dist:0.32.0
```

## Links

- [cargo-dist on GitHub](https://github.com/axodotdev/cargo-dist)
- [The dist book](https://axodotdev.github.io/cargo-dist/)
- [Quickstart](https://axodotdev.github.io/cargo-dist/book/quickstart/)
- [Configuration reference](https://axodotdev.github.io/cargo-dist/book/reference/config.html)
