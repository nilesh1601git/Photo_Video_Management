#!/bin/bash

# file_utils.sh - File operations utilities
# This module provides file copying, verification, and extension checking functions

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/common.sh"

# Supported file extensions
SUPPORTED_EXTENSIONS=("jpg" "JPG" "jpeg" "JPEG" "png" "PNG" "avi" "AVI" "mov" "MOV" "mp4" "MP4" "m4v" "M4V")

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

# Function to calculate MD5 checksum
calculate_md5() {
    local file="$1"
    if command_exists md5sum; then
        md5sum "$file" | awk '{print $1}'
    elif command_exists md5; then
        md5 -q "$file"
    else
        print_error "Neither md5sum nor md5 command found. Cannot verify files."
        return 1
    fi
}

# Function to get file size
get_file_size() {
    local file="$1"
    stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null
}

# Function to compare files by size
files_same_size() {
    local file1="$1"
    local file2="$2"
    local size1=$(get_file_size "$file1")
    local size2=$(get_file_size "$file2")
    [[ "$size1" == "$size2" ]]
}

# Function to compare files by checksum
files_same_checksum() {
    local file1="$1"
    local file2="$2"
    local md5_1=$(calculate_md5 "$file1")
    local md5_2=$(calculate_md5 "$file2")
    [[ "$md5_1" == "$md5_2" ]]
}

# Function to copy file with verification
# Usage: copy_file_with_verification <src> <dest> [verify]
copy_file_with_verification() {
    local src_file="$1"
    local dest_file="$2"
    local verify="${3:-false}"
    local dry_run="${DRY_RUN:-false}"
    local verbose="${VERBOSE:-true}"

    if [[ ! -f "$src_file" ]]; then
        print_error "Source file '$src_file' not found"
        log_message "ERROR: Source file '$src_file' not found"
        return 1
    fi

    if [[ "$dry_run" == true ]]; then
        print_info "Would copy: '$src_file' → '$dest_file'"
        log_message "DRY RUN: Would copy '$src_file' → '$dest_file'"
        return 0
    fi

    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$dest_file")"

    # Check if destination file already exists
    if [[ -e "$dest_file" ]]; then
        # Compare file sizes
        if files_same_size "$src_file" "$dest_file"; then
            # If verify is enabled, check MD5
            if [[ "$verify" == true ]]; then
                if files_same_checksum "$src_file" "$dest_file"; then
                    if [[ "$verbose" == true ]]; then
                        print_warning "Skipping '$src_file' - identical file exists (verified)"
                    fi
                    log_message "SKIP: Identical file exists (verified): '$dest_file'"
                    return 0
                fi
            else
                if [[ "$verbose" == true ]]; then
                    print_warning "Skipping '$src_file' - file with same size exists"
                fi
                log_message "SKIP: File with same size exists: '$dest_file'"
                return 0
            fi
        fi

        # File exists but differs - create backup
        print_warning "File exists but differs: '$dest_file' - creating backup"
        backup_file="${dest_file}.backup.$(date +%s)"
        mv "$dest_file" "$backup_file"
        print_info "Backed up to: $backup_file"
        log_message "BACKUP: Created backup '$backup_file'"
    fi

    # Copy file preserving all attributes
    if cp -p "$src_file" "$dest_file"; then
        # Additional timestamp preservation using touch
        touch -r "$src_file" "$dest_file"

        # Verify copy if requested
        if [[ "$verify" == true ]]; then
            if ! files_same_checksum "$src_file" "$dest_file"; then
                print_error "Verification failed for '$dest_file' - checksums don't match!"
                log_message "ERROR: Verification failed for '$dest_file'"
                rm -f "$dest_file"
                return 1
            fi
            if [[ "$verbose" == true ]]; then
                print_success "Copied and verified: '$src_file' → '$dest_file'"
            fi
            log_message "SUCCESS: Copied and verified '$src_file' → '$dest_file'"
        else
            if [[ "$verbose" == true ]]; then
                print_success "Copied: '$src_file' → '$dest_file'"
            fi
            log_message "SUCCESS: Copied '$src_file' → '$dest_file'"
        fi
        return 0
    else
        print_error "Failed to copy: '$src_file' → '$dest_file'"
        log_message "ERROR: Failed to copy '$src_file' → '$dest_file'"
        return 1
    fi
}

# Function to find files matching pattern
find_files() {
    local pattern="$1"
    local source_dir="${2:-.}"
    
    # Normalize source directory path
    source_dir="$(cd "$source_dir" && pwd)"
    
    # Enable nullglob to handle cases where pattern matches nothing
    local old_nullglob=$(shopt -p nullglob)
    shopt -s nullglob
    
    local files=()
    local original_dir=$(pwd)
    
    cd "$source_dir" || {
        eval "$old_nullglob"
        return 1
    }
    
    for file in $pattern; do
        if [[ -f "$file" ]] && is_supported_extension "$file"; then
            files+=("$file")
        fi
    done
    
    # If no files matched the pattern, try all supported extensions
    if [[ ${#files[@]} -eq 0 && "$pattern" == "*" ]]; then
        for ext in "${SUPPORTED_EXTENSIONS[@]}"; do
            for file in *."$ext"; do
                if [[ -f "$file" ]]; then
                    files+=("$file")
                fi
            done
        done
    fi
    
    cd "$original_dir" || true
    eval "$old_nullglob"
    
    # Convert to absolute paths
    for file in "${files[@]}"; do
        if [[ "$file" != /* ]]; then
            echo "$source_dir/$file"
        else
            echo "$file"
        fi
    done
}

