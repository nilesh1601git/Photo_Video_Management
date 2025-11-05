#!/bin/bash

# exif_utils.sh - EXIF metadata utilities
# This module provides functions to extract and modify EXIF data

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities and date utils
source "$SCRIPT_DIR/common.sh"
source "$SCRIPT_DIR/date_utils.sh"

# Function to check if exiftool is available
check_exiftool() {
    if ! command_exists exiftool; then
        print_error "exiftool not found. Install it to use EXIF features."
        print_info "Install with: sudo apt-get install libimage-exiftool-perl (Debian/Ubuntu)"
        print_info "Or: brew install exiftool (macOS)"
        return 1
    fi
    return 0
}

# Function to extract date from EXIF data
# Tries DateTimeOriginal, CreateDate, then ModifyDate
# Returns: YYYY:MM:DD HH:MM:SS format on success, empty string on failure
get_exif_date() {
    local file="$1"

    if ! check_exiftool; then
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

# Function to get date path from EXIF (YYYY/MM format)
# Returns: YYYY/MM format on success, empty string on failure
get_date_path_from_exif() {
    local file="$1"
    local exif_date=$(get_exif_date "$file")
    
    if [[ -n "$exif_date" ]]; then
        parse_date "$exif_date"
        return $?
    fi
    
    return 1
}

# Function to get CreateDate from EXIF
get_exif_createdate() {
    local file="$1"
    
    if ! check_exiftool; then
        return 1
    fi
    
    exiftool -s -s -s -CreateDate "$file" 2>/dev/null
}

# Function to format EXIF CreateDate to YYYYMMDD_HHMMSS format
# Returns: YYYYMMDD_HHMMSS format on success, empty string on failure
format_exif_date_to_filename() {
    local file="$1"
    local created=$(get_exif_createdate "$file")
    
    if [[ -z "$created" ]]; then
        return 1
    fi
    
    # Format date: YYYYMMDD_HHMMSS
    # Input format is typically: YYYY:MM:DD HH:MM:SS
    local formatted=$(echo "$created" | sed 's/[: ]//g' | cut -c1-15 | sed 's/\(........\)\(......\)/\1_\2/')
    
    if [[ -z "$formatted" ]] || [[ ! $formatted =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        return 1
    fi
    
    echo "$formatted"
    return 0
}

# Function to modify EXIF timestamps from filename
# Expects filename format: YYYYMMDD_HHMMSS.ext
# Usage: modify_exif_timestamp_from_filename <file> [dry_run]
modify_exif_timestamp_from_filename() {
    local file="$1"
    local dry_run="${2:-false}"
    
    if ! check_exiftool; then
        return 1
    fi
    
    # Extract timestamp from filename
    local base=$(basename "$file")
    local name="${base%.*}"
    
    # Match YYYYMMDD_HHMMSS or YYYYMMDD_HHMMSS_XXX
    if [[ $name =~ ^([0-9]{8})_([0-9]{6})(_[0-9]{3})?$ ]]; then
        local date_part="${BASH_REMATCH[1]}"
        local time_part="${BASH_REMATCH[2]}"
        
        # Format as: YYYY:MM:DD HH:MM:SS
        local ts="${date_part:0:4}:${date_part:4:2}:${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"
        
        if [[ "$dry_run" == true ]]; then
            print_info "Would update EXIF timestamp for '$file' to '$ts'"
            return 0
        fi
        
        # Determine file type to set appropriate tags
        local ext="${base##*.}"
        local ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        
        if [[ "$ext_lower" == "jpg" || "$ext_lower" == "jpeg" ]]; then
            # For images, update all EXIF timestamps
            exiftool \
              "-DateTimeOriginal=$ts" \
              "-CreateDate=$ts" \
              "-ModifyDate=$ts" \
              "-FileModifyDate=$ts" \
              "$file" > /dev/null 2>&1
        else
            # For videos, update file modification date
            exiftool "-FileModifyDate=$ts" "$file" > /dev/null 2>&1
        fi
        
        if [[ $? -eq 0 ]]; then
            print_success "Updated EXIF timestamp for '$file' to '$ts'"
            return 0
        else
            print_error "Failed to update EXIF timestamp for '$file'"
            return 1
        fi
    else
        print_warning "Skipping '$file' (filename doesn't match expected format YYYYMMDD_HHMMSS)"
        return 1
    fi
}

# Function to get best available date (EXIF first, then filename, then file modification time)
# Returns: YYYY:MM:DD format
get_best_available_date() {
    local file="$1"
    local prefer_exif="${2:-true}"
    
    # Try EXIF first if preferred
    if [[ "$prefer_exif" == true ]]; then
        local exif_date=$(get_exif_date "$file")
        if [[ -n "$exif_date" ]]; then
            parse_date "$exif_date"
            if [[ $? -eq 0 ]]; then
                return 0
            fi
        fi
    fi
    
    # Fall back to filename
    local filename_date=$(get_filename_date "$file")
    if [[ -n "$filename_date" ]]; then
        parse_date "$filename_date"
        if [[ $? -eq 0 ]]; then
            return 0
        fi
    fi
    
    # Last resort: file modification time
    local mod_date=$(get_file_modification_date "$file")
    if [[ -n "$mod_date" ]]; then
        local date_part="${mod_date:0:8}"
        echo "${date_part:0:4}:${date_part:4:2}:${date_part:6:2}"
        parse_date "${date_part:0:4}:${date_part:4:2}:${date_part:6:2}"
        return $?
    fi
    
    return 1
}

