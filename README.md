# mirror-axodotdev

OCX mirror for [cargo-dist](https://github.com/axodotdev/cargo-dist), Axo's
shippable-application packaging tool. One repository, one spec directory per
package.

| Package | Spec | Publishes to | Announced as | Upstream SPDX |
|---|---|---|---|---|
| [cargo-dist](https://github.com/axodotdev/cargo-dist) | [`cargo-dist/mirror.yml`](cargo-dist/mirror.yml) | `ghcr.io/ocx-contrib/axodotdev/cargo-dist` | [`ocx.sh/axodotdev/cargo-dist`](https://index.ocx.sh/axodotdev/cargo-dist) | `MIT OR Apache-2.0` |

Each upstream release is discovered, re-bundled, smoke-tested per
`(version, platform)` and only then pushed with cascade tags, after which the
result is announced into the OCX index.

> **The package is `cargo-dist`; the binary is `dist`.** The package segment is
> the name the project *publishes* under, never the command you type — the
> crate is `cargo-dist`, the repo is `axodotdev/cargo-dist`, and the binary
> itself self-reports `cargo-dist <version>`. Same relationship as `github/cli`
> shipping `gh`. The namespace `axodotdev` is the project's own org and
> plausibly holds more packages later (`oranda`, `axoupdater`); provenance
> lives in the index claim's `upstream` block, not in the namespace.

## Layout

```
mirror-base.yml         repo-wide policy every spec inherits via `extends:`
cargo-dist/
├── mirror.yml          the spec — never at the repo root
├── metadata.json       bundle interface
├── CATALOG.md          → ocx package describe
├── logo.svg / logo.png describe assets, 512px PNG
└── tests/smoke.star    Starlark smoke test
```

`LICENSE` and `NOTICE.md` are shared at the root. Logos are **not** — each
package carries its own, because a repo-root `logo.*` sits in no workflow's
`paths:` filter, so replacing it would publish nothing until some unrelated
edit happened to fire.

⚠️ `extends:` is a **shallow** merge of top-level keys. A spec that restates
`platforms:` to change one runner drops every `containers:` entry with it, and
nothing reds — the legs simply stop existing, and every `os.features` claim
goes back to being asserted rather than verified. Restate a block in full or
not at all.

## Platforms

`cargo-dist` publishes **five** platform entries: both Linux arches, both macOS
arches and `windows/amd64`.

**There is no `windows/arm64`, and none is planned.** Upstream has never
shipped an aarch64 Windows asset — every in-range release (v0.30.4, v0.31.0,
v0.32.0) ships exactly one Windows artifact,
`cargo-dist-x86_64-pc-windows-msvc.zip`. Declaring the key anyway would boot a
`windows-11-arm` runner that resolves no asset and reports success having
tested nothing.

Upstream ships **both** `-gnu` and `-musl` Linux assets for amd64 and arm64.
This mirror carries the **musl** ones, and both Linux keys are **bare** — no
`+libc.*` suffix. That is a measurement, not an inference: on v0.32.0 *and* on
the v0.30.4 floor, on x86-64 and aarch64 alike, the musl binaries have no
`PT_INTERP` and no `DT_NEEDED` — musl is linked *in*, not linked *against* —
and the UPX gate was cleared first (`strings -a | grep -c '^UPX'` = 0, section
headers at a non-zero offset) so that "statically linked" is a real reading and
not a packer stub hiding a dynamic build. The gnu binaries by contrast name
`/lib64/ld-linux-x86-64.so.2` and `/lib/ld-linux-aarch64.so.1` and need four to
five shared objects, so they would require `+libc.glibc`. `os.features` states
what an artifact requires *of the host*, and a static binary requires nothing —
tagging it `+libc.musl` would be a false requirement that hid the package from
every glibc host it in fact runs on. The second, gnu-keyed platform is not
carried because the usual reason to ship one is DNS (musl's resolver ignores
`nsswitch.conf` and loads no NSS modules) and `dist` makes plain HTTPS requests
to public hosts, reaching no alternative name source. The `alpine:3.20`
container leg in `mirror-base.yml` is what turns the universality claim into
evidence; the measurement itself is recorded above the `assets:` block in
`cargo-dist/mirror.yml`.

## The split archive layout

The unix tarballs and the Windows zip do **not** share a layout, so this spec
carries a per-platform `strip_components` override:

| Asset | Layout | `strip_components` |
|---|---|---|
| `cargo-dist-<triple>.tar.xz` (linux, darwin) | one wrapper directory `cargo-dist-<triple>/` holding `dist` + docs | `1` |
| `cargo-dist-x86_64-pc-windows-msvc.zip` | **flat** — `dist.exe` + docs at the archive root | `0` |

Every entry in the Windows zip sits at depth 1, so a uniform `1` would not
merely mis-path the bundle — it would leave **nothing in it at all**, and
`pipeline prepare` would still exit 0. Measured with a throwaway windows-only
probe spec, no runner involved:

```
strip_components: 0  →  bundle.tar.xz = dist.exe + the 4 doc files
strip_components: 1  →  bundle.tar.xz = COMPLETELY EMPTY, prepare exits 0
```

The layouts themselves were read with `tar tvf` on both ends of the range and
`unzip -l` on all three in-range Windows zips. Both land the payload at the
bundle content root, so one `metadata.json` with `PATH = ${installPath}` serves
every platform.

## Editing

| File | Edit | Regenerate after |
|------|------|------------------|
| `mirror-base.yml`, `cargo-dist/mirror.yml` | hand | yes — see below |
| `cargo-dist/{metadata.json,CATALOG.md,logo.*}` | hand | — |
| `cargo-dist/tests/smoke.star` | hand | — |
| `.github/workflows/*.yml` | **generated — never hand-edit** | re-run when a spec changes |

```bash
ocx-mirror package pipeline generate ci --spec cargo-dist/mirror.yml
```

**Name every spec.** `--spec` *appends* rather than replaces, so a command
naming a subset silently stops rendering the rest while staying green — and the
drift guard reds on a generated workflow the current spec set no longer
produces.

`verify-generated.yml` exits 65 on drift. If a generated workflow is wrong, the
spec or the renderer template is wrong — fix it there and regenerate.

Run `direnv allow` once to put the pinned toolchain on `PATH`, and invoke
`ocx-mirror` directly — never `ocx run -- ocx-mirror`, which pins
`OCX_BINARY_PIN` to the bootstrap `ocx` and false-reds the nested push.

## The binaries claim

`cargo-dist/metadata.json` declares `binaries: ["dist"]` by hand, and
`cargo-dist/mirror.yml` sets `bin_scan: "off"` — forced, not preferred. Every
unix archive wraps its payload in one directory named after the target triple,
which cannot be named in a static PATH; `strip_components: 1` removes it, and
the Windows zip has no wrapper to begin with. Either way the payload lands at
the content root with no subdirectory left for the scan to inspect — and with
nothing to inspect, `auto` and `verify` both fail spec load at exit 65 rather
than offer a hollow check. The hand-written list is what the error message
itself directs, and it is short and stable: `dist` (`dist.exe` on Windows) is
the only mode-0755 entry, while `README.md`, `CHANGELOG.md`, `LICENSE-MIT` and
`LICENSE-APACHE` are 0644 data.

## The smoke test

`cargo-dist/tests/smoke.star` runs `dist plan --output-format=json` over a
hermetic generic (non-Rust) workspace it writes into the scratch root, and
asserts the artifact names, announcement tag and archive kinds that `dist`
*computes* from that fixture — never help or version prose. The verb was chosen
because it is the one that runs the real planning engine while needing no build
toolchain, no network, no git repository and no writable `HOME`: proven with
`env -i PATH=<bundle bin dir only>`, which exits 0 on both ends of the mirrored
range. That is what lets the same script run unchanged on the bare
`ubuntu:24.04` / `alpine:3.20` / `fedora:40` container legs, none of which
ships git, and it is why no leg declares a `containers[].setup`.

The fixture interpolates the version read back from `dist --version`, because
`dist` refuses to plan unless the config's `cargo-dist-version` equals the
running binary exactly. That requirement doubles as the test's permanent
negative control: the last block re-writes the config with an impossible
version and asserts exit **255** with the plan tokens absent, while an unknown
subcommand is asserted at exit **2** — so a green run is evidence that a red
one was reachable, and the two failure modes are told apart.

## Required secrets

| Secret | Use |
|--------|-----|
| `OCX_ANNOUNCE_TOKEN` | opens the index pull request from the `ocx-contrib/index` fork |
| `OCX_MIRROR_DISCORD_HOOK` | notify-stage Discord webhook URL |

(Inherited from the `ocx-contrib` org with visibility ALL. GHCR pushes use the
run's own `GITHUB_TOKEN` — no registry secret needed.)

## License

Apache-2.0 — see [`LICENSE`](LICENSE). Upstream assets are out of scope; each
package's redistribution license is recorded in [`NOTICE.md`](NOTICE.md).
