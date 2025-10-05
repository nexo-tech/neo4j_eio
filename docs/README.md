# Documentation

This directory contains the odoc documentation source files for neo4j_eio.

## Building Documentation Locally

To build the documentation:

```bash
dune build @doc
```

The generated HTML will be in `_build/default/_doc/_html/`.

To view the documentation:

```bash
# Open the main index
open _build/default/_doc/_html/neo4j_eio/index.html
```

Or start a local server:

```bash
cd _build/default/_doc/_html
python3 -m http.server 8080
# Then open http://localhost:8080/neo4j_eio/
```

## Documentation Structure

- `index.mld` - Main documentation page with overview, installation, quick start, and examples
- `pipelines.mld` - Cypher pipeline API guide
- `extractors.mld` - Data extraction guide
- `transactions.mld` - Transaction management guide
- `streaming.mld` - Streaming results guide
- `best-practices.mld` - Best practices and patterns
- `dune` - Dune configuration for documentation

## Writing Documentation

The documentation uses odoc markup language (.mld files):

### Basic Syntax

```
{0 Page Title}

{1 Section}
{2 Subsection}
{3 Subsubsection}

Regular text with {i italics}, {b bold}, and [inline code].

{[
  (* Code blocks *)
  let example = "code"
]}

{v
Verbatim text
v}

- Bullet lists
- Item 2

+ Numbered lists
+ Item 2
```

### Links

```
{!ModuleName} - Link to module
{!ModuleName.function} - Link to function
{{!page-"page-name"}Link text} - Link to another page
{{:https://example.com}External link}
```

## GitHub Pages

Documentation is automatically built and deployed to GitHub Pages when pushing to the `dev` branch.

The workflow is defined in `.github/workflows/docs.yml`.

## Migration from mdBook

The previous mdBook documentation has been migrated to odoc. The original markdown files are preserved in `src/` for reference, but the canonical documentation is now the odoc-generated pages.

Key differences:
- mdBook used markdown (.md) files
- odoc uses .mld files with a slightly different syntax
- odoc integrates directly with OCaml module documentation
- odoc provides automatic API reference generation from source code
