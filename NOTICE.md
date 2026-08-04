# NOTICE

This repository packages and redistributes upstream software published by
[Axo Developer Co](https://axo.dev) ([axodotdev](https://github.com/axodotdev)).
The Apache-2.0 license in [`LICENSE`](LICENSE) covers the OCX pipeline files
authored here. It does **not** cover any upstream-derived asset — each
package's redistributed bytes carry their own license, recorded below.

Each package's logo is an original mark authored for this catalog, not an
upstream trademark; see the comment in `cargo-dist/logo.svg`. Upstream names
remain the property of their respective owners and no endorsement is implied.

| Package | GHCR path | Upstream SPDX |
|---|---|---|
| `cargo-dist` | `ghcr.io/ocx-contrib/axodotdev/cargo-dist` | `MIT OR Apache-2.0` |

---

## `cargo-dist`

Upstream: <https://github.com/axodotdev/cargo-dist>
Published to `ghcr.io/ocx-contrib/axodotdev/cargo-dist`.

| Component | SPDX | Holder |
|---|---|---|
| cargo-dist (`dist`) | **MIT OR Apache-2.0** | Axo Developer Co and the cargo-dist contributors |

The license is a **dual grant**, and the full expression is what is recorded
here and in the package's `org.opencontainers.image.licenses` annotation. The
GitHub license API reports only `Apache-2.0` for this repository — that is a
single-license detector artifact, not the grant:

```
$ gh api repos/axodotdev/cargo-dist/license --jq '.license.spdx_id'
Apache-2.0
$ gh api repos/axodotdev/cargo-dist/contents/Cargo.toml --jq .content \
    | base64 -d | grep '^license'
license = "MIT OR Apache-2.0"
```

Both `LICENSE-APACHE` and `LICENSE-MIT` exist at the repository root **and**
inside every release archive this mirror republishes.

Either license alone permits redistribution of the binary form. Under the MIT
license that requires only that the copyright notice and permission notice
accompany the software; under Apache-2.0 §4 it requires that recipients receive
a copy of the license, that existing copyright, patent, trademark and
attribution notices are retained, and that modified files are marked as
changed. All of those conditions are met without further action here: the
mirrored archives each ship upstream's own `LICENSE-MIT` and `LICENSE-APACHE`
at their root, republished unmodified, and nothing in any archive is altered.
The published binaries statically link third-party Rust crates under permissive
licenses, enumerated in upstream's `Cargo.lock`.

No modifications are made to any upstream artifact in this repository; they are
republished byte-for-byte inside an OCX bundle.
