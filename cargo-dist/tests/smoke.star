# cargo-dist/tests/smoke.star — stable across upstream releases.
# Asserts the contract (exit codes, version shape, values the tool COMPUTES),
# never help/version prose. See ocx.mirror testing-practices.md.
#
# The tool is published as `cargo-dist` but the shipped executable is `dist`.
#
# ─── Why this test is hermetic, and how that was established ────────────────
#
# `dist plan` is the one verb that runs the real planning engine — workspace
# parse, target resolution, artifact-name synthesis — WITHOUT needing a build
# toolchain, a git repository, a network, or a writable HOME. Proven before
# this file was written, on the v0.30.4 floor and on v0.32.0:
#
#   $ cd <empty scratch dir with only the two config files below>
#   $ env -i PATH=<bundle bin dir ONLY> dist plan --output-format=json
#   exit 0, full JSON plan on stdout
#   stderr: " WARN skipping source tarball; git not installed"
#
# No cargo, no rustc, no git, no HOME, no $PATH beyond the bundle itself. That
# is what lets the same script run unchanged on the bare ubuntu:24.04 /
# alpine:3.20 / fedora:40 container legs, none of which ships git — and it is
# why ../../mirror-base.yml declares no `containers[].setup` for any leg. The
# same invocation was also run WITH git present, both inside and outside a git
# repository, and both exit 0; the git-absent path is the only one that even
# logs a warning, and it logs to stderr.
#
# ─── Why the config interpolates the running version ───────────────────────
#
# `dist` refuses to plan unless `cargo-dist-version` in the workspace config
# equals the running binary's version EXACTLY, exiting 255 with
# "You're running dist X, but 'cargo-dist-version = Y' is set". A hard-coded
# version would therefore red on every release but one. Reading it back out of
# `--version` is not decoration: it is the only way this file survives the
# next upgrade — and it hands us a free negative control (Tier 3c below).

DIST = "dist.exe" if ocx.target_platform.os == ocx.os.Windows else "dist"

# `dist` calls exit(-1) when the config's cargo-dist-version does not match the
# running binary (Tier 3c). A NEGATIVE exit does not survive to the caller the
# same way on both platforms: POSIX passes only the low 8 bits, so -1 arrives as
# 255, while Windows keeps the full 32-bit value and RunResult.exit_code
# surfaces it as -1. Same tool behaviour, two OS encodings — so the expected
# code is a platform constant rather than a bare integer.
#
# Both values are MEASURED, not assumed: 255 locally on linux/amd64 for all
# three in-range versions, -1 on the windows-latest leg. The distinction from
# clap's exit 2 (Tier 3b) is preserved on both platforms, which is the whole
# point of pinning it. Note this asymmetry does NOT apply to positive codes —
# clap's 2 is 2 everywhere, which is why Tier 3b needs no branch.
MISMATCH_EXIT = -1 if ocx.target_platform.os == ocx.os.Windows else 255

# ─── Tier 1 + 2: liveness on the composed PATH, and version SHAPE ──────────
# The digits are the contract; the vendor banner is not. `--version` prints
# `cargo-dist <X.Y.Z>` — one line, the version as its last whitespace token.
r_version = ocx.run(DIST, "--version")
expect.ok(r_version)
expect.matches(r_version.stdout, r"\d+\.\d+\.\d+")

VERSION = r_version.stdout.strip().split(" ")[-1]
# Re-asserted anchored: if the banner shape ever changes, this reds HERE with
# a clear cause rather than as a baffling exit-255 config mismatch below.
expect.matches(VERSION, r"^\d+\.\d+\.\d+$")


# ─── Hermetic fixture ───────────────────────────────────────────────────────
# A GENERIC (non-Rust) dist workspace: `dist:app` selects the generic backend,
# so no Cargo.toml, no crate, no cargo is involved. `build-command` is recorded
# in the plan but never executed by `plan`, so it need not exist on any host.
#
# The two `targets` are pinned to fixed triples that are NOT the host's, so
# every assertion below is byte-identical on all five mirrored platforms and
# the plan is proven to be a pure computation rather than a probe of the
# machine it runs on. `ocx.run`'s cwd is the scratch root, so "ws" resolves
# here.
def write_workspace(config_version):
    ocx.mkdir("ws/app")
    ocx.write_file("ws/dist-workspace.toml", "\n".join([
        '[workspace]',
        'members = ["dist:app"]',
        '',
        '[dist]',
        'cargo-dist-version = "' + config_version + '"',
        'targets = ["x86_64-unknown-linux-gnu", "aarch64-apple-darwin"]',
        'ci = []',
        'installers = []',
        '',
    ]))
    ocx.write_file("ws/app/dist.toml", "\n".join([
        '[package]',
        'name = "ocxsmoke"',
        'version = "4.5.6"',
        'description = "ocx mirror smoke fixture"',
        'license = "MIT"',
        'repository = "https://github.com/ocx-contrib/mirror-axodotdev"',
        'binaries = ["ocxsmoke"]',
        'build-command = ["echo", "ocx-smoke"]',
        '',
    ]))


# ─── Tier 3a: the planning engine actually runs and computes ───────────────
# Every token asserted here is SYNTHESISED by dist from the fixture — none of
# it is echoed input:
#   * the announcement tag  `v4.5.6`  = "v" + the package version
#   * the artifact filenames          = name + target triple + the archive
#     format dist chose for that triple
#   * `dist_version`                  = the running binary, tying the plan
#     output back to the artifact under test
# Counts are pinned, not merely `expect.ok`: `plan` exits 0 on a workspace it
# found nothing to release in, so an exit-code-only check would sail past an
# engine that produced an EMPTY plan. Every count below was measured on all
# three in-range releases (0.30.4 / 0.31.0 / 0.32.0) and is identical on each.
write_workspace(VERSION)

r_plan = ocx.run(DIST, "plan", "--output-format=json", cwd="ws")
expect.ok(r_plan)
expect.eq(r_plan.stdout.count('"announcement_tag": "v4.5.6"'), 1)
expect.eq(r_plan.stdout.count('"dist_version": "' + VERSION + '"'), 1)
# 3 occurrences each: the release's artifact list, the artifacts-map key, and
# the entry's own `name` field.
expect.eq(r_plan.stdout.count('ocxsmoke-x86_64-unknown-linux-gnu.tar.xz"'), 3)
expect.eq(r_plan.stdout.count('ocxsmoke-aarch64-apple-darwin.tar.xz"'), 3)
# One executable-zip per declared target — the plan covered both, not just one.
expect.eq(r_plan.stdout.count('"kind": "executable-zip"'), 2)

# ─── Tier 3b: argv parsing is real ─────────────────────────────────────────
# clap rejects an unknown subcommand with exit 2 specifically. Pinning the
# exact code (not "non-zero") is what makes Tier 3c's 255 meaningful: it
# distinguishes "the version gate fired" from "the command line was a typo".
r_bogus = ocx.run(DIST, "ocx-not-a-subcommand")
expect.eq(r_bogus.exit_code, 2)

# ─── Tier 3c: the negative control — red IS reachable ──────────────────────
# Same fixture, same verb, one field changed to a version that cannot be the
# running binary's (dist has never released a 0.0.1). dist's own config gate
# must reject it — with the platform-encoded exit(-1) defined at the top of
# this file — and the plan tokens from Tier 3a must be absent. Without this,
# every assertion above could be satisfied by a tool that ignored the config
# entirely.
write_workspace("0.0.1")

r_mismatch = ocx.run(DIST, "plan", "--output-format=json", cwd="ws")
expect.eq(r_mismatch.exit_code, MISMATCH_EXIT)
expect.eq(r_mismatch.stdout.count('"announcement_tag": "v4.5.6"'), 0)
expect.eq(r_mismatch.stdout.count('"kind": "executable-zip"'), 0)

# No Tier 4: metadata.json declares PATH only (proven by Tier 1 liveness).
