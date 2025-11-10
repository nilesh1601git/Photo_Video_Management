# Photo Management - Quick Start Guide

## 💡 Key Concept

- **STAGE2**: Working copy with files renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate
- **Flat Structure**: All files stored in a single directory (no subdirectories)
- **Automatic Renaming**: Files are automatically renamed based on EXIF CreateDate

## 🚀 Quick Commands

### Basic Copy
```bash
# Copy all photos to STAGE2 (files renamed automatically)
./photomanagement.sh --source /path/to/photos
```

### Copy with Verification
```bash
# Copy and verify with MD5 checksums
./photomanagement.sh --verify --source /path/to/photos

# Full featured: verify + log + progress
./photomanagement.sh --verify --log backup.log --progress --source /path/to/photos
```

### Copy from Specific Source
```bash
# Copy from camera/SD card
./photomanagement.sh --source /media/camera/DCIM --verify

# Copy to custom destination
./photomanagement.sh \
  --source /path/to/photos \
  --stage2 /external/STAGE2 \
  --verify
```

### Copy Specific Files
```bash
# Only JPG files
./photomanagement.sh --source /path/to/photos "*.JPG"

# Specific date pattern
./photomanagement.sh --source /path/to/photos "20231225_*.jpg"

# Multiple patterns (run separately)
./photomanagement.sh --source /path/to/photos "*.JPG"
./photomanagement.sh --source /path/to/photos "*.MP4"
```

### Remark Management
```bash
# Set remark for all files
./photomanagement.sh --set-remark "Family vacation 2024" --source /path/to/photos

# Display remarks for all files
./photomanagement.sh --get-remark --source /path/to/photos

# Display remarks with pattern
./photomanagement.sh --get-remark --source /path/to/photos "*.jpg"
./photomanagement.sh --get-remark TEST_DATA/*

# Show remarks when processing files
./photomanagement.sh --source /path/to/photos --show-remark
```

### Move Files (Delete Source)
```bash
# Move files instead of copying (delete source after successful copy)
./photomanagement.sh --move --source /path/to/photos

# Move with other options
./photomanagement.sh --move --verify --source /path/to/photos

# Complete workflow: move with remark, verification, and progress
./photomanagement.sh \
  --stage2 TEST_DATA/STAGE2 \
  --source TEST_DATA/ \
  --progress \
  --set-remark "Champaign Trip 2017" \
  --move \
  --verify
```

### Display Date Information
```bash
# Display date-related EXIF information only (no copying)
./photomanagement.sh --show-dates --source /path/to/photos
./photomanagement.sh --show-dates --source /path/to/photos "*.jpg"
```

### Structured Logging
```bash
# Create CSV log with filename mappings and date tags
./photomanagement.sh \
  --source /path/to/photos \
  --structured-log mapping.csv \
  --verify
```

## 📋 Common Workflows

### Workflow 1: Import from Camera
```bash
# 1. Import with verification
./photomanagement.sh \
  --source /media/camera/DCIM \
  --verify \
  --log import_$(date +%Y%m%d).log \
  --progress \
  --structured-log mapping_$(date +%Y%m%d).csv

# 2. Verify (if using verify_stages.sh)
./verify_stages.sh --log verify_$(date +%Y%m%d).log
```

### Workflow 2: Organize Existing Photos
```bash
# Organize photos already in current directory
./photomanagement.sh --source . --verify
```

### Workflow 3: Incremental Backup
```bash
# Add new photos (existing files automatically skipped)
./photomanagement.sh \
  --source /new/photos \
  --log incremental.log
```

## 🎯 Feature Combinations

| What You Want | Command |
|---------------|---------|
| Simple copy | `./photomanagement.sh --source /path` |
| Copy with verification | `./photomanagement.sh --verify --source /path` |
| Show progress | `./photomanagement.sh --progress --source /path` (always enabled) |
| Save log | `./photomanagement.sh --log backup.log --source /path` |
| Structured CSV log | `./photomanagement.sh --structured-log mapping.csv --source /path` |
| Set remark | `./photomanagement.sh --set-remark "Text" --source /path` |
| Get remarks | `./photomanagement.sh --get-remark --source /path` |
| Move files | `./photomanagement.sh --move --source /path` |
| Show dates only | `./photomanagement.sh --show-dates --source /path` |
| Everything! | `./photomanagement.sh --verify --log backup.log --progress --structured-log mapping.csv --source /path` |

## 📁 Directory Structure

### STAGE2 (Flat Structure with Renamed Files):
```
STAGE2/
├── 20231225_143022.jpg
├── 20231225_143023.jpg
├── 20240101_000000.mp4
└── 20240115_090000.jpg
```

Note: Files are automatically renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate

## ⚙️ Options Reference

| Option | What It Does |
|--------|--------------|
| `--source <dir>` | Where to copy from |
| `--stage2 <dir>` | STAGE2 = destination location (default: ./STAGE2) |
| `--verify` | Check copied files with MD5 |
| `--log <file>` | Save detailed log |
| `--structured-log <file>` | Save CSV log with filename mappings and date tags |
| `--progress` | Show progress bar (always enabled) |
| `--quiet` | Less output |
| `--set-remark <text>` | Set comment/remark for files (stored in EXIF) |
| `--get-remark` | Display remarks/comments for files |
| `--show-remark` | Show remarks when processing files |
| `--show-dates` | Display date-related EXIF information only (no copying) |
| `--move` | Move files (delete source after successful copy) |
| `--limit <number>` | Limit the number of files to process (useful for testing) |

## 🔧 Requirements

**Basic:**
- bash, cp, mv, touch, stat

**For `--verify`:**
- md5sum (Linux) or md5 (macOS)

**For file renaming (required):**
```bash
# Ubuntu/Debian
sudo apt-get install libimage-exiftool-perl

# macOS
brew install exiftool
```

**For video file support (optional, improves video date extraction):**
```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# macOS
brew install ffmpeg
```

## 💡 Tips

1. **STAGE2 is your working copy** - files are renamed to YYYYMMDD_HHMMSS.ext format
2. Use `--verify` for important backups
3. Use `--log` to track what was copied
4. Use `--structured-log` to create CSV files for analysis
5. Existing files are automatically skipped by checksum (no duplicates)
6. **Move mode safety**: Source files are only deleted if successfully copied to STAGE2 (not if skipped)
7. Use `--set-remark` to add notes/comments to photos (visible in PhotoPrism and other tools)
8. Use `--get-remark` to view all remarks without processing files
9. Use `--show-dates` to inspect EXIF date information before copying
10. Progress bar is always shown automatically

## 🆘 Troubleshooting

**"exiftool not found"**
→ Install exiftool (required for file renaming)

**"Permission denied"**
→ Run: `chmod +x photomanagement.sh verify_stages.sh`

**Files not being renamed**
→ Check that exiftool is installed
→ Verify files have EXIF metadata
→ Check log file for warnings

**Slow copying**
→ Remove `--verify` for faster copies

## 📞 Getting Help

```bash
./photomanagement.sh --help
./verify_stages.sh --help
```

See `PHOTOMANAGEMENT_README.md` for complete documentation.
