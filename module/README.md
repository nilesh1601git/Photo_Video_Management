# Photo/Video Management Modules

This directory contains reusable modules for photo and video management operations.

## Module Structure

### `common.sh`
Common utilities including:
- Color output functions (`print_info`, `print_success`, `print_warning`, `print_error`)
- Logging functionality (`log_message`, `set_log_file`, `close_log_file`)
- Command existence checking (`command_exists`)

### `file_utils.sh`
File operations utilities:
- File extension validation (`is_supported_extension`)
- MD5 checksum calculation (`calculate_md5`)
- File size operations (`get_file_size`, `files_same_size`)
- File comparison (`files_same_checksum`)
- File copying with verification (`copy_file_with_verification`)
- File finding (`find_files`)

### `date_utils.sh`
Date extraction and parsing utilities:
- Filename date extraction (`get_filename_date`)
- Date parsing (`parse_date`)
- Date path generation (`get_date_path_from_filename`)
- File modification date extraction (`get_file_modification_date`)
- Date formatting (`format_date_display`)

### `exif_utils.sh`
EXIF metadata utilities:
- EXIF tool checking (`check_exiftool`)
- EXIF date extraction (`get_exif_date`, `get_exif_createdate`)
- Date path from EXIF (`get_date_path_from_exif`)
- EXIF timestamp modification (`modify_exif_timestamp_from_filename`)
- Best available date (`get_best_available_date`)

### `load_modules.sh`
Convenience script to load all modules at once.

## Usage

To use these modules in your scripts, source them at the beginning:

```bash
#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all modules
source "$SCRIPT_DIR/module/load_modules.sh"

# Or load specific modules
source "$SCRIPT_DIR/module/common.sh"
source "$SCRIPT_DIR/module/file_utils.sh"
```

## Module Dependencies

- `common.sh` - No dependencies (base module)
- `file_utils.sh` - Depends on `common.sh`
- `date_utils.sh` - Depends on `common.sh`
- `exif_utils.sh` - Depends on `common.sh` and `date_utils.sh`
- `load_modules.sh` - Loads all modules in correct order

## Supported File Extensions

The following file extensions are supported by default:
- Images: jpg, JPG, jpeg, JPEG, png, PNG
- Videos: avi, AVI, mov, MOV, mp4, MP4, m4v, M4V

