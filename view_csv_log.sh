#!/bin/bash

# view_csv_log.sh
# Displays CSV log files in a tabular format
# Usage: ./view_csv_log.sh [csv_file]

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/module/common.sh"

# Default CSV file
CSV_FILE="${1:-log.csv}"

# Check if file exists
if [[ ! -f "$CSV_FILE" ]]; then
    print_error "CSV file '$CSV_FILE' not found."
    exit 1
fi

# Check if file is empty
if [[ ! -s "$CSV_FILE" ]]; then
    print_warning "CSV file '$CSV_FILE' is empty."
    exit 0
fi

# Function to display CSV in tabular format using column command
display_table() {
    local file="$1"
    
    # Check if column command is available
    if command -v column >/dev/null 2>&1; then
        # Use column command for nice formatting
        # -t: create table, -s,: use comma as separator
        # -N: specify column names for better alignment
        column -t -s',' "$file" | less -S
    else
        # Fallback: use awk for basic formatting with better column widths
        awk -F',' '
        BEGIN {
            # Define column widths (adjust as needed)
            widths[1] = 50   # Source_filename
            widths[2] = 18   # ModifyDate
            widths[3] = 18   # DateTimeOriginal
            widths[4] = 18   # CreateDate
            widths[5] = 20   # SubSecCreateDate
            widths[6] = 20   # SubSecDateTimeOriginal
            widths[7] = 30  # STAGE1
            widths[8] = 30  # STAGE2
            widths[9] = 30  # Remark
        }
        {
            for (i=1; i<=NF; i++) {
                # Truncate if too long, pad if too short
                value = $i
                if (length(value) > widths[i]) {
                    value = substr(value, 1, widths[i]-3) "..."
                }
                printf "%-" widths[i] "s", value
            }
            printf "\n"
        }' "$file" | less -S
    fi
}

# Function to display summary statistics
display_summary() {
    local file="$1"
    local total_lines=$(wc -l < "$file" | tr -d ' ')
    local total_files=$((total_lines - 1))  # Subtract header
    
    print_info "========================================="
    print_info "CSV Log Summary"
    print_info "========================================="
    print_info "File: $file"
    print_info "Total entries: $total_files"
    
    # Count skipped files (skip header line)
    # STAGE1 is column 7, STAGE2 is column 8 (after removing File-related columns)
    local skipped_stage1=$(tail -n +2 "$file" | awk -F',' '$7 == "Skipped" {count++} END {print count+0}' 2>/dev/null || echo "0")
    local skipped_stage2=$(tail -n +2 "$file" | awk -F',' '$8 == "Skipped" {count++} END {print count+0}' 2>/dev/null || echo "0")
    local skipped_both=$(tail -n +2 "$file" | awk -F',' '$7 == "Skipped" && $8 == "Skipped" {count++} END {print count+0}' 2>/dev/null || echo "0")
    
    # Remove any newlines from counts
    skipped_stage1=$(echo "$skipped_stage1" | tr -d '\n\r')
    skipped_stage2=$(echo "$skipped_stage2" | tr -d '\n\r')
    skipped_both=$(echo "$skipped_both" | tr -d '\n\r')
    
    if [[ $skipped_stage1 -gt 0 ]] || [[ $skipped_stage2 -gt 0 ]]; then
        print_warning "Skipped in STAGE1: $skipped_stage1"
        print_warning "Skipped in STAGE2: $skipped_stage2"
        if [[ $skipped_both -gt 0 ]]; then
            print_warning "Skipped in both: $skipped_both"
        fi
    fi
    
    # Count files with remarks
    local with_remarks=$(awk -F',' 'NR>1 && $NF != "" {count++} END {print count+0}' "$file")
    if [[ $with_remarks -gt 0 ]]; then
        print_success "Files with remarks: $with_remarks"
    fi
    
    print_info "========================================="
    echo ""
}

# Main execution
print_info "Displaying CSV log: $CSV_FILE"
echo ""

# Display summary
display_summary "$CSV_FILE"

# Display table
print_info "Press 'q' to quit, arrow keys to scroll"
echo ""
display_table "$CSV_FILE"

