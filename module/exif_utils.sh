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

# Function to get CreateDate from EXIF
get_exif_createdate() {
    local file="$1"
    
    if ! check_exiftool; then
        return 1
    fi
    
    exiftool -s -s -s -CreateDate "$file" 2>/dev/null
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

# Function to format EXIF CreateDate to YYYYMMDD_HHMMSS format
# For video files, uses ffprobe to get creation_time
# Returns: YYYYMMDD_HHMMSS format on success, empty string on failure
format_exif_date_to_filename() {
    local file="$1"
    local created=""
    
    # Check if it's a video file
    if is_video_file "$file"; then
        # Use ffprobe for video files to get creation_time
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
    fi
    
    # For image files or if video date extraction failed, use exiftool
    if [[ -z "$created" ]]; then
        created=$(get_exif_createdate "$file")
    fi
    
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

# Function to display all date-related EXIF tags
# Shows all date/time fields available in the file
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
        print_info "Date-related EXIF tags for '$(basename "$file")':"
        while IFS= read -r line; do
            # Format the output nicely - remove leading spaces and show tag name and value
            local formatted_line=$(echo "$line" | sed 's/^[[:space:]]*//')
            if [[ -n "$formatted_line" ]]; then
                echo "  $formatted_line"
            fi
        done < "$temp_output"
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

