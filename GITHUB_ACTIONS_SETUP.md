# GitHub Actions Setup for Documentation

This document explains the GitHub Actions workflow configuration for building and deploying documentation.

## Quick Fix Applied

**Problem:** The workflow was failing with:
```
E: Package 'darcs' has no installation candidate
```

**Solution:** Changed `runs-on: ubuntu-latest` (24.04) to `runs-on: ubuntu-22.04` because darcs package is not available in Ubuntu 24.04 but is available in 22.04.

## Workflows

### 1. Documentation Deployment (`.github/workflows/docs.yml`)

Automatically builds and deploys odoc documentation to GitHub Pages.

**Triggers:**
- Push to `dev` branch
- Manual workflow dispatch

**Steps:**
1. Checkout code
2. Setup GitHub Pages
3. Setup OCaml 5.2.x on Ubuntu 22.04
4. Pin the package: `opam pin add neo4j_eio . --no-action --yes`
5. Install documentation dependencies: `opam install . --deps-only --with-doc --yes`
6. Build documentation: `dune build @doc`
7. Prepare output: Copy from `_build/default/_doc/_html/` to `_site/`
8. Upload and deploy to GitHub Pages

**Output:** Documentation available at `https://<username>.github.io/<repo>/`

### 2. CI Build (`.github/workflows/ci.yml`)

Tests building the project and documentation on every push/PR.

**Jobs:**
- **build**: Compiles the OCaml project
- **docs**: Builds documentation and checks for broken links

## Required GitHub Settings

### Enable GitHub Pages

1. Go to repository Settings → Pages
2. Source: "GitHub Actions"
3. No need to select a branch manually - the workflow handles deployment

### Permissions

The workflow already includes the required permissions:
```yaml
permissions:
  contents: read
  pages: write
  id-token: write
```

## Files Required

The following files must be present for the workflow to succeed:

- `neo4j_eio.opam` - Generated from `dune-project`
- `dune-project` - Package metadata with dependencies
- `docs/dune` - Documentation stanza
- `docs/*.mld` - Documentation source files
- `src/*.mli` - Interface files with odoc comments

## Troubleshooting

### Workflow fails with "Package not found"

**Solution:** Ensure `neo4j_eio.opam` file exists. Generate it with:
```bash
dune build neo4j_eio.opam
```

### Workflow fails with missing dependencies

**Solution:** Add dependencies to `dune-project`:
```lisp
(depends
  (ocaml (>= 5.0))
  (dune (>= 3.13))
  eio
  ...
  (odoc :with-doc)
  (alcotest :with-test))
```

Then regenerate: `dune build neo4j_eio.opam`

### Documentation has broken links

**Solution:** Check the warnings in the build output. Common issues:
- Use `Neo4j_eio.Module` not just `Module`
- Use `{{!page-"name"}Text}` for page links
- Check that all `.mld` files are listed in `docs/dune`

### Ubuntu 24.04 issues

**Problem:** Some OCaml packages require system dependencies not available in Ubuntu 24.04.

**Solution:** Use `ubuntu-22.04` in the workflow:
```yaml
runs-on: ubuntu-22.04
```

## Local Testing

Test the workflow steps locally:

```bash
# Setup (one time)
opam pin add neo4j_eio . --no-action --yes
opam install . --deps-only --with-doc --yes

# Build documentation
dune build @doc

# View output
open _build/default/_doc/_html/neo4j_eio/index.html
```

## Viewing Deployment Status

1. Go to repository → Actions tab
2. Click on "Deploy Documentation" workflow
3. View the latest run
4. Check each step for errors/warnings
5. Click "deploy" job to see the deployment URL

## Manual Deployment

To manually trigger documentation deployment:

1. Go to Actions → Deploy Documentation
2. Click "Run workflow"
3. Select `dev` branch
4. Click "Run workflow" button

## Updating Documentation

1. Edit `.mld` files in `docs/`
2. Update odoc comments in `.mli` files
3. Commit and push to `dev` branch
4. GitHub Actions automatically builds and deploys
5. Check the deployment at the GitHub Pages URL

## Advanced Configuration

### Custom Domain

To use a custom domain:

1. Add a `CNAME` file to the repository root
2. Update GitHub repository settings with the custom domain
3. The workflow will automatically include the CNAME file

### Documentation Versioning

To maintain multiple documentation versions:

1. Modify the workflow to include version in output path
2. Build docs for different tags/branches
3. Create an index page that links to different versions

### Caching

The workflow uses `dune-cache: true` to cache build artifacts between runs, speeding up builds.

## Security

The workflow uses:
- `actions/checkout@v4` - Official GitHub action
- `ocaml/setup-ocaml@v2` - Official OCaml action
- `actions/configure-pages@v4` - Official GitHub Pages action
- `actions/upload-pages-artifact@v3` - Official upload action
- `actions/deploy-pages@v4` - Official deploy action

All actions are from trusted sources.

## Resources

- [ocaml/setup-ocaml documentation](https://github.com/ocaml/setup-ocaml)
- [GitHub Pages documentation](https://docs.github.com/en/pages)
- [odoc documentation](https://ocaml.github.io/odoc/)
- [Dune documentation rules](https://dune.readthedocs.io/en/stable/reference/dune/documentation.html)
