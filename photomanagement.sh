#!/bin/bash

# photomanagement.sh
# Copies photos/videos to STAGE1 (flat backup) and STAGE2 (organized) directories
# STAGE1: Pristine backup with original filenames (no organization)
# STAGE2: Organized by date with optional EXIF handling
# Usage: ./photomanagement.sh [--dry-run] [--source <dir>] [--stage1 <dir>] [--stage2 <dir>] [pattern]
# Example: ./photomanagement.sh --dry-run --source ./photos --stage1 ./STAGE1 --stage2 ./STAGE2 "*.jpg"

set -e  # Exit on error

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
LOG_FILE=""
SHOW_PROGRESS=false

# Supported file extensions
SUPPORTED_EXTENSIONS=("jpg" "JPG" "jpeg" "JPEG" "png" "PNG" "avi" "AVI" "mov" "MOV" "mp4" "MP4" "m4v" "M4V")

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

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

# Function to write to log file
log_message() {
    local message="$1"
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    fi
}

# Function to calculate MD5 checksum
calculate_md5() {
    local file="$1"
    if command -v md5sum &> /dev/null; then
        md5sum "$file" | awk '{print $1}'
    elif command -v md5 &> /dev/null; then
        md5 -q "$file"
    else
        print_error "Neither md5sum nor md5 command found. Cannot verify files."
        return 1
    fi
}

# Function to extract date from EXIF data
get_exif_date() {
    local file="$1"

    if ! command -v exiftool &> /dev/null; then
        print_error "exiftool not found. Install it or use --organize-by-date without --use-exif-date"
        return 1
    fi

    # Try DateTimeOriginal first, then CreateDate, then ModifyDate
    local exif_date=$(exiftool -s -s -s -DateTimeOriginal "$file" 2>/dev/null)
    if [[ -z "$exif_date" ]]; then
        exif_date=$(exiftool -s -s -s -CreateDate "$file" 2>/dev/null)
    fi
    if [[ -z "$exif_date" ]]; then
        exif_date=$(exiftool -s -s -s -ModifyDate "$file" 2>/dev/null)
    fi

    echo "$exif_date"
}

# Function to extract date from filename (format: YYYYMMDD_HHMMSS)
get_filename_date() {
    local file="$1"
    local basename=$(basename "$file")

    # Try to extract date from filename pattern YYYYMMDD_HHMMSS
    if [[ $basename =~ ^([0-9]{8})_([0-9]{6}) ]]; then
        local date_part="${BASH_REMATCH[1]}"
        echo "${date_part:0:4}:${date_part:4:2}:${date_part:6:2}"
        return 0
    fi

    return 1
}

# Function to get year and month from date string
parse_date() {
    local date_str="$1"

    # Expected format: YYYY:MM:DD HH:MM:SS or YYYY:MM:DD
    if [[ $date_str =~ ^([0-9]{4}):([0-9]{2}):([0-9]{2}) ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        echo "${year}/${month}"
        return 0
    fi

    return 1
}

# Validate source directory
if [[ ! -d "$SOURCE_DIR" ]]; then
    print_error "Source directory '$SOURCE_DIR' does not exist."
    exit 1
fi

# Check for exiftool if needed
if [[ "$USE_EXIF_DATE" == true ]]; then
    if ! command -v exiftool &> /dev/null; then
        print_error "exiftool is required for --use-exif-date option but not found."
        print_info "Install it with: sudo apt-get install libimage-exiftool-perl (Debian/Ubuntu)"
        print_info "Or: brew install exiftool (macOS)"
        exit 1
    fi
fi

# Initialize log file
if [[ -n "$LOG_FILE" ]]; then
    if [[ "$DRY_RUN" == false ]]; then
        echo "=========================================" > "$LOG_FILE"
        echo "Photo Management Log" >> "$LOG_FILE"
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
        echo "=========================================" >> "$LOG_FILE"
        print_success "Logging to: $LOG_FILE"
    else
        print_info "Would log to: $LOG_FILE"
    fi
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
    local dest_dir="$STAGE1_DIR"
    local dest_file="$dest_dir/$(basename "$src_file")"

    if [[ ! -f "$src_file" ]]; then
        print_error "Source file '$src_file' not found"
        log_message "ERROR: Source file '$src_file' not found"
        return 1
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would copy to STAGE1: '$src_file' → '$dest_file'"
        log_message "DRY RUN: Would copy to STAGE1 '$src_file' → '$dest_file'"
        return 0
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$dest_dir"

    # Check if destination file already exists
    if [[ -e "$dest_file" ]]; then
        # Compare file sizes
        src_size=$(stat -c%s "$src_file" 2>/dev/null || stat -f%z "$src_file" 2>/dev/null)
        dest_size=$(stat -c%s "$dest_file" 2>/dev/null || stat -f%z "$dest_file" 2>/dev/null)

        if [[ "$src_size" == "$dest_size" ]]; then
            if [[ "$VERBOSE" == true ]]; then
                print_warning "Skipping STAGE1 '$src_file' - file with same size exists"
            fi
            log_message "SKIP STAGE1: File with same size exists: '$dest_file'"
            return 0
        fi

        # File exists but differs - create backup
        print_warning "STAGE1 file exists but differs: '$dest_file' - creating backup"
        backup_file="${dest_file}.backup.$(date +%s)"
        mv "$dest_file" "$backup_file"
        print_info "Backed up to: $backup_file"
        log_message "BACKUP STAGE1: Created backup '$backup_file'"
    fi

    # Copy file preserving all attributes
    if cp -p "$src_file" "$dest_file"; then
        # Additional timestamp preservation using touch
        touch -r "$src_file" "$dest_file"

        if [[ "$VERBOSE" == true ]]; then
            print_success "Copied to STAGE1: '$src_file' → '$dest_file'"
        fi
        log_message "SUCCESS STAGE1: Copied '$src_file' → '$dest_file'"
        return 0
    else
        print_error "Failed to copy to STAGE1: '$src_file' → '$dest_file'"
        log_message "ERROR STAGE1: Failed to copy '$src_file' → '$dest_file'"
        return 1
    fi
}

# Function to copy file to STAGE2 (with optional organization)
copy_to_stage2() {
    local src_file="$1"
    local dest_base_dir="$STAGE2_DIR"
    local dest_dir="$dest_base_dir"
    local subdir=""

    if [[ ! -f "$src_file" ]]; then
        print_error "Source file '$src_file' not found"
        log_message "ERROR: Source file '$src_file' not found"
        return 1
    fi

    # Determine subdirectory if organizing by date
    if [[ "$ORGANIZE_BY_DATE" == true ]]; then
        local date_str=""

        # Try to get date from EXIF if requested
        if [[ "$USE_EXIF_DATE" == true ]]; then
            date_str=$(get_exif_date "$src_file")
            if [[ -n "$date_str" ]]; then
                subdir=$(parse_date "$date_str")
                if [[ $? -ne 0 ]]; then
                    print_warning "Could not parse EXIF date for '$src_file', trying filename"
                    log_message "WARNING: Could not parse EXIF date for '$src_file'"
                    subdir=""
                fi
            fi
        fi

        # Fall back to filename date if EXIF didn't work
        if [[ -z "$subdir" ]]; then
            date_str=$(get_filename_date "$src_file")
            if [[ $? -eq 0 && -n "$date_str" ]]; then
                subdir=$(parse_date "$date_str")
                if [[ $? -ne 0 ]]; then
                    print_warning "Could not parse filename date for '$src_file', using root"
                    log_message "WARNING: Could not parse filename date for '$src_file'"
                    subdir=""
                fi
            else
                print_warning "No date found for '$src_file', copying to root directory"
                log_message "WARNING: No date found for '$src_file'"
            fi
        fi

        if [[ -n "$subdir" ]]; then
            dest_dir="$dest_base_dir/$subdir"
        fi
    fi

    local dest_file="$dest_dir/$(basename "$src_file")"

    if [[ "$DRY_RUN" == true ]]; then
        print_info "Would copy to STAGE2: '$src_file' → '$dest_file'"
        log_message "DRY RUN: Would copy to STAGE2 '$src_file' → '$dest_file'"
        return 0
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$dest_dir"

    # Check if destination file already exists
    if [[ -e "$dest_file" ]]; then
        # Compare file sizes
        src_size=$(stat -c%s "$src_file" 2>/dev/null || stat -f%z "$src_file" 2>/dev/null)
        dest_size=$(stat -c%s "$dest_file" 2>/dev/null || stat -f%z "$dest_file" 2>/dev/null)

        if [[ "$src_size" == "$dest_size" ]]; then
            # If verify is enabled, check MD5
            if [[ "$VERIFY_COPY" == true ]]; then
                src_md5=$(calculate_md5 "$src_file")
                dest_md5=$(calculate_md5 "$dest_file")
                if [[ "$src_md5" == "$dest_md5" ]]; then
                    if [[ "$VERBOSE" == true ]]; then
                        print_warning "Skipping STAGE2 '$src_file' - identical file exists (verified)"
                    fi
                    log_message "SKIP STAGE2: Identical file exists (verified): '$dest_file'"
                    return 0
                fi
            else
                if [[ "$VERBOSE" == true ]]; then
                    print_warning "Skipping STAGE2 '$src_file' - file with same size exists"
                fi
                log_message "SKIP STAGE2: File with same size exists: '$dest_file'"
                return 0
            fi
        fi

        # File exists but differs - create backup
        print_warning "STAGE2 file exists but differs: '$dest_file' - creating backup"
        backup_file="${dest_file}.backup.$(date +%s)"
        mv "$dest_file" "$backup_file"
        print_info "Backed up to: $backup_file"
        log_message "BACKUP STAGE2: Created backup '$backup_file'"
    fi

    # Copy file preserving all attributes
    if cp -p "$src_file" "$dest_file"; then
        # Additional timestamp preservation using touch
        touch -r "$src_file" "$dest_file"

        # Verify copy if requested
        if [[ "$VERIFY_COPY" == true ]]; then
            src_md5=$(calculate_md5 "$src_file")
            dest_md5=$(calculate_md5 "$dest_file")
            if [[ "$src_md5" != "$dest_md5" ]]; then
                print_error "Verification failed for STAGE2 '$dest_file' - checksums don't match!"
                log_message "ERROR STAGE2: Verification failed for '$dest_file'"
                rm -f "$dest_file"
                return 1
            fi
            if [[ "$VERBOSE" == true ]]; then
                print_success "Copied and verified to STAGE2: '$src_file' → '$dest_file'"
            fi
            log_message "SUCCESS STAGE2: Copied and verified '$src_file' → '$dest_file'"
        else
            if [[ "$VERBOSE" == true ]]; then
                print_success "Copied to STAGE2: '$src_file' → '$dest_file'"
            fi
            log_message "SUCCESS STAGE2: Copied '$src_file' → '$dest_file'"
        fi
        return 0
    else
        print_error "Failed to copy to STAGE2: '$src_file' → '$dest_file'"
        log_message "ERROR STAGE2: Failed to copy '$src_file' → '$dest_file'"
        return 1
    fi
}

# Function to check if file extension is supported
is_supported_extension() {
    local file="$1"
    local ext="${file##*.}"
    
    for supported_ext in "${SUPPORTED_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$supported_ext" ]]; then
            return 0
        fi
    done
    return 1
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

# Change to source directory
cd "$SOURCE_DIR" || exit 1

# Counter for statistics
total_files=0
copied_files=0
skipped_files=0
failed_files=0
verified_files=0

# First, count total files for progress reporting
if [[ "$SHOW_PROGRESS" == true ]]; then
    print_info "Counting files..."
    file_count=0
    for file in $PATTERN; do
        [[ -f "$file" ]] && is_supported_extension "$file" && ((file_count++))
    done
    if [[ $file_count -eq 0 && "$PATTERN" == "*" ]]; then
        for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
            for file in *."$ext"; do
                [[ -f "$file" ]] && ((file_count++))
            done
        done
    fi
    print_info "Found $file_count files to process"
    log_message "Found $file_count files to process"
fi

# Enable nullglob to handle cases where pattern matches nothing
shopt -s nullglob

# Process files matching the pattern
current_file=0
for file in $PATTERN; do
    if [[ -f "$file" ]]; then
        # Check if file extension is supported
        if ! is_supported_extension "$file"; then
            if [[ "$VERBOSE" == true ]]; then
                print_warning "Skipping unsupported file type: '$file'"
            fi
            log_message "SKIP: Unsupported file type '$file'"
            ((skipped_files++))
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
    fi
done

# If no files matched the pattern, try all supported extensions
if [[ $total_files -eq 0 && "$PATTERN" == "*" ]]; then
    print_info "No files found with pattern '$PATTERN', searching for all supported file types..."
    log_message "Searching for all supported file types"

    for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
        for file in *."$ext"; do
            if [[ -f "$file" ]]; then
                ((total_files++))
                ((current_file++))

                # Show progress
                if [[ "$SHOW_PROGRESS" == true && -n "$file_count" && $file_count -gt 0 ]]; then
                    progress=$((current_file * 100 / file_count))
                    printf "\rProgress: [%-50s] %d%% (%d/%d)" $(printf '#%.0s' $(seq 1 $((progress / 2)))) $progress $current_file $file_count
                fi

                # Copy to STAGE1 (flat backup)
                if copy_to_stage1 "$file"; then
                    # Copy to STAGE2 (with optional organization)
                    if copy_to_stage2 "$file"; then
                        ((copied_files++))
                        if [[ "$VERIFY_COPY" == true ]]; then
                            ((verified_files++))
                        fi
                    else
                        ((failed_files++))
                    fi
                else
                    ((failed_files++))
                fi
            fi
        done
    done
fi

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

if [[ -n "$LOG_FILE" ]]; then
    log_message "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
    print_success "Log file saved to: $LOG_FILE"
fi

exit 0

