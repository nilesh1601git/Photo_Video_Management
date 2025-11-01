#!/bin/bash

shopt -s nullglob

for f in *.jpg *.JPG *.AVI *.avi *.MOV *.mov *.mp4; do
    # Extract date from filename (first 8 characters)
    base=$(basename "$f")
    date_part="${base:0:8}"  # e.g., 20171126
    year="${date_part:0:4}"
    month="${date_part:4:2}"

    # Create target directory
    target_dir="${year}/${month}"
    mkdir -p "$target_dir"

    # Check if file already exists at target
    if [ -e "$target_dir/$base" ]; then
        echo "⚠️  WARNING: '$target_dir/$base' already exists. Skipping '$f'."
    else
        echo "Moving '$f' → '$target_dir/'"
        mv "$f" "$target_dir/"
    fi
done

