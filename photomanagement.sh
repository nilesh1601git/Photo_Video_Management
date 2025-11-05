#!/bin/bash

# photomanagement.sh
# Copies photos/videos to STAGE1 (flat backup) and STAGE2 (organized) directories
# STAGE1: Pristine backup with original filenames (no organization)
# STAGE2: Organized by date with optional EXIF handling
# Usage: ./photomanagement.sh [--dry-run] [--source <dir>] [--stage1 <dir>] [--stage2 <dir>] [pattern]
# Example: ./photomanagement.sh --dry-run --source ./photos --stage1 ./STAGE1 --stage2 ./STAGE2 "*.jpg"

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all modules
source "$SCRIPT_DIR/module/load_modules.sh"

# Default values
DRY_RUN=false
SOURCE_DIR="."
STAGE1_DIR="./STAGE1"
STAGE2_DIR="./STAGE2"
PATTERN="*"
VERBOSE=true
ORGANIZE_BY_DATE=false
USE_EXIF_DATE=false
VERIFY_COPY=false
SHOW_PROGRESS=false

# Associative array to track per-timestamp counters for duplicate filenames in STAGE2
declare -A stage2_filename_counters

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [PATTERN]

Copy photos/videos to STAGE1 (flat backup) and STAGE2 (organized) directories.

STAGE1: Pristine backup with original filenames (no organization, no renaming)
STAGE2: Files renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate,
        with optional date-based directory organization and verification

OPTIONS:
    --dry-run              Show what would be copied without actually copying
    --source <dir>         Source directory (default: current directory)
    --stage1 <dir>         STAGE1 destination - flat backup (default: ./STAGE1)
    --stage2 <dir>         STAGE2 destination - organized (default: ./STAGE2)
    --organize-by-date     Organize STAGE2 files into YYYY/MM subdirectories
    --use-exif-date        Use EXIF date for STAGE2 organization (requires exiftool)
    --verify               Verify copied files using MD5 checksums
    --log <file>           Write detailed log to specified file
    --progress             Show progress bar during copy operations
    --quiet                Suppress verbose output
    -h, --help             Show this help message

PATTERN:
    File pattern to match (default: all supported files)
    Examples: "*.jpg", "*.JPG", "20231225_*.jpg"

EXAMPLES:
    # Dry run - see what would be copied
    $0 --dry-run

    # Basic: Copy to STAGE1 (flat) and STAGE2 (flat)
    $0 --source /path/to/photos

    # Copy to STAGE1 (flat) and organize STAGE2 by date from filename
    $0 --organize-by-date "*.JPG"

    # Copy to STAGE1 (flat) and organize STAGE2 by EXIF date with verification
    $0 --organize-by-date --use-exif-date --verify

    # Full featured backup with logging
    $0 --organize-by-date --use-exif-date --verify --log backup.log --progress

    # Copy specific date pattern
    $0 --organize-by-date "20231225_*.jpg"

WORKFLOW:
    1. Files are copied to STAGE1 maintaining original filenames (pristine backup)
    2. Files are copied to STAGE2 and renamed to YYYYMMDD_HHMMSS.ext based on EXIF CreateDate
    3. STAGE2 files can be organized into YYYY/MM subdirectories (optional)
    4. Filename mappings (original → new) are logged
    5. Both stages preserve original timestamps
    6. STAGE1 = backup, STAGE2 = working/organized copy with standardized names

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        --stage1)
            STAGE1_DIR="$2"
            shift 2
            ;;
        --stage2)
            STAGE2_DIR="$2"
            shift 2
            ;;
        --organize-by-date)
            ORGANIZE_BY_DATE=true
            shift
            ;;
        --use-exif-date)
            USE_EXIF_DATE=true
            shift
            ;;
        --verify)
            VERIFY_COPY=true
            shift
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
            ;;
        --progress)
            SHOW_PROGRESS=true
            shift
            ;;
        --quiet)
            VERBOSE=false
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            PATTERN="$1"
            shift
            ;;
    esac
done

# Validate source directory
if [[ ! -d "$SOURCE_DIR" ]]; then
    print_error "Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Check for exiftool (required for STAGE2 renaming based on EXIF CreateDate)
if ! check_exiftool; then
    print_error "exiftool is required for STAGE2 file renaming but not found."
    print_info "Install it with: sudo apt-get install libimage-exiftool-perl (Debian/Ubuntu)"
    print_info "Or: brew install exiftool (macOS)"
    exit 1
fi

# Initialize log file
if [[ -n "$LOG_FILE" ]]; then
    set_log_file "$LOG_FILE"
fi

# Create STAGE directories if they don't exist
if [[ "$DRY_RUN" == false ]]; then
    mkdir -p "$STAGE1_DIR"
    mkdir -p "$STAGE2_DIR"
    print_success "Created directories: $STAGE1_DIR and $STAGE2_DIR"
    log_message "Created directories: $STAGE1_DIR and $STAGE2_DIR"
else
    print_info "DRY RUN MODE - No files will be copied"
    print_info "Would create directories: $STAGE1_DIR and $STAGE2_DIR"
fi

# Function to copy file to STAGE1 (flat backup, no organization)
copy_to_stage1() {
    local src_file="$1"
    local dest_file="$STAGE1_DIR/$(basename "$src_file")"
    copy_file_with_verification "$src_file" "$dest_file" false
}

# Function to copy file to STAGE2 (with optional organization and renaming)
copy_to_stage2() {
    local src_file="$1"
    local dest_base_dir="$STAGE2_DIR"
    local dest_dir="$dest_base_dir"
    local subdir=""
    local original_filename=$(basename "$src_file")
    local new_filename=""
    local ext="${original_filename##*.}"

    # Try to get new filename from EXIF CreateDate
    local exif_formatted_date=$(format_exif_date_to_filename "$src_file")
    if [[ -n "$exif_formatted_date" ]]; then
        # Format extension to lowercase
        local ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        new_filename="${exif_formatted_date}.${ext_lower}"
    else
        # Fall back to original filename if EXIF date not available
        new_filename="$original_filename"
        print_warning "Could not get EXIF CreateDate for '$src_file', using original filename"
        log_message "WARNING: Could not get EXIF CreateDate for '$src_file', using original filename"
    fi

    # Determine subdirectory if organizing by date
    if [[ "$ORGANIZE_BY_DATE" == true ]]; then
        # Try to get date from EXIF if requested
        if [[ "$USE_EXIF_DATE" == true ]]; then
            subdir=$(get_date_path_from_exif "$src_file")
            if [[ $? -ne 0 ]]; then
                print_warning "Could not parse EXIF date for '$src_file', trying filename"
                log_message "WARNING: Could not parse EXIF date for '$src_file'"
                subdir=""
            fi
        fi

        # Fall back to filename date if EXIF didn't work
        if [[ -z "$subdir" ]]; then
            subdir=$(get_date_path_from_filename "$src_file")
            if [[ $? -ne 0 ]]; then
                print_warning "No date found for '$src_file', copying to root directory"
                log_message "WARNING: No date found for '$src_file'"
            fi
        fi

        if [[ -n "$subdir" ]]; then
            dest_dir="$dest_base_dir/$subdir"
        fi
    fi

    # Handle duplicate filenames by adding counter suffix
    local base_name="${new_filename%.*}"
    local final_filename="$new_filename"
    local ext="${new_filename##*.}"
    
    # Check if file with this name already exists in destination (or would exist in dry run)
    if [[ -e "$dest_dir/$final_filename" ]] && [[ "$dest_dir/$final_filename" != "$src_file" ]]; then
        # Initialize counter for this base name if not already done
        local counter=${stage2_filename_counters[$base_name]:-1}
        
        # Loop until a unique name is found
        while true; do
            final_filename="${base_name}_$(printf "%03d" $counter).${ext}"
            if [[ ! -e "$dest_dir/$final_filename" ]] || [[ "$DRY_RUN" == true ]]; then
                break
            fi
            ((counter++))
        done
        
        stage2_filename_counters[$base_name]=$((counter + 1))
        print_warning "Duplicate filename detected, using: '$final_filename'"
        log_message "WARNING: Duplicate filename detected, using: '$final_filename'"
    fi
    
    local dest_file="$dest_dir/$final_filename"
    
    # Log filename mapping
    if [[ "$original_filename" != "$final_filename" ]]; then
        print_info "Filename mapping: '$original_filename' → '$final_filename'"
        log_message "FILENAME MAPPING: '$original_filename' → '$final_filename'"
    else
        log_message "FILENAME MAPPING: '$original_filename' → '$final_filename' (no change)"
    fi
    
    copy_file_with_verification "$src_file" "$dest_file" "$VERIFY_COPY"
}

# Main processing
print_info "Starting photo management process..."
print_info "Source: $SOURCE_DIR"
print_info "Pattern: $PATTERN"
print_info "STAGE1: $STAGE1_DIR (flat backup - original filenames preserved)"
print_info "STAGE2: $STAGE2_DIR (renamed to YYYYMMDD_HHMMSS.ext based on EXIF CreateDate)"
if [[ "$ORGANIZE_BY_DATE" == true ]]; then
    print_info "STAGE2 Organization: By date (YYYY/MM)"
    if [[ "$USE_EXIF_DATE" == true ]]; then
        print_info "Date source: EXIF metadata (with filename fallback)"
    else
        print_info "Date source: Filename"
    fi
else
    print_info "STAGE2 Organization: Flat structure"
fi
if [[ "$VERIFY_COPY" == true ]]; then
    print_info "Verification: Enabled for STAGE2 (MD5 checksums)"
fi
echo ""

log_message "Starting photo management process"
log_message "Source: $SOURCE_DIR"
log_message "Pattern: $PATTERN"
log_message "STAGE1: $STAGE1_DIR (flat backup)"
log_message "STAGE2: $STAGE2_DIR (working copy)"
log_message "Organize by date: $ORGANIZE_BY_DATE"
log_message "Use EXIF date: $USE_EXIF_DATE"
log_message "Verify copy: $VERIFY_COPY"

# Normalize source directory path
SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"

# Counter for statistics
total_files=0
copied_files=0
skipped_files=0
failed_files=0
verified_files=0

# Count total files for progress reporting
file_count=0
print_info "Counting files..."
while IFS= read -r file; do
    [[ -n "$file" ]] && ((file_count++))
done < <(find_files "$PATTERN" "$SOURCE_DIR")
print_info "Found $file_count files to process"
log_message "Found $file_count files to process"
echo ""

# Process files
current_file=0
while IFS= read -r file; do
    if [[ -z "$file" ]]; then
        continue
    fi
    
    ((total_files++))
    ((current_file++))

    # Show progress bar
    if [[ $file_count -gt 0 ]]; then
        progress=$((current_file * 100 / file_count))
        filled=$((progress / 2))
        empty=$((50 - filled))
        
        # Create progress bar string
        bar=""
        for ((i=0; i<filled; i++)); do
            bar="${bar}█"
        done
        for ((i=0; i<empty; i++)); do
            bar="${bar}░"
        done
        
        # Print progress bar with current filename (truncated if too long)
        filename=$(basename "$file")
        if [[ ${#filename} -gt 40 ]]; then
            filename="...${filename: -37}"
        fi
        printf "\r\033[KProgress: [%s] %3d%% (%d/%d) - %s" "$bar" $progress $current_file $file_count "$filename"
    fi

    # Copy to STAGE1 (flat backup)
    stage1_success=false
    stage2_success=false

    if copy_to_stage1 "$file"; then
        stage1_success=true
        # Copy to STAGE2 (with optional organization)
        if copy_to_stage2 "$file"; then
            stage2_success=true
            ((copied_files++))
            if [[ "$VERIFY_COPY" == true ]]; then
                ((verified_files++))
            fi
        else
            ((failed_files++))
            log_message "ERROR: Failed to copy to STAGE2: '$file'"
        fi
    else
        ((failed_files++))
        log_message "ERROR: Failed to copy to STAGE1: '$file'"
    fi
done < <(find_files "$PATTERN" "$SOURCE_DIR")

# Clear progress line and show completion
if [[ $file_count -gt 0 ]]; then
    printf "\r\033[K"
    echo ""
fi

# Print summary
echo ""
print_info "========================================="
print_info "SUMMARY"
print_info "========================================="
print_info "Total files processed: $total_files"
print_success "Successfully copied: $copied_files"
if [[ "$VERIFY_COPY" == true ]]; then
    print_success "Verified copies: $verified_files"
fi
if [[ $skipped_files -gt 0 ]]; then
    print_warning "Skipped: $skipped_files"
fi
if [[ $failed_files -gt 0 ]]; then
    print_error "Failed: $failed_files"
fi
print_info "========================================="

# Log summary
log_message "========================================="
log_message "SUMMARY"
log_message "Total files processed: $total_files"
log_message "Successfully copied: $copied_files"
if [[ "$VERIFY_COPY" == true ]]; then
    log_message "Verified copies: $verified_files"
fi
log_message "Skipped: $skipped_files"
log_message "Failed: $failed_files"
log_message "========================================="

if [[ "$DRY_RUN" == true ]]; then
    print_info "This was a DRY RUN - no files were actually copied"
    log_message "DRY RUN - no files were actually copied"
fi

close_log_file

exit 0
