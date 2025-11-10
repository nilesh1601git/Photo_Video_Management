# Photo Management Script

A comprehensive bash script for managing, copying, and organizing photos and videos while preserving timestamps and metadata. Files are automatically renamed to a standardized format based on EXIF CreateDate.

## Script Overview

### `photomanagement.sh` - Main Photo Copy & Organization Script

The primary script for copying photos/videos to STAGE2 directory with automatic renaming and advanced features.

**Key Concept:**
- **STAGE2**: Working copy with files renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate
- **Flat Structure**: All files stored in a single directory (no subdirectories)
- **Automatic Renaming**: Files are renamed based on EXIF CreateDate for consistent naming

#### Features

✅ **Automatic Renaming**: Files renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate  
✅ **STAGE2 Copy**: Files copied to STAGE2 with standardized names  
✅ **Timestamp Preservation**: Maintains original file modification times  
✅ **EXIF Metadata Support**: Extract dates from EXIF data for renaming (requires exiftool)  
✅ **File Verification**: MD5 checksum verification of copied files  
✅ **Progress Reporting**: Visual progress bar for large batches with real-time updates  
✅ **Detailed Logging**: Create comprehensive log files with timestamps  
✅ **Structured Logging**: CSV format log with filename mappings and date tags  
✅ **Smart Duplicate Handling**: Checksum-based duplicate detection - skip identical files  
✅ **Move Mode**: Move files instead of copying (delete source after successful copy)  
✅ **Remark Management**: Set, get, and display remarks/comments stored in EXIF ImageDescription and UserComment tags  
✅ **Date Tag Display**: Show all date-related EXIF tags  
✅ **Multiple Format Support**: JPG, JPEG, PNG, AVI, MOV, MP4, M4V  
✅ **Modular Architecture**: Reusable modules in `module/` directory  

#### Usage

```bash
./photomanagement.sh [OPTIONS] [PATTERN]
```

#### Options

| Option | Description |
|--------|-------------|
| `--source <dir>` | Source directory (default: current directory) |
| `--stage2 <dir>` | STAGE2 destination (default: ./STAGE2) |
| `--verify` | Verify copied files using MD5 checksums |
| `--log <file>` | Write detailed log to specified file |
| `--structured-log <file>` | Write structured CSV log with filename mappings and date tags |
| `--progress` | Show progress bar during copy operations (always enabled) |
| `--quiet` | Suppress verbose output |
| `--set-remark <text>` | Set remark/comment for files (stored in EXIF ImageDescription and UserComment) |
| `--get-remark` | Display remark/comment for files |
| `--show-remark` | Show remarks when processing files |
| `--show-dates` | Display date-related EXIF information only (no copying) |
| `--move` | Move files instead of copying (delete source after successful copy to STAGE2) |
| `--limit <number>` | Limit the number of files to process (useful for testing) |
| `-h, --help` | Show help message |

#### Examples

**Basic copy to STAGE2:**
```bash
./photomanagement.sh --source /path/to/photos
```

**Copy with verification:**
```bash
./photomanagement.sh --verify --source /path/to/photos
```

**Full featured backup with logging:**
```bash
./photomanagement.sh --verify --log backup.log --progress --source /path/to/photos
```

**Set remark for all files:**
```bash
./photomanagement.sh --set-remark "Family vacation 2024" --source /path/to/photos
```

**Display remarks for all files:**
```bash
./photomanagement.sh --get-remark --source /path/to/photos
./photomanagement.sh --get-remark --source /path/to/photos "*.jpg"
```

**Show remarks when processing files:**
```bash
./photomanagement.sh --source /path/to/photos --show-remark
```

**Move files instead of copying:**
```bash
./photomanagement.sh --move --source /path/to/photos
```

**Process only first 10 files (useful for testing):**
```bash
./photomanagement.sh --source /path/to/photos --limit 10
```

**Display date-related EXIF information only (no copying):**
```bash
./photomanagement.sh --show-dates --source /path/to/photos
./photomanagement.sh --show-dates --source /path/to/photos "*.jpg"
```

**Complete workflow example (move with remark and verification):**
```bash
./photomanagement.sh \
  --stage2 TEST_DATA/STAGE2 \
  --source TEST_DATA/ \
  --progress \
  --set-remark "Champaign Trip 2017" \
  --move \
  --verify \
  --structured-log mapping.csv
```
This example:
- Uses custom STAGE2 directory
- Shows progress bar during processing
- Sets a remark for all files ("Champaign Trip 2017")
- Moves files (deletes source after successful copy)
- Verifies copied files with MD5 checksums
- Creates structured CSV log with filename mappings

#### File Renaming

**STAGE2 Renaming:**
- Files in STAGE2 are automatically renamed to `YYYYMMDD_HHMMSS.ext` format
- Renaming priority: EXIF CreateDate → DateTimeOriginal → ModifyDate
- For video files: Uses ffprobe for MP4/M4V, falls back to exiftool for other formats
- Fallback: If no EXIF date, uses oldest file stat date (FileModifyDate, FileAccessDate, FileInodeChangeDate)
- If no date available: Uses original filename
- Duplicate filenames get `_001`, `_002`, etc. suffix automatically
- Extension is normalized to lowercase

**Example:**
```
Source: IMG_1234.JPG (EXIF CreateDate: 2023:12:25 14:30:22)
STAGE2: 20231225_143022.jpg
```

**Directory Structure:**
```
STAGE2/
├── 20231225_143022.jpg
├── 20231225_143023.jpg
├── 20240101_000000.mp4
└── 20240115_090000.jpg
```

**Duplicate Detection:**
- Files are checked by MD5 checksum before copying
- If an identical file (by checksum) already exists in STAGE2, the file is skipped
- Different files with same name are copied with `_001`, `_002` suffix
- In move mode, source files are only deleted if successfully copied to STAGE2 (not if skipped)

---

### 2. `verify_stages.sh` - Stage Verification Script

Verify that files in STAGE1 and STAGE2 are identical using MD5 checksums.

**Note:** This script still references STAGE1 for backward compatibility, but the main script now only uses STAGE2.

#### Features

✅ **Checksum Verification**: MD5 hash comparison  
✅ **Size Comparison**: Quick file size checks  
✅ **Missing File Detection**: Find files missing in either stage  
✅ **Detailed Logging**: Log all verification results  
✅ **Comprehensive Reports**: Summary of verification status

#### Usage

```bash
./verify_stages.sh [OPTIONS]
```

#### Options

| Option | Description |
|--------|-------------|
| `--stage1 <dir>` | STAGE1 directory (default: ./STAGE1) |
| `--stage2 <dir>` | STAGE2 directory (default: ./STAGE2) |
| `--log <file>` | Write detailed log to specified file |
| `--quiet` | Suppress verbose output |
| `-h, --help` | Show help message |

#### Examples

**Verify default directories:**
```bash
./verify_stages.sh
```

**Verify custom directories:**
```bash
./verify_stages.sh --stage1 /backup/STAGE1 --stage2 /backup/STAGE2
```

**Verify with logging:**
```bash
./verify_stages.sh --log verification.log
```

#### Exit Codes

- `0`: All files verified successfully
- `1`: Verification failed (mismatches or missing files found)

---

## Installation & Requirements

### Required Tools

**Basic functionality:**
- `bash` (version 4.0+)
- `cp`, `mv`, `touch`, `stat` (standard Unix tools)
- `md5sum` or `md5` (for verification)

**For EXIF date support (required for renaming):**
```bash
# Debian/Ubuntu
sudo apt-get install libimage-exiftool-perl

# macOS
brew install exiftool

# Fedora/RHEL
sudo dnf install perl-Image-ExifTool
```

**For video file support (optional, improves video date extraction):**
```bash
# Debian/Ubuntu
sudo apt-get install ffmpeg

# macOS
brew install ffmpeg
```

### Setup

1. Clone or download the scripts
2. Make them executable:
```bash
chmod +x photomanagement.sh verify_stages.sh
```

3. Optionally, add to your PATH:
```bash
sudo ln -s $(pwd)/photomanagement.sh /usr/local/bin/photomanagement
sudo ln -s $(pwd)/verify_stages.sh /usr/local/bin/verify-stages
```

---

## Workflow Examples

### Complete Backup Workflow

```bash
# 1. Perform backup with all features
./photomanagement.sh \
  --source /media/camera/DCIM \
  --stage2 /backup/STAGE2 \
  --verify \
  --log backup_$(date +%Y%m%d).log \
  --progress \
  --structured-log mapping_$(date +%Y%m%d).csv
```

### Move Workflow with Remarks

```bash
# Move files with remark, verification, and progress tracking
./photomanagement.sh \
  --stage2 TEST_DATA/STAGE2 \
  --source TEST_DATA/ \
  --progress \
  --set-remark "Champaign Trip 2017" \
  --move \
  --verify
```
This workflow:
- Moves files from source (deletes after successful copy to STAGE2)
- Sets a remark ("Champaign Trip 2017") stored in EXIF tags
- Verifies copied files with MD5 checksums
- Shows progress bar during processing
- Uses custom STAGE2 directory

### Incremental Backup

```bash
# Copy new photos (existing files are automatically skipped)
./photomanagement.sh \
  --source /new/photos \
  --verify \
  --log incremental.log
```

---

## File Naming Convention

The script automatically renames files to the format:
```
YYYYMMDD_HHMMSS.ext
YYYYMMDD_HHMMSS_NNN.ext  (with counter for duplicates)
```

Examples:
- `20231225_143022.jpg`
- `20231225_143022_001.jpg` (duplicate)
- `20240101_000000.mp4`

This format is compatible with the other scripts in this repository:
- `rename_by_createdate.sh` - Rename files based on EXIF CreateDate
- `bulk_rename_by_createdate.sh` - Bulk rename files
- `rename_files.sh` - Rename based on file modification time

---

## Structured Log File

The `--structured-log` option creates a CSV file with the following columns:

```
Source_filename,[EXIF]ModifyDate,[EXIF]DateTimeOriginal,[EXIF]CreateDate,[Composite]SubSecCreateDate,[Composite]SubSecDateTimeOriginal,STAGE2,Remark
```

Example:
```
IMG_1234.JPG,20231225_143022,20231225_143022,20231225_143022,,,20231225_143022.jpg,
DSC_5678.jpg,20240115_094510,20240115_094510,20240115_094510,,,20240115_094510.jpg,Family vacation
```

This log file can be opened in spreadsheet applications (Excel, Google Sheets) for analysis.

---

## Troubleshooting

### Issue: "exiftool not found"
**Solution:** Install exiftool (see Installation section). exiftool is required for file renaming.

### Issue: "Neither md5sum nor md5 command found"
**Solution:** Install coreutils package or don't use `--verify`

### Issue: Files not being renamed
**Solution:** 
- Check that exiftool is installed
- Verify files have EXIF metadata
- Check log file for warnings about missing EXIF dates

### Issue: Permission denied
**Solution:** 
```bash
chmod +x photomanagement.sh verify_stages.sh
```

### Issue: Disk space
**Solution:** Check available space before copying:
```bash
df -h /backup
```

---

## Log Files

Log files contain detailed information about each operation:

```
[2024-01-15 14:30:22] Starting photo management process
[2024-01-15 14:30:22] Source: /media/camera/DCIM
[2024-01-15 14:30:22] STAGE2: /backup/STAGE2 (working copy)
[2024-01-15 14:30:23] FILENAME MAPPING: 'IMG_1234.jpg' → '20231225_143022.jpg'
[2024-01-15 14:30:23] SUCCESS: Copied and verified 'IMG_1234.jpg' → '/backup/STAGE2/20231225_143022.jpg'
[2024-01-15 14:30:24] SKIP: Identical file exists (verified): '/backup/STAGE2/20231225_143023.jpg'
[2024-01-15 14:30:25] ERROR: Failed to copy '/media/camera/DCIM/corrupt.jpg'
```

---

## Performance Tips

1. **Use `--verify` selectively**: MD5 calculation is CPU-intensive
2. **Progress bar is always shown**: Provides visual feedback automatically
3. **Use `--quiet` for automated scripts**: Reduces output overhead
4. **Regular verification**: Run `verify_stages.sh` periodically (if using STAGE1)

---

## Modular Architecture

The script uses a modular architecture with reusable modules in the `module/` directory:

- `module/common.sh` - Common utilities (colors, logging, basic utilities)
- `module/file_utils.sh` - File operations (copying, verification, extensions)
- `module/date_utils.sh` - Date extraction and parsing
- `module/exif_utils.sh` - EXIF operations (date extraction, timestamp modification)

See `module/README.md` for detailed module documentation.

---

## License

These scripts are provided as-is for personal and commercial use.
