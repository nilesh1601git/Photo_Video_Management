#!/bin/bash

# verify_stages.sh
# Verify that files in STAGE1 and STAGE2 are identical
# Usage: ./verify_stages.sh [--stage1 <dir>] [--stage2 <dir>] [--log <file>]

set -e

# Default values
STAGE1_DIR="./STAGE1"
STAGE2_DIR="./STAGE2"
LOG_FILE=""
VERBOSE=true

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
        print_error "Neither md5sum nor md5 command found."
        return 1
    fi
}

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
    echo "=========================================" > "$LOG_FILE"
    echo "Stage Verification Log" >> "$LOG_FILE"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
    echo "=========================================" >> "$LOG_FILE"
    print_success "Logging to: $LOG_FILE"
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
    stage1_size=$(stat -c%s "$stage1_file" 2>/dev/null || stat -f%z "$stage1_file" 2>/dev/null)
    stage2_size=$(stat -c%s "$stage2_file" 2>/dev/null || stat -f%z "$stage2_file" 2>/dev/null)
    
    if [[ "$stage1_size" != "$stage2_size" ]]; then
        print_error "Size mismatch: $rel_path (STAGE1: $stage1_size, STAGE2: $stage2_size)"
        log_message "ERROR: Size mismatch: $rel_path"
        ((size_mismatch++))
        return 1
    fi
    
    # Compare checksums
    stage1_md5=$(calculate_md5 "$stage1_file")
    stage2_md5=$(calculate_md5 "$stage2_file")
    
    if [[ "$stage1_md5" != "$stage2_md5" ]]; then
        print_error "Checksum mismatch: $rel_path"
        log_message "ERROR: Checksum mismatch: $rel_path (STAGE1: $stage1_md5, STAGE2: $stage2_md5)"
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

if [[ -n "$LOG_FILE" ]]; then
    log_message "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
    print_success "Log file saved to: $LOG_FILE"
fi

# Exit with error if there were any issues
if [[ $missing_in_stage2 -gt 0 || $size_mismatch -gt 0 || $mismatch_files -gt 0 ]]; then
    print_error "Verification FAILED - issues found!"
    exit 1
else
    print_success "Verification PASSED - all files match!"
    exit 0
fi

