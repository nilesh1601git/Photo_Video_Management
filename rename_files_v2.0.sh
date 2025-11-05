#!/bin/bash

# rename_files_v2.0.sh
# Renames files based on modification date/time
# Usage: ./rename_files_v2.0.sh [--dry-run]

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/lib/load_modules.sh"

# Default values
DRY_RUN=false
declare -A timestamp_counters  # associative array to track per-timestamp counters

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--dry-run]"
            echo "Renames files based on modification date/time in YYYYMMDD_HHMMSS format"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

rename_function() {
    local ext=$1

    for file in *."$ext"; do
        if [[ -f "$file" ]]; then
            # Get modification date and time in YYYYMMDD_HHMMSS format
            local datetime=$(get_file_modification_date "$file")
            local base_name="${datetime}"
            local new_name="${base_name}.$ext"

            # If file with that name already exists, use counter suffix
            if [[ -e "$new_name" ]]; then
                # Initialize counter for this timestamp if not already done
                local counter=${timestamp_counters[$base_name]:-1}

                # Loop until a unique name is found
                while true; do
                    new_name="${base_name}_$(printf "%03d" $counter).$ext"
                    if [[ ! -e "$new_name" ]]; then
                        break
                    fi
                    ((counter++))
                done

                timestamp_counters[$base_name]=$((counter + 1))
            fi

            # Final safety check to prevent overwriting
            if [[ "$DRY_RUN" == true ]]; then
                echo "Would rename: \"$file\" -> \"$new_name\""
            elif [[ ! -e "$new_name" ]]; then
                echo "Renaming: \"$file\" -> \"$new_name\""
                mv "$file" "$new_name"
            else
                echo "Skipping \"$file\" → \"$new_name\" already exists."
            fi
        fi
    done
}

# Run for all desired extensions
print_info "Starting file renaming process..."
rename_function AVI
rename_function avi
rename_function jpg
rename_function JPG
rename_function MOV
rename_function MP4
rename_function mp4
print_success "Renaming complete!"
