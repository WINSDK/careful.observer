#!/bin/bash
set -e

# Loop through all .md files in the current directory.
for md_file in ../posts/*.md; do
  # If no .md files are found, the loop will still run once with "*.md" literal
  # so we check if the file really exists.
  if [[ ! -f "$md_file" ]]; then
    break
  fi

  base_name="${md_file%.md}"
  html_file="${base_name}.html"

  echo "Converting '$md_file' to '$html_file'..."

  # Run pandoc to generate the HTML.
  pandoc "$md_file" \
         --template=template.html \
         --highlight-style=gruvbox.theme \
         --syntax-definition=rust.xml \
         --syntax-definition=ocaml.xml \
         --lua-filter=links.lua \
         --standalone \
         --output="$html_file"

  echo "Finished converting '$md_file' to '$html_file'."
done

echo "All conversions complete."
