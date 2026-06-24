# satisfactory-server

Satisfactory dedicated server image (steamcmd base + `ficsit-cli` for mods).
Published to GitHub Container Registry as `ghcr.io/rake-pro/satisfactory-server`.

## CI

`.github/workflows/build.yml` builds and pushes on push to `main` (and builds,
without pushing, on PRs). It tags the linux/amd64 image:

- `ghcr.io/rake-pro/satisfactory-server:sha-<short>` (immutable, pin this in GitOps)
- `ghcr.io/rake-pro/satisfactory-server:latest`

Auth uses the built-in `GITHUB_TOKEN` (`packages: write`) - no registry secrets.

The build moved out of the `Rake-Pro/GitOps-ArgoCD` monorepo
(`custom-images/satisfactory-server`) into this dedicated repo; the image name is
unchanged, so existing cluster references continue to work.
