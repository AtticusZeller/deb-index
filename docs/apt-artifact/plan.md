# Pending production activation

Implementation and local validation are recorded in [log.md](log.md); usage is in ../../README.md.

## Publish the verified migration

Current Git credentials belong to Hubo1231 and cannot push to AtticusZeller/deb-index (HTTP 403).
The GitHub API also reports push=false/admin=false. Pages remains configured for legacy deployment.

### Task: Activate Pages Artifact in production

**Change**

- [ ] Use credentials with repository write and Pages administration permissions.
- [ ] Push the local migration commit to main.
- [ ] Change Settings → Pages → Source to GitHub Actions; run Update APT Repository.

**Verification**

1. [ ] Workflow succeeds, including InRelease verification with existing public.key.
2. [ ] Public site exposes signed indexes and the two latest GUI-package downloads (amd64 SFL and alacritty).
3. [ ] A client using the production key can apt update and see the new SFL candidate.

**Done**

- [ ] Production repository serves current SFL and the other latest stable packages via Pages Artifact.
