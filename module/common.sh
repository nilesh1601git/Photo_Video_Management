#!/bin/bash

# common.sh - Common utilities for photo/video management scripts
# This module provides color output, logging, and basic utility functions

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global flag to track if we're in progress mode (for progress bar clearing)
IN_PROGRESS_MODE=false

# Function to clear progress bar line if in progress mode
clear_progress_if_needed() {
    if [[ "$IN_PROGRESS_MODE" == true ]]; then
        printf "\r\033[K"
    fi
}

# Function to print colored messages
print_info() {
    clear_progress_if_needed
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    clear_progress_if_needed
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    clear_progress_if_needed
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    clear_progress_if_needed
    echo -e "${RED}❌ $1${NC}"
}

# Global log file variable (set by scripts that use logging)
LOG_FILE=""

# Function to set log file
set_log_file() {
    LOG_FILE="$1"
    if [[ -n "$LOG_FILE" && "$DRY_RUN" != true ]]; then
        echo "=========================================" > "$LOG_FILE"
        echo "Photo Management Log" >> "$LOG_FILE"
        echo "Started: $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
        echo "=========================================" >> "$LOG_FILE"
        print_success "Logging to: $LOG_FILE"
    elif [[ -n "$LOG_FILE" && "$DRY_RUN" == true ]]; then
        print_info "Would log to: $LOG_FILE"
    fi
}

# Function to write to log file
log_message() {
    local message="$1"
    if [[ -n "$LOG_FILE" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$LOG_FILE"
    fi
}

# Function to close log file
close_log_file() {
    if [[ -n "$LOG_FILE" ]]; then
        log_message "Completed: $(date '+%Y-%m-%d %H:%M:%S')"
        print_success "Log file saved to: $LOG_FILE"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to show usage (to be overridden by scripts)
show_usage() {
    print_error "Usage function not implemented"
    exit 1
}

