#!/bin/bash

# place_files_in_directory.sh
# Organizes files into YYYY/MM directories based on filename date
# Usage: ./place_files_in_directory.sh [--dry-run]

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/module/load_modules.sh"

# Default values
DRY_RUN=false

# Parse command line arguments
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
    shift
    ;;
    -h|--help)
        echo "Usage: $0 [--dry-run]"
        echo "Organizes files into YYYY/MM directories based on filename date (first 8 characters)"
        exit 0
        ;;
esac

shopt -s nullglob

print_info "Organizing files into date-based directories..."

for f in *.jpg *.JPG *.AVI *.avi *.MOV *.mov *.mp4; do
    if [[ ! -f "$f" ]]; then
        continue
    fi
    
    # Extract date from filename (first 8 characters)
    base=$(basename "$f")
    date_part="${base:0:8}"  # e.g., 20171126
    
    # Validate date format
    if [[ ! $date_part =~ ^[0-9]{8}$ ]]; then
        print_warning "Skipping '$f' - filename doesn't start with 8-digit date"
        continue
    fi
    
    year="${date_part:0:4}"
    month="${date_part:4:2}"

    # Create target directory
    target_dir="${year}/${month}"
    
    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would move '$f' → '$target_dir/'"
    else
        mkdir -p "$target_dir"

        # Check if file already exists at target
        if [[ -e "$target_dir/$base" ]]; then
            print_warning "WARNING: '$target_dir/$base' already exists. Skipping '$f'."
        else
            print_success "Moving '$f' → '$target_dir/'"
            mv "$f" "$target_dir/"
        fi
    fi
done

print_success "Done!"
