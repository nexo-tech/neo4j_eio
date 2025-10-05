# GitHub Workflows

This directory contains GitHub Actions workflows for CI/CD.

## docs.yml - Documentation Deployment

Builds and deploys odoc documentation to GitHub Pages.

### Trigger
- Push to `dev` branch
- Manual workflow dispatch

### Process
1. Checkout code
2. Setup OCaml 5.2.x
3. Install dependencies with `opam install . --deps-only --with-doc`
4. Build documentation with `dune build @doc`
5. Copy generated HTML from `_build/default/_doc/_html/` to `_site/`
6. Upload to GitHub Pages
7. Deploy to GitHub Pages

### Output
Documentation is available at: `https://<username>.github.io/<repo>/`

### Local Testing

To test the workflow locally:

```bash
# Install dependencies
opam install . --deps-only --with-doc --yes

# Build documentation
dune build @doc

# View output
open _build/default/_doc/_html/neo4j_eio/index.html
```

### Troubleshooting

**Build fails with missing modules:**
- Check that all `.mli` files are properly documented
- Ensure `docs/dune` includes all `.mld` files
- Verify module references use `Neo4j_eio.Module` format

**Documentation not updating:**
- Ensure you're pushing to `dev` branch
- Check GitHub Actions tab for build status
- Verify GitHub Pages is enabled in repository settings

**Missing dependencies:**
- Update `dune-project` with correct dependencies
- Run `opam install . --deps-only --with-doc` locally to test

## Future Workflows

Additional workflows that could be added:

- **ci.yml** - Run tests on pull requests
- **release.yml** - Build and publish opam packages
- **benchmarks.yml** - Run performance benchmarks
