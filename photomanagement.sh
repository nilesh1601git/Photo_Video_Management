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
SET_REMARK=""
GET_REMARK=false
SHOW_REMARK=false
MOVE_MODE=false

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
    --set-remark <text>    Set remark/comment for files (stored in EXIF ImageDescription and UserComment)
    --get-remark           Display remark/comment for files
    --show-remark          Show remarks when processing files
    --move                 Move files instead of copying (delete source after successful copy to both stages)
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

    # Set remark for all files
    $0 --set-remark "Family vacation 2024" --source /path/to/photos

    # Display remarks for all files
    $0 --get-remark --source /path/to/photos

    # Display remarks for specific pattern
    $0 --get-remark --source /path/to/photos "*.jpg"

    # Show remarks when processing files
    $0 --source /path/to/photos --show-remark

    # Move files instead of copying (delete source after successful copy)
    $0 --move --source /path/to/photos

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
        --set-remark)
            SET_REMARK="$2"
            shift 2
            ;;
        --get-remark)
            GET_REMARK=true
            shift
            ;;
        --show-remark)
            SHOW_REMARK=true
            shift
            ;;
        --move)
            MOVE_MODE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            # For get-remark mode, only set PATTERN from the first non-option argument
            # When glob expands (e.g., TEST_DATA/*), multiple args are passed but we only need the first
            if [[ "$GET_REMARK" == true ]]; then
                # Only set PATTERN if it's not already set (first argument)
                if [[ -z "$PATTERN" ]] || [[ "$PATTERN" == "*" ]]; then
                    PATTERN="$1"
                fi
            else
                PATTERN="$1"
            fi
            shift
            ;;
    esac
done

# Validate source directory (skip if in get-remark mode, will be handled there)
if [[ "$GET_REMARK" != true ]]; then
    if [[ ! -d "$SOURCE_DIR" ]]; then
        print_error "Source directory '$SOURCE_DIR' does not exist."
        exit 1
    fi
fi

# Check for exiftool (required for STAGE2 renaming, setting/getting remarks, and EXIF operations)
# Only check if not in get-remark-only mode (get-remark will check itself)
if [[ "$GET_REMARK" != true ]]; then
    if ! check_exiftool; then
        print_error "exiftool is required for STAGE2 file renaming but not found."
        print_info "Install it with: sudo apt-get install libimage-exiftool-perl (Debian/Ubuntu)"
        print_info "Or: brew install exiftool (macOS)"
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
    
    # Display remark if requested
    if [[ "$SHOW_REMARK" == true ]]; then
        display_exif_remark "$src_file"
    fi
    
    copy_file_with_verification "$src_file" "$dest_file" false "STAGE1"
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

    # Display all date-related EXIF tags before processing
    if [[ "$VERBOSE" == true ]]; then
        display_all_date_tags "$src_file"
    fi

    # Display remark if requested
    if [[ "$SHOW_REMARK" == true ]]; then
        display_exif_remark "$src_file"
    fi

    # Check if a file with matching checksum already exists in STAGE2
    # This prevents creating duplicate files with different names (e.g., _001 suffix)
    local existing_file=$(find_file_with_matching_checksum "$src_file" "$dest_base_dir")
    if [[ -n "$existing_file" ]]; then
        if [[ "$VERBOSE" == true ]]; then
            print_warning "Skipping STAGE2 '$src_file' - identical file already exists: '$existing_file' (checksum match)"
        fi
        log_message "SKIP: Identical file exists in STAGE2 (checksum match): '$existing_file'"
        # Return 2 to indicate skipped (not an error, but not copied either)
        # This prevents move mode from deleting source when file wasn't actually copied
        return 2
    fi

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
        print_warning "Duplicate filename detected in STAGE2, using: '$final_filename'"
        log_message "WARNING: Duplicate filename detected in STAGE2, using: '$final_filename'"
    fi
    
    local dest_file="$dest_dir/$final_filename"
    
    # Log filename mapping
    if [[ "$original_filename" != "$final_filename" ]]; then
        print_info "Filename mapping: '$original_filename' → '$final_filename'"
        log_message "FILENAME MAPPING: '$original_filename' → '$final_filename'"
    else
        log_message "FILENAME MAPPING: '$original_filename' → '$final_filename' (no change)"
    fi
    
    copy_file_with_verification "$src_file" "$dest_file" "$VERIFY_COPY" "STAGE2"
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
if [[ "$MOVE_MODE" == true ]]; then
    print_info "Mode: MOVE (source files will be deleted after successful copy to both stages)"
else
    print_info "Mode: COPY (source files will be preserved)"
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
log_message "Move mode: $MOVE_MODE"

# Handle --get-remark mode: just display remarks without copying
if [[ "$GET_REMARK" == true ]]; then
    # Check for exiftool for get-remark mode
    if ! check_exiftool; then
        print_error "exiftool is required for reading remarks but not found."
        print_info "Install it with: sudo apt-get install libimage-exiftool-perl (Debian/Ubuntu)"
        print_info "Or: brew install exiftool (macOS)"
        exit 1
    fi
    
    # Handle path arguments - could be directory, file, or pattern with directory
    # When glob pattern is expanded by shell (e.g., TEST_DATA/*), PATTERN may contain paths
    # When TEST_DATA/* expands, we get multiple arguments, but only the first one is in PATTERN
    # We need to detect the common parent directory and process all files in it
    
    # If PATTERN contains a path (has /), extract the directory
    if [[ "$PATTERN" == */* ]]; then
        dir_part=$(dirname "$PATTERN")
        pattern_part=$(basename "$PATTERN")
        
        # When glob expands (e.g., TEST_DATA/*), we want to process all files in the parent directory
        # So if we see a path like TEST_DATA/IMG_0013.JPG or TEST_DATA/STAGE2, use TEST_DATA as source
        if [[ -d "$dir_part" ]]; then
            # Use the directory as source, and process all files in it
            # This handles glob expansion: when TEST_DATA/* expands to multiple files,
            # we process all files in TEST_DATA/ not just the first one
            SOURCE_DIR="$dir_part"
            PATTERN="*"
        # Check if PATTERN itself is a directory
        elif [[ -d "$PATTERN" ]]; then
            SOURCE_DIR="$PATTERN"
            PATTERN="*"
        # Check if PATTERN is a file
        elif [[ -f "$PATTERN" ]]; then
            SOURCE_DIR="$dir_part"
            PATTERN="$pattern_part"
        fi
    # If PATTERN doesn't have a path, check if SOURCE_DIR is a file
    elif [[ -f "$SOURCE_DIR" ]]; then
        file_path="$SOURCE_DIR"
        SOURCE_DIR="$(dirname "$file_path")"
        PATTERN="$(basename "$file_path")"
    fi
    
    # Normalize source directory path
    if [[ ! -d "$SOURCE_DIR" ]]; then
        print_error "Source directory '$SOURCE_DIR' does not exist."
        exit 1
    fi
    SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
    
    print_info "Displaying remarks for files in: $SOURCE_DIR"
    print_info "Pattern: $PATTERN"
    echo ""
    
    # Use a temporary file to avoid issues with set -e and process substitution
    temp_file_list=$(mktemp)
    find_files "$PATTERN" "$SOURCE_DIR" > "$temp_file_list" || true
    mapfile -t found_files < "$temp_file_list"
    rm -f "$temp_file_list"
    
    files_with_remarks=0
    files_without_remarks=0
    
    for file in "${found_files[@]}"; do
        if [[ -z "$file" ]]; then
            continue
        fi
        
        filename=$(basename "$file")
        remark=$(get_exif_remark "$file")
        
        if [[ -n "$remark" ]]; then
            print_info "$filename: $remark"
            ((files_with_remarks++))
        else
            if [[ "$VERBOSE" == true ]]; then
                print_warning "$filename: No remark found"
            fi
            ((files_without_remarks++))
        fi
    done
    
    echo ""
    print_info "========================================="
    print_info "REMARK SUMMARY"
    print_info "========================================="
    print_info "Total files processed: ${#found_files[@]}"
    print_success "Files with remarks: $files_with_remarks"
    if [[ $files_without_remarks -gt 0 ]]; then
        print_warning "Files without remarks: $files_without_remarks"
    fi
    print_info "========================================="
    
    exit 0
fi

# Normalize source directory path (for non-get-remark mode)
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
# Use a temporary file to avoid issues with set -e and process substitution
temp_file_list=$(mktemp)
find_files "$PATTERN" "$SOURCE_DIR" > "$temp_file_list" || true
mapfile -t found_files < "$temp_file_list"
rm -f "$temp_file_list"
for file in "${found_files[@]}"; do
    [[ -n "$file" ]] && ((file_count++))
done
print_info "Found $file_count files to process"
log_message "Found $file_count files to process"
echo ""

# Process files
current_file=0
# Use a temporary file to avoid issues with set -e and process substitution
temp_file_list=$(mktemp)
find_files "$PATTERN" "$SOURCE_DIR" > "$temp_file_list" || true
mapfile -t files_to_process < "$temp_file_list"
rm -f "$temp_file_list"

# Set progress mode flag so print functions clear progress bar
IN_PROGRESS_MODE=true

for file in "${files_to_process[@]}"; do
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

    # Set remark if requested (before copying so it's preserved in both stages)
    if [[ -n "$SET_REMARK" ]]; then
        set_exif_remark "$file" "$SET_REMARK" "$DRY_RUN"
    fi

    # Copy to STAGE1 (flat backup)
    stage1_success=false
    stage2_success=false

    if copy_to_stage1 "$file"; then
        stage1_success=true
        # Copy to STAGE2 (with optional organization)
        copy_to_stage2 "$file"
        stage2_result=$?
        
        if [[ $stage2_result -eq 0 ]]; then
            # Successfully copied to STAGE2
            stage2_success=true
            ((copied_files++))
            if [[ "$VERIFY_COPY" == true ]]; then
                ((verified_files++))
            fi
            
            # Move mode: delete source file after successful copy to both stages
            if [[ "$MOVE_MODE" == true ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    print_info "Would move (delete source): '$file'"
                    log_message "DRY RUN: Would move (delete source) '$file'"
                else
                    if rm -f "$file"; then
                        print_success "Moved (deleted source): '$file'"
                        log_message "MOVED: Deleted source file '$file' after successful copy to both stages"
                    else
                        print_error "Failed to delete source file: '$file'"
                        log_message "ERROR: Failed to delete source file '$file'"
                        ((failed_files++))
                    fi
                fi
            fi
        elif [[ $stage2_result -eq 2 ]]; then
            # Skipped (file already exists in STAGE2) - don't delete source in move mode
            stage2_success=false
            ((skipped_files++))
            if [[ "$VERBOSE" == true ]]; then
                print_info "File skipped in STAGE2 (already exists), source file preserved"
            fi
            log_message "SKIP: File skipped in STAGE2, source file preserved (not deleted in move mode)"
        else
            # Failed to copy to STAGE2
            stage2_success=false
            ((failed_files++))
            log_message "ERROR: Failed to copy to STAGE2: '$file'"
        fi
    else
        ((failed_files++))
        log_message "ERROR: Failed to copy to STAGE1: '$file'"
    fi
done

# Clear progress mode flag
IN_PROGRESS_MODE=false

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
