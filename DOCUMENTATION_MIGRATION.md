# Documentation Migration: mdBook → odoc

This document describes the migration from mdBook to odoc for the neo4j_eio documentation.

## Summary

The project documentation has been migrated from mdBook (markdown-based) to odoc (OCaml's native documentation generator). This provides better integration with the OCaml ecosystem and automatic API reference generation from source code.

## What Changed

### Before (mdBook)
- Documentation written in Markdown files (`docs/src/*.md`)
- Separate from API documentation
- Built with `mdbook build`
- Required mdBook installation

### After (odoc)
- Documentation written in odoc markup files (`docs/*.mld`)
- Integrated with API documentation generated from `.mli` files
- Built with `dune build @doc`
- Part of standard OCaml toolchain

## Files Created

### Documentation Files
- `docs/index.mld` - Main documentation page
- `docs/pipelines.mld` - Cypher pipeline guide
- `docs/extractors.mld` - Data extraction guide
- `docs/transactions.mld` - Transaction guide
- `docs/streaming.mld` - Streaming results guide
- `docs/best-practices.mld` - Best practices
- `docs/dune` - Dune configuration
- `docs/README.md` - Documentation build instructions

### Configuration Files
- Updated `dune-project` with package metadata
- Updated `.github/workflows/docs.yml` for odoc builds

## Building Documentation

### Locally
```bash
dune build @doc
open _build/default/_doc/_html/neo4j_eio/index.html
```

### GitHub Pages
Documentation is automatically built and deployed when pushing to the `dev` branch.

## Documentation Structure

The odoc-generated documentation includes:

1. **Main Index** (`index.mld`)
   - Overview and features
   - Installation instructions
   - Quick start examples
   - Configuration guide
   - Core and advanced module listings

2. **Topic Guides** (`.mld` files)
   - Pipelines - Query composition and transformations
   - Extractors - Type-safe data extraction
   - Transactions - ACID transaction management
   - Streaming - Large result set handling
   - Best Practices - Performance and patterns

3. **API Reference** (auto-generated from `.mli` files)
   - Module documentation
   - Function signatures with types
   - Usage examples in docstrings

## Key Features of odoc

1. **Integration**: Directly integrated with OCaml modules
2. **Type Information**: Shows actual OCaml types from source
3. **Cross-references**: Links between modules and functions work automatically
4. **Code Examples**: Syntax-highlighted OCaml code blocks
5. **Standards**: Uses standard OCaml documentation format

## Migration Notes

### Syntax Differences

| mdBook (Markdown) | odoc |
|------------------|------|
| `# Heading` | `{1 Heading}` |
| `## Subheading` | `{2 Subheading}` |
| `` `code` `` | `[code]` |
| ` ```ocaml ... ``` ` | `{[ ... ]}` |
| `[link](url)` | `{{:url}link}` |
| N/A | `{!Module}` (module link) |

### Module References

In odoc, you reference modules as:
- `{!Neo4j_eio.Module}` - Link to a module
- `{!Neo4j_eio.Module.function}` - Link to a function
- `{{!page-"name"}Text}` - Link to another documentation page

## Original mdBook Files

The original mdBook markdown files are preserved in `docs/src/` for reference, but are no longer used for documentation generation.

## Benefits of Migration

1. **Single Source**: API docs generated directly from source code
2. **Type Safety**: Documentation always matches actual types
3. **Better Navigation**: Automatic cross-linking between modules
4. **OCaml Ecosystem**: Standard tool in OCaml, no extra dependencies
5. **GitHub Pages**: Works seamlessly with GitHub Pages deployment

## Future Improvements

1. Add more code examples to `.mli` files
2. Create additional topic guides as needed
3. Add search functionality (odoc supports this)
4. Generate PDF documentation (odoc supports LaTeX output)

## Viewing Documentation

### Online
Once deployed, documentation will be available at:
https://yourusername.github.io/neo4j_eio/

### Locally
```bash
# Build
dune build @doc

# Serve with Python
cd _build/default/_doc/_html
python3 -m http.server 8080

# Open browser
open http://localhost:8080/neo4j_eio/
```

## Testing

The documentation build is tested in CI/CD:
- `.github/workflows/docs.yml` builds documentation on every push to `dev`
- Ensures documentation stays in sync with code changes
- Automatically deploys to GitHub Pages

## Resources

- [odoc Documentation](https://ocaml.github.io/odoc/)
- [odoc Syntax Guide](https://ocaml.github.io/odoc/odoc_for_authors.html)
- [Dune Documentation Rules](https://dune.readthedocs.io/en/stable/reference/dune/documentation.html)
