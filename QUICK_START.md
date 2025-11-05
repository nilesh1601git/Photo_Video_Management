# Photo Management - Quick Start Guide

## 💡 Key Concept

- **STAGE1**: Flat backup with original filenames (pristine backup - no organization)
- **STAGE2**: Working copy with optional date organization (for browsing and operations)

## 🚀 Quick Commands

### Basic Copy (No Organization)
```bash
# Preview what will be copied
./photomanagement.sh --dry-run

# Copy all photos to STAGE1 (flat) and STAGE2 (flat)
./photomanagement.sh
```

### Copy with Date Organization (STAGE2 only)
```bash
# STAGE1: flat backup, STAGE2: organized by filename date (YYYYMMDD_HHMMSS format)
./photomanagement.sh --organize-by-date

# STAGE1: flat backup, STAGE2: organized by EXIF date (requires exiftool)
./photomanagement.sh --organize-by-date --use-exif-date
```

### Copy with Verification
```bash
# Copy and verify with MD5 checksums
./photomanagement.sh --verify

# Full featured: organize + verify + log
./photomanagement.sh --organize-by-date --use-exif-date --verify --log backup.log
```

### Copy from Specific Source
```bash
# Copy from camera/SD card
./photomanagement.sh --source /media/camera/DCIM --organize-by-date --verify

# Copy to custom destinations
./photomanagement.sh \
  --source /path/to/photos \
  --stage1 /backup/STAGE1 \
  --stage2 /external/STAGE2 \
  --organize-by-date
```

### Copy Specific Files
```bash
# Only JPG files
./photomanagement.sh "*.JPG"

# Specific date
./photomanagement.sh "20231225_*.jpg"

# Multiple patterns (run separately)
./photomanagement.sh "*.JPG"
./photomanagement.sh "*.MP4"
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
./photomanagement.sh --move --organize-by-date --verify

# Complete workflow: move with remark, verification, and progress
./photomanagement.sh \
  --stage1 TEST_DATA/STAGE1 \
  --stage2 TEST_DATA/STAGE2 \
  --source TEST_DATA/ \
  --progress \
  --set-remark "Champaign Trip 2017" \
  --move \
  --verify
```

### Verify Stages
```bash
# Verify STAGE1 and STAGE2 are identical
./verify_stages.sh

# Verify with logging
./verify_stages.sh --log verify.log
```

## 📋 Common Workflows

### Workflow 1: Import from Camera
```bash
# 1. Preview
./photomanagement.sh --dry-run --source /media/camera/DCIM --organize-by-date --use-exif-date

# 2. Import with verification
./photomanagement.sh \
  --source /media/camera/DCIM \
  --organize-by-date \
  --use-exif-date \
  --verify \
  --log import_$(date +%Y%m%d).log \
  --progress

# 3. Verify both stages
./verify_stages.sh --log verify_$(date +%Y%m%d).log
```

### Workflow 2: Organize Existing Photos
```bash
# Organize photos already in current directory
./photomanagement.sh --organize-by-date --use-exif-date --verify
```

### Workflow 3: Incremental Backup
```bash
# Add new photos (existing files automatically skipped)
./photomanagement.sh \
  --source /new/photos \
  --organize-by-date \
  --log incremental.log
```

## 🎯 Feature Combinations

| What You Want | Command |
|---------------|---------|
| Simple copy | `./photomanagement.sh` |
| Preview only | `./photomanagement.sh --dry-run` |
| Organize by date | `./photomanagement.sh --organize-by-date` |
| Use EXIF dates | `./photomanagement.sh --organize-by-date --use-exif-date` |
| Verify copies | `./photomanagement.sh --verify` |
| Show progress | `./photomanagement.sh --progress` |
| Save log | `./photomanagement.sh --log backup.log` |
| Set remark | `./photomanagement.sh --set-remark "Text" --source /path` |
| Get remarks | `./photomanagement.sh --get-remark --source /path` |
| Move files | `./photomanagement.sh --move --source /path` |
| Everything! | `./photomanagement.sh --organize-by-date --use-exif-date --verify --log backup.log --progress` |

## 📁 Directory Structure

### Without `--organize-by-date` (STAGE1 flat, STAGE2 flat with renamed files):
```
STAGE1/                          STAGE2/
├── IMG_0013.JPG                 ├── 20231125_143022.jpg
├── IMG_0018.JPG                 ├── 20231125_143023.jpg
└── video.MOV                     └── 20240101_000000.mp4
```
Note: STAGE2 files are renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate

### With `--organize-by-date` (STAGE1 flat, STAGE2 organized with renamed files):
```
STAGE1/                          STAGE2/
├── IMG_0013.JPG                 ├── 2023/
├── IMG_0018.JPG                 │   └── 12/
└── video.MOV                     │       ├── 20231225_143022.jpg
                                 │       └── 20231225_143023.jpg
                                 └── 2024/
                                     └── 01/
                                         └── 20240101_000000.mp4
```
Note: STAGE1 preserves original filenames, STAGE2 files are renamed and organized by date

## ⚙️ Options Reference

| Option | What It Does |
|--------|--------------|
| `--dry-run` | Preview without copying |
| `--source <dir>` | Where to copy from |
| `--stage1 <dir>` | STAGE1 = flat backup location |
| `--stage2 <dir>` | STAGE2 = organized copy location |
| `--organize-by-date` | Create YYYY/MM folders in STAGE2 only |
| `--use-exif-date` | Get date from photo metadata for STAGE2 |
| `--verify` | Check STAGE2 files with MD5 |
| `--log <file>` | Save detailed log |
| `--progress` | Show progress bar |
| `--quiet` | Less output |
| `--set-remark <text>` | Set comment/remark for files (stored in EXIF) |
| `--get-remark` | Display remarks/comments for files |
| `--show-remark` | Show remarks when processing files |
| `--move` | Move files (delete source after successful copy) |

## 🔧 Requirements

**Basic:**
- bash, cp, mv, touch, stat

**For `--verify`:**
- md5sum (Linux) or md5 (macOS)

**For `--use-exif-date`:**
```bash
# Ubuntu/Debian
sudo apt-get install libimage-exiftool-perl

# macOS
brew install exiftool
```

## 💡 Tips

1. **Always test with `--dry-run` first!**
2. **STAGE1 is your safety net** - always kept flat with original filenames
3. **STAGE2 is for working** - files are renamed to YYYYMMDD_HHMMSS.ext format and can be organized by date
4. Use `--verify` for important backups (checks STAGE2)
5. Use `--log` to track what was copied
6. Run `verify_stages.sh` after large copies to ensure both stages match
7. Existing files are automatically skipped by checksum (no duplicates)
8. **Move mode safety**: Source files are only deleted if successfully copied to both stages (not if skipped)
9. Use `--set-remark` to add notes/comments to photos (visible in PhotoPrism and other tools)
10. Use `--get-remark` to view all remarks without processing files

## 🆘 Troubleshooting

**"exiftool not found"**
→ Install exiftool or remove `--use-exif-date`

**"Permission denied"**
→ Run: `chmod +x photomanagement.sh verify_stages.sh`

**Files not organizing by date**
→ Check filename format: YYYYMMDD_HHMMSS.ext
→ Or use `--use-exif-date` if photos have metadata

**Slow copying**
→ Remove `--verify` for faster copies (verify later with verify_stages.sh)

## 📞 Getting Help

```bash
./photomanagement.sh --help
./verify_stages.sh --help
```

See `PHOTOMANAGEMENT_README.md` for complete documentation.

