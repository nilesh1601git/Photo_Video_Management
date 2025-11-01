#!/bin/bash

# rename_by_createdate.sh
# Usage: rename_by_createdate.sh [--dry-run] <file>

dry_run=false

if [[ "$1" == "--dry-run" ]]; then
    dry_run=true
    shift
fi

file="$1"

if [[ ! -f "$file" ]]; then
    echo "❌ File '$file' not found."
    exit 1
fi

created=$(exiftool -s -s -s -CreateDate "$file")

if [[ -z "$created" ]]; then
    echo "❌ No CreateDate found in '$file'."
    exit 1
fi

formatted=$(echo "$created" | sed 's/[: ]//g' | cut -c1-15 | sed 's/\(........\)\(......\)/\1_\2/')
ext="${file##*.}"
ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
new_name="${formatted}.${ext_lower}"

if [[ "$file" == "$new_name" ]]; then
    echo "✅ '$file' is already correctly named."
elif [[ -e "$new_name" ]]; then
    echo "⚠️  '$new_name' already exists. Skipping rename."
else
    if $dry_run; then
        echo "🧪 Dry Run: '$file' → '$new_name'"
    else
        echo "🔄 Renaming '$file' → '$new_name'"
        mv "$file" "$new_name"
    fi
fi

