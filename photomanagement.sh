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
source "$SCRIPT_DIR/lib/load_modules.sh"

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

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [PATTERN]

Copy photos/videos to STAGE1 (flat backup) and STAGE2 (organized) directories.

STAGE1: Pristine backup with original filenames (no organization)
STAGE2: Organized by date with optional EXIF handling and verification

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
    2. Files are copied to STAGE2 with optional date organization
    3. Both stages preserve original timestamps
    4. STAGE1 = backup, STAGE2 = working/organized copy

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

# Check for exiftool if needed
if [[ "$USE_EXIF_DATE" == true ]]; then
    if ! check_exiftool; then
        exit 1
    fi
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

# Function to copy file to STAGE2 (with optional organization)
copy_to_stage2() {
    local src_file="$1"
    local dest_base_dir="$STAGE2_DIR"
    local dest_dir="$dest_base_dir"
    local subdir=""

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

    local dest_file="$dest_dir/$(basename "$src_file")"
    copy_file_with_verification "$src_file" "$dest_file" "$VERIFY_COPY"
}

# Main processing
print_info "Starting photo management process..."
print_info "Source: $SOURCE_DIR"
print_info "Pattern: $PATTERN"
print_info "STAGE1: $STAGE1_DIR (flat backup - no organization)"
print_info "STAGE2: $STAGE2_DIR (working copy)"
if [[ "$ORGANIZE_BY_DATE" == true ]]; then
    print_info "STAGE2 Organization: By date (YYYY/MM)"
    if [[ "$USE_EXIF_DATE" == true ]]; then
        print_info "Date source: EXIF metadata (with filename fallback)"
    else
        print_info "Date source: Filename"
    fi
else
    print_info "STAGE2 Organization: Flat (same as STAGE1)"
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

# First, count total files for progress reporting
file_count=0
if [[ "$SHOW_PROGRESS" == true ]]; then
    print_info "Counting files..."
    while IFS= read -r file; do
        [[ -n "$file" ]] && ((file_count++))
    done < <(find_files "$PATTERN" "$SOURCE_DIR")
    print_info "Found $file_count files to process"
    log_message "Found $file_count files to process"
fi

# Process files
current_file=0
while IFS= read -r file; do
    if [[ -z "$file" ]]; then
        continue
    fi
    
    ((total_files++))
    ((current_file++))

    # Show progress
    if [[ "$SHOW_PROGRESS" == true && -n "$file_count" && $file_count -gt 0 ]]; then
        progress=$((current_file * 100 / file_count))
        printf "\rProgress: [%-50s] %d%% (%d/%d)" $(printf '#%.0s' $(seq 1 $((progress / 2)))) $progress $current_file $file_count
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

# Clear progress line if shown
if [[ "$SHOW_PROGRESS" == true ]]; then
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
