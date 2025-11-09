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

# Function to check if ffmpeg is available
check_ffmpeg() {
    if ! command_exists ffmpeg; then
        return 1
    fi
    return 0
}

# Function to check if ffprobe is available
check_ffprobe() {
    if ! command_exists ffprobe; then
        return 1
    fi
    return 0
}

# Function to check if file is a video format
is_video_file() {
    local file="$1"
    local ext="${file##*.}"
    local ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    case "$ext_lower" in
        avi|mov|mp4|m4v|mkv|webm|flv|wmv|mpg|mpeg)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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

# Function to validate if a date string is valid (not 0000:00:00 00:00:00 or similar invalid dates)
# Returns: 0 if valid, 1 if invalid
is_valid_date() {
    local date_str="$1"
    
    if [[ -z "$date_str" ]]; then
        return 1
    fi
    
    # Check for invalid date patterns: 0000:00:00, 0000-00-00, etc.
    if [[ "$date_str" =~ ^0{4}[:/-]0{2}[:/-]0{2} ]]; then
        return 1
    fi
    
    # Check if it contains only zeros for date part
    if [[ "$date_str" =~ ^0{4} ]]; then
        return 1
    fi
    
    return 0
}

# Function to get CreateDate from EXIF
# Returns valid CreateDate or empty string if not found/invalid
get_exif_createdate() {
    local file="$1"
    
    if ! check_exiftool; then
        return 1
    fi
    
    local created=$(exiftool -s -s -s -CreateDate "$file" 2>/dev/null)
    
    # Validate the date - reject invalid dates like 0000:00:00 00:00:00
    if [[ -n "$created" ]] && is_valid_date "$created"; then
        echo "$created"
        return 0
    fi
    
    return 1
}

# Function to get all date-related EXIF tags as a pipe-separated string
# Returns: DateTimeOriginal|CreateDate|ModifyDate|FileModifyDate|DateTime|DateCreated|DateModified
get_all_date_tags() {
    local file="$1"
    
    if ! check_exiftool; then
        echo "N/A|N/A|N/A|N/A|N/A|N/A|N/A"
        return 1
    fi
    
    # Extract common date-related tags
    local datetime_original=$(exiftool -s -s -s -DateTimeOriginal "$file" 2>/dev/null)
    [[ -z "$datetime_original" ]] && datetime_original="N/A"
    
    local create_date=$(exiftool -s -s -s -CreateDate "$file" 2>/dev/null)
    [[ -z "$create_date" ]] && create_date="N/A"
    
    local modify_date=$(exiftool -s -s -s -ModifyDate "$file" 2>/dev/null)
    [[ -z "$modify_date" ]] && modify_date="N/A"
    
    local file_modify_date=$(exiftool -s -s -s -FileModifyDate "$file" 2>/dev/null)
    [[ -z "$file_modify_date" ]] && file_modify_date="N/A"
    
    local datetime=$(exiftool -s -s -s -DateTime "$file" 2>/dev/null)
    [[ -z "$datetime" ]] && datetime="N/A"
    
    local date_created=$(exiftool -s -s -s -DateCreated "$file" 2>/dev/null)
    [[ -z "$date_created" ]] && date_created="N/A"
    
    local date_modified=$(exiftool -s -s -s -DateModified "$file" 2>/dev/null)
    [[ -z "$date_modified" ]] && date_modified="N/A"
    
    # Return pipe-separated values
    echo "${datetime_original}|${create_date}|${modify_date}|${file_modify_date}|${datetime}|${date_created}|${date_modified}"
}

# Function to get the oldest file stat date when no EXIF tags are available
# Returns: YYYY:MM:DD HH:MM:SS format on success, empty string on failure
get_oldest_file_stat_date() {
    local file="$1"
    
    if ! check_exiftool; then
        return 1
    fi
    
    # Get File* dates using exiftool
    local file_modify_date=$(exiftool -s -s -s -FileModifyDate "$file" 2>/dev/null)
    local file_access_date=$(exiftool -s -s -s -FileAccessDate "$file" 2>/dev/null)
    local file_inode_change_date=$(exiftool -s -s -s -FileInodeChangeDate "$file" 2>/dev/null)
    
    # Find oldest date
    local oldest_date=""
    local oldest_timestamp=9999999999
    
    if [[ -n "$file_modify_date" ]]; then
        local ts=$(date_to_timestamp "$file_modify_date")
        if [[ $ts -lt $oldest_timestamp ]] && [[ $ts -gt 0 ]]; then
            oldest_timestamp=$ts
            oldest_date="$file_modify_date"
        fi
    fi
    
    if [[ -n "$file_access_date" ]]; then
        local ts=$(date_to_timestamp "$file_access_date")
        if [[ $ts -lt $oldest_timestamp ]] && [[ $ts -gt 0 ]]; then
            oldest_timestamp=$ts
            oldest_date="$file_access_date"
        fi
    fi
    
    if [[ -n "$file_inode_change_date" ]]; then
        local ts=$(date_to_timestamp "$file_inode_change_date")
        if [[ $ts -lt $oldest_timestamp ]] && [[ $ts -gt 0 ]]; then
            oldest_timestamp=$ts
            oldest_date="$file_inode_change_date"
        fi
    fi
    
    if [[ -n "$oldest_date" ]]; then
        echo "$oldest_date"
        return 0
    fi
    
    return 1
}

# Function to check if file has any EXIF date tags (not just File* tags)
# Returns: 0 if EXIF tags exist, 1 otherwise
has_exif_date_tags() {
    local file="$1"
    
    if ! check_exiftool; then
        return 1
    fi
    
    # Check for EXIF, Composite, IPTC, XMP, or ICC_Profile date tags
    local has_exif=$(exiftool -s -G -time:all -date:all "$file" 2>/dev/null | grep -iE "(date|time)" | grep -v "^$" | grep -v -iE "SubSecTime(Original|Digitized)" | grep -E "^\[EXIF\]|^\[Composite\]|^\[IPTC\]|^\[XMP\]|^\[ICC_Profile\]" | head -1)
    
    if [[ -n "$has_exif" ]]; then
        return 0
    fi
    
    return 1
}

# Function to check if file has any valid EXIF date tags (not just File* tags, and not invalid dates like 0000:00:00)
# Returns: 0 if valid EXIF tags exist, 1 otherwise
has_valid_exif_date_tags() {
    local file="$1"
    
    if ! check_exiftool; then
        return 1
    fi
    
    # Get all EXIF date tags and check if any are valid
    local exif_tags=$(exiftool -s -G -time:all -date:all "$file" 2>/dev/null | grep -iE "(date|time)" | grep -v "^$" | grep -v -iE "SubSecTime(Original|Digitized)" | grep -E "^\[EXIF\]|^\[Composite\]|^\[IPTC\]|^\[XMP\]|^\[ICC_Profile\]|^\[QuickTime\]")
    
    if [[ -z "$exif_tags" ]]; then
        return 1
    fi
    
    # Check if any of the tags have valid dates (not 0000:00:00)
    while IFS= read -r line; do
        # Extract the date value (everything after the colon)
        local date_value=$(echo "$line" | sed 's/.*:[[:space:]]*//')
        if [[ -n "$date_value" ]] && is_valid_date "$date_value"; then
            return 0
        fi
    done <<< "$exif_tags"
    
    return 1
}

# Function to format EXIF CreateDate to YYYYMMDD_HHMMSS format
# For MP4 files, uses exiftool first, then falls back to ffprobe
# For other video files, uses ffprobe first, then falls back to exiftool
# If no EXIF tags exist, uses oldest file stat date (FileModifyDate, FileAccessDate, FileInodeChangeDate)
# Returns: YYYYMMDD_HHMMSS format on success, empty string on failure
format_exif_date_to_filename() {
    local file="$1"
    local created=""
    local ext="${file##*.}"
    local ext_lower=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    
    # Check if it's a video file
    if is_video_file "$file"; then
        # For MP4 files, use exiftool first
        if [[ "$ext_lower" == "mp4" ]] || [[ "$ext_lower" == "m4v" ]]; then
            # Try exiftool first for MP4/M4V files
            created=$(get_exif_createdate "$file")
            # Validate the date if we got one
            if [[ -n "$created" ]] && ! is_valid_date "$created"; then
                created=""
            fi
            
            # If exiftool didn't work, fall back to ffprobe
            if [[ -z "$created" ]] && check_ffprobe; then
                # Try format_tags=creation_time first (metadata)
                created=$(ffprobe -v quiet -show_entries format_tags=creation_time -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
                
                # If not found, try format=creation_time (container level)
                if [[ -z "$created" ]]; then
                    created=$(ffprobe -v quiet -show_entries format=creation_time -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
                fi
                
                # Remove any leading/trailing whitespace
                created=$(echo "$created" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Convert ISO 8601 format to YYYY:MM:DD HH:MM:SS
                # Handles formats like: 2015-05-24T08:51:40.000000Z, 2015-05-24 08:51:40, or 2015-05-24T08:51:40
                if [[ -n "$created" ]]; then
                    # Replace T with space, remove microseconds and timezone
                    created=$(echo "$created" | sed 's/T/ /' | sed 's/\.[0-9]*//' | sed 's/[Z+-].*$//')
                    # Convert YYYY-MM-DD HH:MM:SS to YYYY:MM:DD HH:MM:SS
                    if [[ $created =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]+([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]; then
                        created="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
                    fi
                fi
            fi
        else
            # For other video files (AVI, MOV, etc.), use ffprobe first
            if check_ffprobe; then
                # Try format_tags=creation_time first (metadata)
                created=$(ffprobe -v quiet -show_entries format_tags=creation_time -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
                
                # If not found, try format=creation_time (container level)
                if [[ -z "$created" ]]; then
                    created=$(ffprobe -v quiet -show_entries format=creation_time -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
                fi
                
                # Remove any leading/trailing whitespace
                created=$(echo "$created" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                
                # Convert ISO 8601 format to YYYY:MM:DD HH:MM:SS
                # Handles formats like: 2015-05-24T08:51:40.000000Z, 2015-05-24 08:51:40, or 2015-05-24T08:51:40
                if [[ -n "$created" ]]; then
                    # Replace T with space, remove microseconds and timezone
                    created=$(echo "$created" | sed 's/T/ /' | sed 's/\.[0-9]*//' | sed 's/[Z+-].*$//')
                    # Convert YYYY-MM-DD HH:MM:SS to YYYY:MM:DD HH:MM:SS
                    if [[ $created =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]+([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]; then
                        created="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}:${BASH_REMATCH[3]} ${BASH_REMATCH[4]}:${BASH_REMATCH[5]}:${BASH_REMATCH[6]}"
                    fi
                fi
            fi
            
            # Fall back to exiftool if ffprobe didn't work
            if [[ -z "$created" ]]; then
                created=$(get_exif_createdate "$file")
                # Validate the date if we got one
                if [[ -n "$created" ]] && ! is_valid_date "$created"; then
                    created=""
                fi
            fi
        fi
    else
        # For image files, use EXIF CreateDate
        created=$(get_exif_createdate "$file")
        # Validate the date if we got one
        if [[ -n "$created" ]] && ! is_valid_date "$created"; then
            created=""
        fi
    fi
    
    # If no valid EXIF CreateDate found, check if there are any valid EXIF tags at all
    # If no valid EXIF tags exist, use oldest file stat date
    if [[ -z "$created" ]]; then
        # Check if there are any valid EXIF date tags (not just invalid ones like 0000:00:00)
        if ! has_valid_exif_date_tags "$file"; then
            # No valid EXIF tags found, use oldest file stat date
            created=$(get_oldest_file_stat_date "$file")
        fi
    fi
    
    if [[ -z "$created" ]]; then
        return 1
    fi
    
    # Format date: YYYYMMDD_HHMMSS
    # Input format is typically: YYYY:MM:DD HH:MM:SS or YYYY:MM:DD HH:MM:SS+timezone
    # Use format_date_to_yyyymmdd_hhmmss for proper formatting
    local formatted=$(format_date_to_yyyymmdd_hhmmss "$created")
    
    if [[ -z "$formatted" ]] || [[ ! $formatted =~ ^[0-9]{8}_[0-9]{6}$ ]]; then
        return 1
    fi
    
    echo "$formatted"
    return 0
}

# Function to convert date string to YYYYMMDD_HHMMSS format
# Handles various input formats:
#   - YYYY:MM:DD HH:MM:SS
#   - YYYY:MM:DD HH:MM:SS+timezone
#   - YYYY:MM:DD HH:MM:SS.timezone
#   - YYYY:MM:DD HH:MM:SS.SSS
# Returns: YYYYMMDD_HHMMSS format on success, empty string on failure
format_date_to_yyyymmdd_hhmmss() {
    local date_str="$1"
    
    if [[ -z "$date_str" ]]; then
        return 1
    fi
    
    # Remove timezone info (everything after +, -, or . after seconds)
    # Handle formats like: 2025:11:05 23:44:10+05:30 or 2017:01:29 22:39:02.150
    local cleaned=$(echo "$date_str" | sed -E 's/[+-][0-9]{2}:[0-9]{2}$//' | sed -E 's/\.[0-9]+$//')
    
    # Extract date and time parts
    # Format: YYYY:MM:DD HH:MM:SS
    if [[ $cleaned =~ ^([0-9]{4}):([0-9]{2}):([0-9]{2})[[:space:]]+([0-9]{2}):([0-9]{2}):([0-9]{2}) ]]; then
        local year="${BASH_REMATCH[1]}"
        local month="${BASH_REMATCH[2]}"
        local day="${BASH_REMATCH[3]}"
        local hour="${BASH_REMATCH[4]}"
        local minute="${BASH_REMATCH[5]}"
        local second="${BASH_REMATCH[6]}"
        
        echo "${year}${month}${day}_${hour}${minute}${second}"
        return 0
    fi
    
    return 1
}

# Function to modify EXIF timestamps from filename
# Expects filename format: YYYYMMDD_HHMMSS.ext or PREFIX_YYYYMMDD_HHMMSS.ext (e.g., VID_20161010_231520.mp4)
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
    
    local date_part=""
    local time_part=""
    
    # Match patterns:
    # 1. YYYYMMDD_HHMMSS or YYYYMMDD_HHMMSS_XXX (original pattern)
    # 2. PREFIX_YYYYMMDD_HHMMSS (e.g., VID_20161010_231520, IMG_20161010_231520)
    if [[ $name =~ ^([0-9]{8})_([0-9]{6})(_[0-9]{3})?$ ]]; then
        # Pattern 1: Direct YYYYMMDD_HHMMSS
        date_part="${BASH_REMATCH[1]}"
        time_part="${BASH_REMATCH[2]}"
    elif [[ $name =~ _([0-9]{8})_([0-9]{6})(_[0-9]{3})?$ ]]; then
        # Pattern 2: PREFIX_YYYYMMDD_HHMMSS (e.g., VID_20161010_231520)
        date_part="${BASH_REMATCH[1]}"
        time_part="${BASH_REMATCH[2]}"
    fi
    
    if [[ -n "$date_part" ]] && [[ -n "$time_part" ]]; then
        
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
        print_warning "Skipping '$file' (filename doesn't match expected format YYYYMMDD_HHMMSS or PREFIX_YYYYMMDD_HHMMSS)"
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

# Function to convert exiftool date format to Unix timestamp for comparison
# Input: exiftool date format (e.g., "2009:07:31 22:05:48+05:30")
# Returns: Unix timestamp
date_to_timestamp() {
    local date_str="$1"
    # Remove timezone offset and convert to format that date can parse
    # Handle formats like "2009:07:31 22:05:48+05:30" or "2009:07:31 22:05:48"
    # Convert "2009:07:31 22:05:48+05:30" to "2009-07-31 22:05:48"
    local clean_date=$(echo "$date_str" | sed 's/+[0-9][0-9]:[0-9][0-9]$//' | sed 's/-[0-9][0-9]:[0-9][0-9]$//' | sed 's/:/-/' | sed 's/:/-/' | sed 's/ / /')
    # Convert YYYY-MM-DD HH:MM:SS to Unix timestamp
    date -d "$clean_date" +%s 2>/dev/null || echo "0"
}

# Function to display all date-related EXIF tags
# Shows all date/time fields available in the file
# If no EXIF tags are found (only File* tags), uses the oldest file stat date
display_all_date_tags() {
    local file="$1"
    
    if ! check_exiftool; then
        return 1
    fi
    
    # Get all date-related tags using exiftool
    # This searches for tags containing "Date" or "Time" in their names
    # Exclude SubSecTimeOriginal and SubSecTimeDigitized as they are not needed
    local temp_output=$(mktemp)
    exiftool -s -G -time:all -date:all "$file" 2>/dev/null | grep -iE "(date|time)" | grep -v "^$" | grep -v -iE "SubSecTime(Original|Digitized)" > "$temp_output" || true
    
    if [[ -s "$temp_output" ]]; then
        # Read all lines into an array for processing
        local lines=()
        while IFS= read -r line; do
            lines+=("$line")
        done < "$temp_output"
        
        # Check if there are any EXIF tags (not just File* tags)
        local has_exif_tags=false
        local has_file_tags=false
        local file_modify_date=""
        local file_access_date=""
        local file_inode_change_date=""
        
        for line in "${lines[@]}"; do
            local formatted_line=$(echo "$line" | sed 's/^[[:space:]]*//')
            if [[ -n "$formatted_line" ]]; then
                # Check if it's an EXIF tag (not File tag)
                if [[ "$formatted_line" =~ ^\[EXIF\]|^\[Composite\]|^\[IPTC\]|^\[XMP\]|^\[ICC_Profile\] ]]; then
                    has_exif_tags=true
                elif [[ "$formatted_line" =~ ^\[File\] ]]; then
                    has_file_tags=true
                    # Extract File* dates - get everything after the colon
                    if [[ "$formatted_line" =~ FileModifyDate ]]; then
                        file_modify_date=$(echo "$formatted_line" | sed 's/.*FileModifyDate[[:space:]]*:[[:space:]]*//')
                    elif [[ "$formatted_line" =~ FileAccessDate ]]; then
                        file_access_date=$(echo "$formatted_line" | sed 's/.*FileAccessDate[[:space:]]*:[[:space:]]*//')
                    elif [[ "$formatted_line" =~ FileInodeChangeDate ]]; then
                        file_inode_change_date=$(echo "$formatted_line" | sed 's/.*FileInodeChangeDate[[:space:]]*:[[:space:]]*//')
                    fi
                fi
            fi
        done
        
        # If no EXIF tags found but File tags exist, use oldest file stat date
        if [[ "$has_exif_tags" == false ]] && [[ "$has_file_tags" == true ]]; then
            print_info "Date-related EXIF tags for '$(basename "$file")':"
            
            # Display all File tags and valid QuickTime tags (filter out invalid dates)
            for line in "${lines[@]}"; do
                local formatted_line=$(echo "$line" | sed 's/^[[:space:]]*//')
                if [[ -n "$formatted_line" ]]; then
                    # Extract the date value (everything after the colon)
                    local date_value=$(echo "$formatted_line" | sed 's/.*:[[:space:]]*//')
                    # Skip lines with invalid dates (0000:00:00 00:00:00)
                    if [[ -n "$date_value" ]] && ! is_valid_date "$date_value"; then
                        continue
                    fi
                    echo "  $formatted_line"
                fi
            done
            
            # Find oldest date from File tags
            local oldest_date=""
            local oldest_timestamp=9999999999
            local oldest_tag=""
            
            if [[ -n "$file_modify_date" ]]; then
                local ts=$(date_to_timestamp "$file_modify_date")
                if [[ $ts -lt $oldest_timestamp ]] && [[ $ts -gt 0 ]]; then
                    oldest_timestamp=$ts
                    oldest_date="$file_modify_date"
                    oldest_tag="FileModifyDate"
                fi
            fi
            
            if [[ -n "$file_access_date" ]]; then
                local ts=$(date_to_timestamp "$file_access_date")
                if [[ $ts -lt $oldest_timestamp ]] && [[ $ts -gt 0 ]]; then
                    oldest_timestamp=$ts
                    oldest_date="$file_access_date"
                    oldest_tag="FileAccessDate"
                fi
            fi
            
            if [[ -n "$file_inode_change_date" ]]; then
                local ts=$(date_to_timestamp "$file_inode_change_date")
                if [[ $ts -lt $oldest_timestamp ]] && [[ $ts -gt 0 ]]; then
                    oldest_timestamp=$ts
                    oldest_date="$file_inode_change_date"
                    oldest_tag="FileInodeChangeDate"
                fi
            fi
            
            if [[ -n "$oldest_date" ]]; then
                echo ""
                print_info "No EXIF date tags found. Using oldest file stat date:"
                echo "  [File]          $oldest_tag                  : $oldest_date"
            fi
        else
            # Normal case: display all tags (has EXIF tags or no tags at all)
            # Filter out invalid dates (like 0000:00:00 00:00:00)
            print_info "Date-related EXIF tags for '$(basename "$file")':"
            for line in "${lines[@]}"; do
                # Format the output nicely - remove leading spaces and show tag name and value
                local formatted_line=$(echo "$line" | sed 's/^[[:space:]]*//')
                if [[ -n "$formatted_line" ]]; then
                    # Extract the date value (everything after the colon)
                    local date_value=$(echo "$formatted_line" | sed 's/.*:[[:space:]]*//')
                    # Skip lines with invalid dates (0000:00:00 00:00:00)
                    if [[ -n "$date_value" ]] && ! is_valid_date "$date_value"; then
                        continue
                    fi
                    echo "  $formatted_line"
                fi
            done
        fi
    else
        print_warning "No date-related EXIF tags found for '$(basename "$file")'"
    fi
    
    rm -f "$temp_output"
}

# Function to get remark/comment from EXIF ImageDescription or UserComment
# For video files, uses ffprobe to get caption (title), comment, or description metadata
# Returns the remark text if found, empty string otherwise
get_exif_remark() {
    local file="$1"
    
    # Check if it's a video file
    if is_video_file "$file"; then
        # Use ffprobe for video files
        if check_ffprobe; then
            # For video files, try caption (title) first, then comment, then description
            local remark=$(ffprobe -v quiet -show_entries format_tags=title -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
            
            # If title/caption is empty, try comment
            if [[ -z "$remark" ]]; then
                remark=$(ffprobe -v quiet -show_entries format_tags=comment -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
            fi
            
            # If comment is empty, try description
            if [[ -z "$remark" ]]; then
                remark=$(ffprobe -v quiet -show_entries format_tags=description -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null | head -1)
            fi
            
            # Remove any leading/trailing whitespace
            remark=$(echo "$remark" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            echo "$remark"
            return 0
        else
            # Fallback to exiftool if ffprobe not available
            if check_exiftool; then
                local remark=$(exiftool -s -s -s -Comment "$file" 2>/dev/null)
                echo "$remark"
                return 0
            fi
            return 1
        fi
    fi
    
    # For image files, use exiftool
    if ! check_exiftool; then
        return 1
    fi
    
    # Try ImageDescription first (more commonly displayed)
    local remark=$(exiftool -s -s -s -ImageDescription "$file" 2>/dev/null)
    
    # If ImageDescription is empty, try UserComment
    if [[ -z "$remark" ]]; then
        remark=$(exiftool -s -s -s -UserComment "$file" 2>/dev/null)
    fi
    
    echo "$remark"
}

# Function to set remark/comment in EXIF ImageDescription and UserComment
# For video files, uses ffmpeg to set caption (title), comment, and description metadata
# Sets multiple tags for maximum compatibility
set_exif_remark() {
    local file="$1"
    local remark="$2"
    local dry_run="${3:-false}"
    
    if [[ "$dry_run" == true ]]; then
        print_info "Would set remark for '$file' to: '$remark'"
        return 0
    fi
    
    # Check if it's a video file
    if is_video_file "$file"; then
        # Use ffmpeg for video files
        if ! check_ffmpeg; then
            print_error "ffmpeg not found. Install it to set remarks for video files."
            print_info "Install with: sudo apt-get install ffmpeg (Debian/Ubuntu)"
            return 1
        fi
        
        # Create temporary output file in the same directory as source
        # Keep the original extension so ffmpeg knows the format
        local file_dir=$(dirname "$file")
        local file_name=$(basename "$file")
        local file_ext="${file##*.}"
        local file_base="${file_name%.*}"
        local temp_file="${file_dir}/${file_base}.tmp_remark.${file_ext}"
        
        # Use ffmpeg to add caption (title) and comment metadata for video files
        # Using -c copy to avoid re-encoding (fast, preserves quality)
        # Suppress ffmpeg output but keep stderr for error detection
        if ffmpeg -i "$file" -metadata title="$remark" -metadata comment="$remark" -metadata description="$remark" -c copy -y "$temp_file" 2>/dev/null; then
            # Replace original file with modified version
            if mv "$temp_file" "$file"; then
                print_success "Set remark for '$file'"
                return 0
            else
                rm -f "$temp_file"
                print_error "Failed to replace file '$file'"
                return 1
            fi
        else
            rm -f "$temp_file"
            # Try without -c copy (re-encode if needed) - this is slower but more compatible
            # Note: Re-encoding may reduce quality slightly
            if ffmpeg -i "$file" -metadata title="$remark" -metadata comment="$remark" -metadata description="$remark" -c:v copy -c:a copy -y "$temp_file" 2>/dev/null; then
                if mv "$temp_file" "$file"; then
                    print_success "Set remark for '$file' (file was re-encoded)"
                    return 0
                else
                    rm -f "$temp_file"
                    print_error "Failed to replace file '$file'"
                    return 1
                fi
            else
                rm -f "$temp_file"
                print_warning "Failed to set remark for '$(basename "$file")' using ffmpeg"
                return 1
            fi
        fi
    fi
    
    # For image files, use exiftool
    if ! check_exiftool; then
        return 1
    fi
    
    # Set both ImageDescription and UserComment for maximum compatibility
    local temp_output=$(mktemp)
    exiftool -overwrite_original \
        "-ImageDescription=$remark" \
        "-UserComment=$remark" \
        "$file" > "$temp_output" 2>&1
    local result=$?
    
    # Check if there was an error message about not being able to write
    if grep -qi "can't.*write\|weren't updated\|error" "$temp_output"; then
        rm -f "$temp_output"
        print_warning "Cannot set remark for '$(basename "$file")' - file format not supported for writing"
        return 1
    fi
    
    rm -f "$temp_output"
    
    if [[ $result -eq 0 ]]; then
        print_success "Set remark for '$file'"
        return 0
    else
        print_warning "Failed to set remark for '$(basename "$file")' - file format may not support EXIF metadata"
        return 1
    fi
}

# Function to display remark/comment if available
display_exif_remark() {
    local file="$1"
    local remark=$(get_exif_remark "$file")
    
    if [[ -n "$remark" ]]; then
        print_info "Remark for '$(basename "$file")': $remark"
        return 0
    fi
    return 1
}

# Function to get all CSV log EXIF tags
# Returns: comma-separated values for CSV log
# Format: ModifyDate,DateTimeOriginal,CreateDate,SubSecCreateDate,SubSecDateTimeOriginal
get_csv_exif_tags() {
    local file="$1"
    
    if ! check_exiftool; then
        echo ",,,,"
        return 1
    fi
    
    # Extract required EXIF tags (excluding File-related tags)
    local exif_modify_date_raw=$(exiftool -s -s -s -EXIF:ModifyDate "$file" 2>/dev/null)
    local exif_modify_date=""
    [[ -n "$exif_modify_date_raw" ]] && exif_modify_date=$(format_date_to_yyyymmdd_hhmmss "$exif_modify_date_raw")
    
    local datetime_original_raw=$(exiftool -s -s -s -EXIF:DateTimeOriginal "$file" 2>/dev/null)
    local datetime_original=""
    [[ -n "$datetime_original_raw" ]] && datetime_original=$(format_date_to_yyyymmdd_hhmmss "$datetime_original_raw")
    
    local create_date_raw=$(exiftool -s -s -s -EXIF:CreateDate "$file" 2>/dev/null)
    local create_date=""
    [[ -n "$create_date_raw" ]] && create_date=$(format_date_to_yyyymmdd_hhmmss "$create_date_raw")
    
    local subsec_create_date_raw=$(exiftool -s -s -s -Composite:SubSecCreateDate "$file" 2>/dev/null)
    local subsec_create_date=""
    [[ -n "$subsec_create_date_raw" ]] && subsec_create_date=$(format_date_to_yyyymmdd_hhmmss "$subsec_create_date_raw")
    
    local subsec_datetime_original_raw=$(exiftool -s -s -s -Composite:SubSecDateTimeOriginal "$file" 2>/dev/null)
    local subsec_datetime_original=""
    [[ -n "$subsec_datetime_original_raw" ]] && subsec_datetime_original=$(format_date_to_yyyymmdd_hhmmss "$subsec_datetime_original_raw")
    
    # Return comma-separated values (empty strings if conversion failed)
    echo "${exif_modify_date},${datetime_original},${create_date},${subsec_create_date},${subsec_datetime_original}"
}

