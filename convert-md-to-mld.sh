#!/bin/bash
set -e

# Convert markdown files to proper odoc format
# Usage: ./convert-md-to-mld.sh

echo "Converting markdown files to odoc format..."

# Remove existing converted files
rm -f docs/pages-*.mld

# Convert each markdown file
find docs/src -name "*.md" -type f | while read -r mdfile; do
  basename=$(basename "$mdfile")

  # Skip SUMMARY.md and README.md files
  if [ "$basename" = "SUMMARY.md" ] || [ "$basename" = "README.md" ]; then
    echo "Skipping: $mdfile"
    continue
  fi

  # Convert path to flat name with hyphens
  relpath="${mdfile#docs/src/}"
  flatname=$(echo "${relpath%.md}" | tr "/" "-")
  mldfile="docs/pages-${flatname}.mld"

  echo "Converting: $mdfile -> $mldfile"

  # Read the file and convert to odoc
  {
    # Get title from first line or filename
    title=$(head -1 "$mdfile" | sed 's/^# //')
    if [ -z "$title" ]; then
      title=$(basename "$mdfile" .md)
    fi

    echo "{0 $title}"
    echo ""

    # Convert markdown to odoc format
    tail -n +2 "$mdfile" | sed -E \
      -e 's/^# (.+)/{1 \1}/' \
      -e 's/^## (.+)/{2 \1}/' \
      -e 's/^### (.+)/{3 \1}/' \
      -e 's/^#### (.+)/{4 \1}/' \
      -e 's/^```ocaml/{[/' \
      -e 's/^```/]}/' \
      -e 's/`([^`]+)`/[\1]/g'
  } > "$mldfile"
done

# Generate dune file
echo "Generating docs/dune..."
{
  echo "(documentation"
  echo " (package neo4j_eio)"
  echo " (mld_files"
  echo "  index pipelines extractors transactions streaming best-practices"
  find docs -name "pages-*.mld" -type f | sort | while read f; do
    pagename=$(basename "$f" .mld)
    echo "  $pagename"
  done
  echo " ))"
} > docs/dune

echo "Done! Generated $(find docs -name 'pages-*.mld' | wc -l) page files"
