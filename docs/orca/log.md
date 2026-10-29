# Orca APT integration

## Publish the official Orca desktop package

The user approved this scope on 2026-10-29: add the official stablyai/orca DEB,
follow the latest stable release, update the package lists, and verify before publication.
Release v1.4.244 provides orca-ide_1.4.244_amd64.deb (182,432,380 bytes).
Upstream uses the Debian name orca-ide to avoid the GNOME screen reader's orca name.
Keep the existing amd64-only policy for GUI applications, latest-only retention,
repository URL, signing key, and daily 08:00 Asia/Shanghai schedule.
The current configuration-driven builder already implements this integration;
rebuilding or repackaging upstream binaries and changing the builder are unnecessary.

### Task: Add and validate Orca

**Change**

- [x] Add configs/orca-ide.json for stablyai/orca, matching only stable-version amd64 DEBs.
- [x] List orca-ide in README and the generated site homepage; document the install command.

**Verification**

1. [x] Download the real latest stable DEB through the existing builder; check package name,
   version, architecture, dependencies, and the GitHub asset SHA256 digest.
2. [x] Run the existing regression suite and checks on changed files; obtain independent review.
3. [x] Generate signed indexes with an isolated test key; verify that isolated APT sees
   the expected candidate and can resolve its dependencies without installing packages.

**Done**

- [x] The unchanged builder produces exactly one Orca amd64 DEB and a valid APT entry.

Local verification (2026-10-29): upstream SHA256 is
8fe4c5c3696c789d2da05e43e0cc9d95af9c1ddbf907f52b9c06203b068c4c89.
The regression suite and changed-file pre-commit checks passed. Independent review found
no blocking issues. An isolated APT update accepted the test signature and listed 1.4.244
from the local index. A fresh-install simulation with an empty package status database
resolved dependencies using the host's Ubuntu 24.04 package indexes; no packages were installed.

### Task: Publish and verify the live repository

**Change**

- [x] Commit and push the reviewed change to main to invoke the existing deployment workflow.

**Verification**

1. [x] Deployment succeeds with the production signing key and below the 950,000,000-byte limit.
2. [x] Isolated APT accepts the public repository signature and reports orca-ide as a candidate.
3. [x] The public DEB has the upstream SHA256 digest and the homepage lists Orca.

**Done**

- [x] The live repository offers the official Orca package through the existing APT source.

Production verification (2026-10-29): commit 5ac0bd097495b06d60dbc9636e86601456bb0a4a
was published by [workflow run 40874558976](https://github.com/AtticusZeller/deb-index/actions/runs/40874558976).
All workflow steps, including production InRelease verification and Pages deployment, succeeded.
The uploaded Pages artifact was 305,599,663 bytes; the site's size gate passed.
An isolated APT client accepted https://docs.atticux.me/deb-index with the existing public.key
and an empty installed-package database, reporting orca-ide candidate 1.4.244 from the public index.
APT downloaded the public 182,432,380-byte DEB and its SHA256 matched the upstream digest above.
The canonical homepage listed orca-ide (Orca IDE). The test changed no system APT sources
and installed no packages. GUI launch was not part of this repository integration's acceptance.

Sources: https://github.com/stablyai/orca/releases/tag/v1.4.244 and
https://github.com/stablyai/orca/blob/v1.4.244/config/electron-builder.config.cjs.
