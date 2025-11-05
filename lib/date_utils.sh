#!/bin/bash

# date_utils.sh - Date extraction and parsing utilities
# This module provides functions to extract dates from filenames and parse them

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/common.sh"

# Function to extract date from filename (format: YYYYMMDD_HHMMSS)
# Returns: YYYY:MM:DD format on success, empty string on failure
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
# Input format: YYYY:MM:DD HH:MM:SS or YYYY:MM:DD
# Returns: YYYY/MM format on success, empty string on failure
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

# Function to extract date from filename and return YYYY/MM path
# Returns: YYYY/MM format on success, empty string on failure
get_date_path_from_filename() {
    local file="$1"
    local date_str=$(get_filename_date "$file")
    
    if [[ -n "$date_str" ]]; then
        parse_date "$date_str"
        return $?
    fi
    
    return 1
}

# Function to get modification date from file
# Returns: YYYYMMDD_HHMMSS format
get_file_modification_date() {
    local file="$1"
    stat -c %y "$file" | awk '{print $1"_"$2}' | sed 's/[-:]//g' | cut -c1-15
}

# Function to format date string for display
# Input: YYYY:MM:DD HH:MM:SS or similar
# Returns: Formatted date string
format_date_display() {
    local date_str="$1"
    echo "$date_str" | sed 's/:/ /g' | awk '{print $1 "-" $2 "-" $3 " " $4 ":" $5 ":" $6}'
}

