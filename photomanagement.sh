#!/bin/bash

# photomanagement.sh
# Copies photos/videos to STAGE1 (flat backup) and STAGE2 (organized) directories
# STAGE1: Pristine backup with original filenames (no organization)
# STAGE2: Organized by date with optional EXIF handling
# Usage: ./photomanagement.sh [--dry-run] [--source <dir>] [--stage1 <dir>] [--stage2 <dir>] [pattern]
# Example: ./photomanagement.sh --dry-run --source ./photos --stage1 ./STAGE1 --stage2 ./STAGE2 "*.jpg"

set -e  # Exit on error

# Get the directory where this script is located (handle symlinks)
SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ -L "$SCRIPT_PATH" ]]; then
    # Resolve symlink to actual file
    SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH")"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Load all modules
source "$SCRIPT_DIR/module/load_modules.sh"

# Default values
DRY_RUN=false
SOURCE_DIR="."
STAGE1_DIR=""  # Optional - only used if --stage1 is provided
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
MAX_FILES=""  # Optional - limit number of files to process

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
    --stage1 <dir>         STAGE1 destination - flat backup (optional, not used if omitted)
    --stage2 <dir>         STAGE2 destination - organized (default: ./STAGE2)
    --organize-by-date     Organize STAGE2 files into YYYY/MM subdirectories
    --use-exif-date        Use EXIF date for STAGE2 organization (requires exiftool)
    --verify               Verify copied files using MD5 checksums
    --log <file>           Write detailed log to specified file
    --structured-log <file> Write structured log with filename mappings and date tags
    --progress             Show progress bar during copy operations
    --quiet                Suppress verbose output
    --set-remark <text>    Set remark/comment for files (stored in EXIF ImageDescription and UserComment)
    --get-remark           Display remark/comment for files
    --show-remark          Show remarks when processing files
    --move                 Move files instead of copying (delete source after successful copy to both stages)
    --limit <number>       Limit the number of files to process (useful for testing)
    -h, --help             Show this help message

PATTERN:
    File pattern to match (default: all supported files)
    Examples: "*.jpg", "*.JPG", "20231225_*.jpg"

EXAMPLES:
    # Dry run - see what would be copied
    $0 --dry-run

    # Basic: Copy to STAGE2 only (flat)
    $0 --source /path/to/photos

    # Copy to STAGE1 (flat) and STAGE2 (flat)
    $0 --source /path/to/photos --stage1 ./STAGE1

    # Copy to STAGE1 (flat) and organize STAGE2 by date from filename
    $0 --organize-by-date "*.JPG" --stage1 ./STAGE1

    # Copy to STAGE1 (flat) and organize STAGE2 by EXIF date with verification
    $0 --organize-by-date --use-exif-date --verify --stage1 ./STAGE1

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

    # Process only first 10 files (useful for testing)
    $0 --source /path/to/photos --limit 10

WORKFLOW:
    1. Files are copied to STAGE1 maintaining original filenames (pristine backup) - OPTIONAL
    2. Files are copied to STAGE2 and renamed to YYYYMMDD_HHMMSS.ext based on EXIF CreateDate
    3. STAGE2 files can be organized into YYYY/MM subdirectories (optional)
    4. Filename mappings (original → new) are logged
    5. Both stages preserve original timestamps
    6. STAGE1 = backup (optional), STAGE2 = working/organized copy with standardized names

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
        --structured-log)
            STRUCTURED_LOG_FILE="$2"
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
        --limit)
            MAX_FILES="$2"
            # Validate that MAX_FILES is a positive integer
            if ! [[ "$MAX_FILES" =~ ^[1-9][0-9]*$ ]]; then
                print_error "Invalid limit value: '$MAX_FILES'. Must be a positive integer."
                exit 1
            fi
            shift 2
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

# Initialize structured log file (CSV format)
if [[ -n "$STRUCTURED_LOG_FILE" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
        # Write CSV header to structured log file
        echo "Source_filename,[EXIF]ModifyDate,[EXIF]DateTimeOriginal,[EXIF]CreateDate,[Composite]SubSecCreateDate,[Composite]SubSecDateTimeOriginal,STAGE1,STAGE2,Remark" > "$STRUCTURED_LOG_FILE"
        print_success "Structured log file: $STRUCTURED_LOG_FILE"
    else
        print_info "Would create structured log file: $STRUCTURED_LOG_FILE"
    fi
fi

# Create STAGE directories if they don't exist
if [[ "$DRY_RUN" == false ]]; then
    stage1_created=false
    stage2_created=false
    
    if [[ -n "$STAGE1_DIR" ]] && [[ ! -d "$STAGE1_DIR" ]]; then
        mkdir -p "$STAGE1_DIR"
        stage1_created=true
    fi
    
    if [[ ! -d "$STAGE2_DIR" ]]; then
        mkdir -p "$STAGE2_DIR"
        stage2_created=true
    fi
    
    if [[ "$stage1_created" == true ]] || [[ "$stage2_created" == true ]]; then
        created_dirs=""
        if [[ "$stage1_created" == true ]]; then
            created_dirs="$STAGE1_DIR"
        fi
        if [[ "$stage2_created" == true ]]; then
            if [[ -n "$created_dirs" ]]; then
                created_dirs="$created_dirs and $STAGE2_DIR"
            else
                created_dirs="$STAGE2_DIR"
            fi
        fi
        print_success "Created directories: $created_dirs"
        log_message "Created directories: $created_dirs"
    fi
else
    print_info "DRY RUN MODE - No files will be copied"
    would_create=""
    if [[ -n "$STAGE1_DIR" ]]; then
        would_create="$STAGE1_DIR"
    fi
    if [[ -n "$would_create" ]]; then
        would_create="$would_create and $STAGE2_DIR"
    else
        would_create="$STAGE2_DIR"
    fi
    print_info "Would create directories: $would_create"
fi

# Function to copy file to STAGE1 (flat backup, no organization)
# Returns: 0 on success, 1 on failure, 2 on skip, 3 if STAGE1 not configured
# Sets global variable STAGE1_DEST_PATH with destination path or "Skipped" or "Not provided"
copy_to_stage1() {
    local src_file="$1"
    
    # If STAGE1_DIR is not set, skip STAGE1 processing
    if [[ -z "$STAGE1_DIR" ]]; then
        STAGE1_DEST_PATH="Not provided"
        return 3
    fi
    
    local dest_file="$STAGE1_DIR/$(basename "$src_file")"
    
    # Display remark if requested
    if [[ "$SHOW_REMARK" == true ]]; then
        display_exif_remark "$src_file"
    fi
    
    # Check if file already exists with matching checksum
    if [[ -e "$dest_file" ]]; then
        if files_same_checksum "$src_file" "$dest_file"; then
            STAGE1_DEST_PATH="Skipped"
            return 2
        fi
    fi
    
    # Try to copy (file doesn't exist or differs, so it should be copied)
    if copy_file_with_verification "$src_file" "$dest_file" false "STAGE1"; then
        # File was successfully copied (or skipped internally, but we already checked above)
        STAGE1_DEST_PATH="$dest_file"
        return 0
    else
        STAGE1_DEST_PATH=""
        return 1
    fi
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
            print_info "Skipping STAGE2 '$src_file' - identical file already exists: '$existing_file' (checksum match)"
        fi
        log_message "SKIP: Identical file exists in STAGE2 (checksum match): '$existing_file'"
        # Set STAGE2_DEST_PATH to the existing file path for CSV log
        STAGE2_DEST_PATH="$existing_file"
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
        
        # Check if filename already contains a date pattern (YYYYMMDD_HHMMSS)
        # If so, suppress warning for video files as this is expected behavior
        local filename_base="${original_filename%.*}"
        local suppress_warning=false
        
        if is_video_file "$src_file"; then
            # Check if filename matches YYYYMMDD_HHMMSS pattern
            if [[ $filename_base =~ ^[0-9]{8}_[0-9]{6} ]]; then
                suppress_warning=true
            fi
        fi
        
        if [[ "$suppress_warning" == false ]]; then
            # For video files, this is often expected (many video formats don't have EXIF CreateDate)
            # Make the message less alarming for video files
            if is_video_file "$src_file"; then
                if [[ "$VERBOSE" == true ]]; then
                    print_info "Video file '$src_file' - no creation date in metadata, using original filename"
                fi
                log_message "INFO: Video file '$src_file' - no creation date in metadata, using original filename"
            else
                print_warning "Could not get EXIF CreateDate for '$src_file', using original filename"
                log_message "WARNING: Could not get EXIF CreateDate for '$src_file', using original filename"
            fi
        elif [[ "$VERBOSE" == true ]]; then
            # For video files with date in filename, just log it without warning
            log_message "INFO: Using original filename for video file '$src_file' (date already in filename)"
        fi
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
    
    # Copy file and set STAGE2_DEST_PATH
    # Note: We already checked for identical files above, so this should copy
    if copy_file_with_verification "$src_file" "$dest_file" "$VERIFY_COPY" "STAGE2"; then
        STAGE2_DEST_PATH="$dest_file"
        return 0
    else
        STAGE2_DEST_PATH=""
        return 1
    fi
}

# Main processing
print_info "Starting photo management process..."
print_info "Source: $SOURCE_DIR"
print_info "Pattern: $PATTERN"
if [[ -n "$STAGE1_DIR" ]]; then
    print_info "STAGE1: $STAGE1_DIR (flat backup - original filenames preserved)"
else
    print_info "STAGE1: Not configured (skipped)"
fi
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
    if [[ -n "$STAGE1_DIR" ]]; then
        print_info "Mode: MOVE (source files will be deleted after successful copy to both stages)"
    else
        print_info "Mode: MOVE (source files will be deleted after successful copy to STAGE2)"
    fi
else
    print_info "Mode: COPY (source files will be preserved)"
fi
echo ""

log_message "Starting photo management process"
log_message "Source: $SOURCE_DIR"
log_message "Pattern: $PATTERN"
if [[ -n "$STAGE1_DIR" ]]; then
    log_message "STAGE1: $STAGE1_DIR (flat backup)"
else
    log_message "STAGE1: Not configured (skipped)"
fi
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
    processed_count=0
    
    for file in "${found_files[@]}"; do
        if [[ -z "$file" ]]; then
            continue
        fi
        
        # Check limit if set
        if [[ -n "$MAX_FILES" ]] && [[ $processed_count -ge $MAX_FILES ]]; then
            break
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
        
        ((processed_count++))
    done
    
    echo ""
    print_info "========================================="
    print_info "REMARK SUMMARY"
    print_info "========================================="
    if [[ -n "$MAX_FILES" ]] && [[ ${#found_files[@]} -gt $MAX_FILES ]] && [[ $processed_count -ge $MAX_FILES ]]; then
        print_info "Total files processed: $processed_count (limited from ${#found_files[@]})"
    else
        print_info "Total files processed: $processed_count"
    fi
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

# Apply limit if set
if [[ -n "$MAX_FILES" ]] && [[ $file_count -gt $MAX_FILES ]]; then
    print_info "Found $file_count files, limiting to $MAX_FILES files"
    log_message "Found $file_count files, limiting to $MAX_FILES files"
    file_count=$MAX_FILES
else
    print_info "Found $file_count files to process"
    log_message "Found $file_count files to process"
fi
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
    
    # Check limit if set
    if [[ -n "$MAX_FILES" ]] && [[ $current_file -ge $MAX_FILES ]]; then
        if [[ "$VERBOSE" == true ]]; then
            print_info "Reached limit of $MAX_FILES files, stopping processing"
        fi
        log_message "Reached limit of $MAX_FILES files, stopping processing"
        break
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

    # Copy to STAGE1 (flat backup) - only if STAGE1_DIR is configured
    stage1_success=false
    stage2_success=false
    STAGE1_DEST_PATH=""
    STAGE2_DEST_PATH=""

    if [[ -n "$STAGE1_DIR" ]]; then
        copy_to_stage1 "$file"
        stage1_result=$?
        
        if [[ $stage1_result -eq 0 ]]; then
            stage1_success=true
        elif [[ $stage1_result -eq 2 ]]; then
            # Skipped in STAGE1 (already exists)
            stage1_success=false
            ((skipped_files++))
        elif [[ $stage1_result -eq 3 ]]; then
            # STAGE1 not configured - this shouldn't happen if we check above, but handle it
            stage1_success=false
        else
            # Failed to copy to STAGE1
            stage1_success=false
            ((failed_files++))
            log_message "ERROR: Failed to copy to STAGE1: '$file'"
        fi
    else
        # STAGE1 not configured - mark as not provided
        STAGE1_DEST_PATH="Not provided"
        stage1_result=3
    fi
    
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
        
        # Move mode: delete source file after successful copy to STAGE2 (and STAGE1 if configured)
        if [[ "$MOVE_MODE" == true ]]; then
            # Only delete source if STAGE2 succeeded and (STAGE1 succeeded or STAGE1 not configured)
            should_delete=false
            if [[ -n "$STAGE1_DIR" ]]; then
                # STAGE1 is configured - require both stages to succeed
                if [[ $stage1_result -eq 0 ]] && [[ $stage2_result -eq 0 ]]; then
                    should_delete=true
                fi
            else
                # STAGE1 not configured - only require STAGE2 to succeed
                if [[ $stage2_result -eq 0 ]]; then
                    should_delete=true
                fi
            fi
            
            if [[ "$should_delete" == true ]]; then
                if [[ "$DRY_RUN" == true ]]; then
                    print_info "Would move (delete source): '$file'"
                    log_message "DRY RUN: Would move (delete source) '$file'"
                else
                    if rm -f "$file"; then
                        print_success "Moved (deleted source): '$file'"
                        log_message "MOVED: Deleted source file '$file' after successful copy"
                    else
                        print_error "Failed to delete source file: '$file'"
                        log_message "ERROR: Failed to delete source file '$file'"
                        ((failed_files++))
                    fi
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
    
    # Write CSV log entry if structured log is enabled
    if [[ -n "$STRUCTURED_LOG_FILE" ]] && [[ "$DRY_RUN" == false ]]; then
        # Get all CSV EXIF tags
        csv_tags=$(get_csv_exif_tags "$file")
        
        # Get remark if available
        remark=$(get_exif_remark "$file")
        [[ -z "$remark" ]] && remark=""
        
        # Set STAGE1 path (use "Not provided" if STAGE1_DIR not configured, "Skipped" if skipped, or path if copied)
        if [[ -z "$STAGE1_DIR" ]]; then
            stage1_path="Not provided"
        else
            stage1_path="${STAGE1_DEST_PATH:-Skipped}"
            if [[ -z "$stage1_path" ]]; then
                stage1_path="Skipped"
            fi
        fi
        
        # Set STAGE2 path (use "Skipped" if not set or empty)
        stage2_path="${STAGE2_DEST_PATH:-Skipped}"
        if [[ -z "$stage2_path" ]]; then
            stage2_path="Skipped"
        fi
        
        # Write CSV line: Source_filename,EXIF_tags,STAGE1,STAGE2,Remark
        echo "${file},${csv_tags},${stage1_path},${stage2_path},${remark}" >> "$STRUCTURED_LOG_FILE"
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

# Close structured log file
if [[ -n "$STRUCTURED_LOG_FILE" ]] && [[ "$DRY_RUN" == false ]]; then
    print_success "Structured log file saved to: $STRUCTURED_LOG_FILE"
    print_info "Structured log contains: Source File Name | Date Tags | Final File Name"
fi

exit 0
