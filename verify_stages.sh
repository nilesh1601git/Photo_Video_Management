#!/bin/bash

# verify_stages.sh
# Verify that files in STAGE1 and STAGE2 are identical
# Usage: ./verify_stages.sh [--stage1 <dir>] [--stage2 <dir>] [--log <file>]

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load modules
source "$SCRIPT_DIR/lib/load_modules.sh"

# Default values
STAGE1_DIR="./STAGE1"
STAGE2_DIR="./STAGE2"
VERBOSE=true

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Verify that files in STAGE1 and STAGE2 directories are identical.

OPTIONS:
    --stage1 <dir>         STAGE1 directory (default: ./STAGE1)
    --stage2 <dir>         STAGE2 directory (default: ./STAGE2)
    --log <file>           Write detailed log to specified file
    --quiet                Suppress verbose output
    -h, --help             Show this help message

EXAMPLES:
    # Verify default STAGE1 and STAGE2 directories
    $0

    # Verify custom directories
    $0 --stage1 /backup/STAGE1 --stage2 /backup/STAGE2

    # Verify with logging
    $0 --log verification.log

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --stage1)
            STAGE1_DIR="$2"
            shift 2
            ;;
        --stage2)
            STAGE2_DIR="$2"
            shift 2
            ;;
        --log)
            LOG_FILE="$2"
            shift 2
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
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate directories
if [[ ! -d "$STAGE1_DIR" ]]; then
    print_error "STAGE1 directory '$STAGE1_DIR' does not exist."
    exit 1
fi

if [[ ! -d "$STAGE2_DIR" ]]; then
    print_error "STAGE2 directory '$STAGE2_DIR' does not exist."
    exit 1
fi

# Initialize log file
if [[ -n "$LOG_FILE" ]]; then
    set_log_file "$LOG_FILE"
fi

print_info "Starting verification..."
print_info "STAGE1: $STAGE1_DIR"
print_info "STAGE2: $STAGE2_DIR"
echo ""

log_message "Starting verification"
log_message "STAGE1: $STAGE1_DIR"
log_message "STAGE2: $STAGE2_DIR"

# Counters
total_files=0
verified_files=0
missing_in_stage2=0
missing_in_stage1=0
mismatch_files=0
size_mismatch=0

# Function to verify a file
verify_file() {
    local rel_path="$1"
    local stage1_file="$STAGE1_DIR/$rel_path"
    local stage2_file="$STAGE2_DIR/$rel_path"
    
    ((total_files++))
    
    # Check if file exists in STAGE2
    if [[ ! -f "$stage2_file" ]]; then
        print_error "Missing in STAGE2: $rel_path"
        log_message "ERROR: Missing in STAGE2: $rel_path"
        ((missing_in_stage2++))
        return 1
    fi
    
    # Compare file sizes
    if ! files_same_size "$stage1_file" "$stage2_file"; then
        local stage1_size=$(get_file_size "$stage1_file")
        local stage2_size=$(get_file_size "$stage2_file")
        print_error "Size mismatch: $rel_path (STAGE1: $stage1_size, STAGE2: $stage2_size)"
        log_message "ERROR: Size mismatch: $rel_path"
        ((size_mismatch++))
        return 1
    fi
    
    # Compare checksums
    if ! files_same_checksum "$stage1_file" "$stage2_file"; then
        print_error "Checksum mismatch: $rel_path"
        log_message "ERROR: Checksum mismatch: $rel_path"
        ((mismatch_files++))
        return 1
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        print_success "Verified: $rel_path"
    fi
    log_message "SUCCESS: Verified $rel_path"
    ((verified_files++))
    return 0
}

# Find all files in STAGE1 and verify them
print_info "Scanning STAGE1 directory..."
while IFS= read -r -d '' file; do
    rel_path="${file#$STAGE1_DIR/}"
    verify_file "$rel_path"
done < <(find "$STAGE1_DIR" -type f -print0)

# Check for files in STAGE2 that don't exist in STAGE1
print_info "Checking for extra files in STAGE2..."
while IFS= read -r -d '' file; do
    rel_path="${file#$STAGE2_DIR/}"
    stage1_file="$STAGE1_DIR/$rel_path"
    
    if [[ ! -f "$stage1_file" ]]; then
        print_warning "Extra file in STAGE2 (not in STAGE1): $rel_path"
        log_message "WARNING: Extra file in STAGE2: $rel_path"
        ((missing_in_stage1++))
    fi
done < <(find "$STAGE2_DIR" -type f -print0)

# Print summary
echo ""
print_info "========================================="
print_info "VERIFICATION SUMMARY"
print_info "========================================="
print_info "Total files in STAGE1: $total_files"
print_success "Successfully verified: $verified_files"
if [[ $missing_in_stage2 -gt 0 ]]; then
    print_error "Missing in STAGE2: $missing_in_stage2"
fi
if [[ $missing_in_stage1 -gt 0 ]]; then
    print_warning "Extra in STAGE2: $missing_in_stage1"
fi
if [[ $size_mismatch -gt 0 ]]; then
    print_error "Size mismatches: $size_mismatch"
fi
if [[ $mismatch_files -gt 0 ]]; then
    print_error "Checksum mismatches: $mismatch_files"
fi
print_info "========================================="

# Log summary
log_message "========================================="
log_message "VERIFICATION SUMMARY"
log_message "Total files in STAGE1: $total_files"
log_message "Successfully verified: $verified_files"
log_message "Missing in STAGE2: $missing_in_stage2"
log_message "Extra in STAGE2: $missing_in_stage1"
log_message "Size mismatches: $size_mismatch"
log_message "Checksum mismatches: $mismatch_files"
log_message "========================================="

close_log_file

# Exit with error if there were any issues
if [[ $missing_in_stage2 -gt 0 || $size_mismatch -gt 0 || $mismatch_files -gt 0 ]]; then
    print_error "Verification FAILED - issues found!"
    exit 1
else
    print_success "Verification PASSED - all files match!"
    exit 0
fi
