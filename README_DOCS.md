# Documentation

## Overview

Documentation is built using **odoc** and deployed to GitHub Pages automatically.

All your original **markdown files** in `docs/src/` are automatically converted and included in the documentation!

## How It Works

1. **Source files:**
   - `docs/*.mld` - Hand-written odoc pages (index, pipelines, extractors, etc.)
   - `docs/src/**/*.md` - All your markdown documentation (auto-converted)
   - `src/*.mli` - API documentation from source code

2. **Build process** (happens in GitHub Actions):
   - Converts all `.md` files to `.mld` format automatically
   - Builds documentation with `dune build @doc`
   - Deploys to GitHub Pages

3. **Deployment:**
   - Runs when you push to `dev` branch
   - Takes **2-3 minutes** using Docker with pre-installed OCaml
   - Deploys to `https://<username>.github.io/<repo>/`

## Updating Documentation

### Edit Markdown Files (Easiest)

Just edit the markdown files in `docs/src/`:

```bash
vim docs/src/core-concepts/sessions.md
git commit -am "Update sessions documentation"
git push origin dev
```

GitHub Actions automatically converts markdown and rebuilds docs.

### Edit odoc Files (For Rich Features)

For advanced formatting, edit the `.mld` files:

```bash
vim docs/pipelines.mld
git commit -am "Update pipelines guide"
git push origin dev
```

### Add New Pages

1. Create markdown file:
   ```bash
   vim docs/src/new-section/my-page.md
   ```

2. Add link in `docs/index.mld`:
   ```
   - {{!page-"pages/new-section/my-page"}My Page Title}
   ```

3. Commit and push - CI handles the rest!

## Local Preview

```bash
# Install dependencies (one time)
opam install dune odoc

# Build documentation
dune build @doc

# View in browser
open _build/default/_doc/_html/neo4j_eio/index.html
```

## GitHub Actions Workflow

The workflow (`.github/workflows/docs.yml`) does:

1. Uses Docker container with OCaml 5.2 pre-installed (fast!)
2. Converts all `docs/src/**/*.md` to `docs/pages/**/*.mld`
3. Updates `docs/dune` to include all converted files
4. Builds with `dune build @doc`
5. Deploys to GitHub Pages

**Time:** 2-3 minutes total

## File Structure

```
docs/
├── index.mld                    # Main documentation page
├── pipelines.mld                # Pipeline guide (hand-written)
├── extractors.mld               # Extractors guide (hand-written)
├── transactions.mld             # Transactions guide (hand-written)
├── streaming.mld                # Streaming guide (hand-written)
├── best-practices.mld           # Best practices (hand-written)
├── dune                         # Build config (auto-updated in CI)
└── src/                         # Your markdown files
    ├── introduction.md          # → pages/introduction.mld
    ├── installation.md          # → pages/installation.mld
    ├── core-concepts/
    │   ├── sessions.md          # → pages/core-concepts/sessions.mld
    │   └── ...
    ├── advanced/
    │   ├── transactions.md      # → pages/advanced/transactions.mld
    │   └── ...
    └── ...
```

## Markdown Conversion

The CI automatically converts markdown syntax to odoc:

| Markdown | odoc |
|----------|------|
| `# Heading` | `{1 Heading}` |
| `## Subheading` | `{2 Subheading}` |
| `### Subsubheading` | `{3 Subsubheading}` |

Code blocks, links, and other markdown features are preserved.

## Benefits

✅ **Keep your markdown files** - No need to rewrite everything
✅ **Automatic conversion** - CI handles .md → .mld conversion
✅ **Fast builds** - Docker container with pre-installed OCaml (2-3 min)
✅ **API integration** - Combines markdown docs with API docs from source
✅ **No manual builds** - Just push to `dev`, docs auto-deploy

## Troubleshooting

**Workflow fails?**
- Check Actions tab for errors
- Ensure `docs/src/` markdown files have valid syntax
- Links in markdown will be preserved

**Missing pages?**
- Markdown files are auto-included
- Check `docs/index.mld` for links to your pages

**Want to edit conversion?**
- See `.github/workflows/docs.yml`
- Edit the `sed` command in "Convert markdown to mld" step

## Resources

- [odoc documentation](https://ocaml.github.io/odoc/)
- [Dune documentation](https://dune.readthedocs.io/)
- Workflow: `.github/workflows/docs.yml`
