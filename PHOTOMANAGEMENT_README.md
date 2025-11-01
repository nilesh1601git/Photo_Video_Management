# Photo Management Scripts

A comprehensive set of bash scripts for managing, copying, and organizing photos and videos while preserving timestamps and metadata.

## Scripts Overview

### 1. `photomanagement.sh` - Main Photo Copy & Organization Script

The primary script for copying photos/videos to STAGE1 (flat backup) and STAGE2 (organized working copy) directories with advanced features.

**Key Concept:**
- **STAGE1**: Pristine backup with original filenames (no organization) - for safety
- **STAGE2**: Working copy with optional date organization - for operations and browsing

#### Features

✅ **Dual Stage Backup**: Copies files to both STAGE1 (flat) and STAGE2 (organized) directories
✅ **STAGE1 - Flat Backup**: Pristine backup with original filenames, no organization
✅ **STAGE2 - Organized Copy**: Optional date-based organization for easy browsing
✅ **Timestamp Preservation**: Maintains original file modification times in both stages
✅ **Date-Based Organization**: Organize STAGE2 files into YYYY/MM subdirectories
✅ **EXIF Metadata Support**: Extract dates from EXIF data for STAGE2 organization (requires exiftool)
✅ **File Verification**: MD5 checksum verification of STAGE2 files
✅ **Progress Reporting**: Visual progress bar for large batches
✅ **Detailed Logging**: Create comprehensive log files
✅ **Dry Run Mode**: Preview operations without making changes
✅ **Smart Duplicate Handling**: Skip identical files, backup different ones
✅ **Multiple Format Support**: JPG, JPEG, PNG, AVI, MOV, MP4, M4V

#### Usage

```bash
./photomanagement.sh [OPTIONS] [PATTERN]
```

#### Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be copied without actually copying |
| `--source <dir>` | Source directory (default: current directory) |
| `--stage1 <dir>` | STAGE1 destination - flat backup (default: ./STAGE1) |
| `--stage2 <dir>` | STAGE2 destination - organized copy (default: ./STAGE2) |
| `--organize-by-date` | Organize STAGE2 files into YYYY/MM subdirectories |
| `--use-exif-date` | Use EXIF date for STAGE2 organization (requires exiftool) |
| `--verify` | Verify STAGE2 copied files using MD5 checksums |
| `--log <file>` | Write detailed log to specified file |
| `--progress` | Show progress bar during copy operations |
| `--quiet` | Suppress verbose output |
| `-h, --help` | Show help message |

#### Examples

**Basic copy to STAGE1 and STAGE2:**
```bash
./photomanagement.sh
```

**Dry run to preview operations:**
```bash
./photomanagement.sh --dry-run
```

**Copy from specific source with custom destinations:**
```bash
./photomanagement.sh --source /path/to/photos --stage1 /backup/STAGE1 --stage2 /backup/STAGE2
```

**Copy to STAGE1 (flat) and organize STAGE2 by date from filename:**
```bash
./photomanagement.sh --organize-by-date "*.JPG"
```

**Copy to STAGE1 (flat) and organize STAGE2 by EXIF date with verification:**
```bash
./photomanagement.sh --organize-by-date --use-exif-date --verify
```

**Full featured backup with logging:**
```bash
./photomanagement.sh --organize-by-date --use-exif-date --verify --log backup.log --progress
```

**Copy only specific date pattern:**
```bash
./photomanagement.sh --organize-by-date "20231225_*.jpg"
```

#### Date Organization

**STAGE1** always maintains a flat structure (no organization):
```
STAGE1/
├── 20231125_143022.jpg
├── 20231125_143023.jpg
├── 20231225_120000.jpg
├── 20231225_120001.jpg
└── 20240101_000000.jpg
```

**STAGE2** can be organized by date when using `--organize-by-date`:
```
STAGE2/
├── 2023/
│   ├── 11/
│   │   ├── 20231125_143022.jpg
│   │   └── 20231125_143023.jpg
│   └── 12/
│       ├── 20231225_120000.jpg
│       └── 20231225_120001.jpg
└── 2024/
    └── 01/
        └── 20240101_000000.jpg
```

**Date Source Priority (for STAGE2 organization):**
1. If `--use-exif-date` is specified: EXIF DateTimeOriginal → CreateDate → ModifyDate
2. Fallback: Filename pattern (YYYYMMDD_HHMMSS)
3. If no date found: Copy to STAGE2 root directory

---

### 2. `verify_stages.sh` - Stage Verification Script

Verify that files in STAGE1 and STAGE2 are identical using MD5 checksums.

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

**For EXIF date support:**
```bash
# Debian/Ubuntu
sudo apt-get install libimage-exiftool-perl

# macOS
brew install exiftool

# Fedora/RHEL
sudo dnf install perl-Image-ExifTool
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
# 1. Dry run to preview
./photomanagement.sh --dry-run --organize-by-date --use-exif-date

# 2. Perform actual backup with all features
./photomanagement.sh \
  --source /media/camera/DCIM \
  --stage1 /backup/STAGE1 \
  --stage2 /backup/STAGE2 \
  --organize-by-date \
  --use-exif-date \
  --verify \
  --log backup_$(date +%Y%m%d).log \
  --progress

# 3. Verify both stages match
./verify_stages.sh \
  --stage1 /backup/STAGE1 \
  --stage2 /backup/STAGE2 \
  --log verify_$(date +%Y%m%d).log
```

### Incremental Backup

```bash
# Copy new photos (existing files are automatically skipped)
./photomanagement.sh \
  --source /new/photos \
  --organize-by-date \
  --verify \
  --log incremental.log
```

### Organize Existing Collection

```bash
# Organize already copied files by date
cd /backup/STAGE1
../photomanagement.sh \
  --source . \
  --stage1 ./organized \
  --stage2 /backup/STAGE2/organized \
  --organize-by-date \
  --use-exif-date
```

---

## File Naming Convention

The scripts work best with files named in the format:
```
YYYYMMDD_HHMMSS.ext
YYYYMMDD_HHMMSS_NNN.ext  (with counter)
```

Examples:
- `20231225_143022.jpg`
- `20231225_143022_001.jpg`
- `20240101_000000.mp4`

This format is compatible with the other scripts in this repository:
- `rename_by_createdate.sh` - Rename files based on EXIF CreateDate
- `bulk_rename_by_createdate.sh` - Bulk rename files
- `rename_files.sh` - Rename based on file modification time

---

## Troubleshooting

### Issue: "exiftool not found"
**Solution:** Install exiftool (see Installation section) or don't use `--use-exif-date`

### Issue: "Neither md5sum nor md5 command found"
**Solution:** Install coreutils package or don't use `--verify`

### Issue: Files not organizing by date
**Solution:** 
- Check filename format matches YYYYMMDD_HHMMSS pattern
- Use `--use-exif-date` if files have EXIF metadata
- Check that exiftool is installed when using `--use-exif-date`

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
[2024-01-15 14:30:22] STAGE1: /backup/STAGE1
[2024-01-15 14:30:22] STAGE2: /backup/STAGE2
[2024-01-15 14:30:23] SUCCESS: Copied and verified '/media/camera/DCIM/IMG_1234.jpg' → '/backup/STAGE1/2024/01/20240115_143022.jpg'
[2024-01-15 14:30:24] SKIP: Identical file exists (verified): '/backup/STAGE1/2024/01/20240115_143023.jpg'
[2024-01-15 14:30:25] ERROR: Failed to copy '/media/camera/DCIM/corrupt.jpg'
```

---

## Performance Tips

1. **Use `--verify` selectively**: MD5 calculation is CPU-intensive
2. **Use `--progress` for large batches**: Provides visual feedback
3. **Use `--quiet` for automated scripts**: Reduces output overhead
4. **Organize by date**: Makes browsing and management easier
5. **Regular verification**: Run `verify_stages.sh` periodically

---

## License

These scripts are provided as-is for personal and commercial use.

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

