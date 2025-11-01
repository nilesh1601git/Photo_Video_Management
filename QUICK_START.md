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
| Everything! | `./photomanagement.sh --organize-by-date --use-exif-date --verify --log backup.log --progress` |

## 📁 Directory Structure

### Without `--organize-by-date` (both stages flat):
```
STAGE1/                          STAGE2/
├── 20231225_143022.jpg          ├── 20231225_143022.jpg
├── 20231225_143023.jpg          ├── 20231225_143023.jpg
└── 20240101_000000.mp4          └── 20240101_000000.mp4
```

### With `--organize-by-date` (STAGE1 flat, STAGE2 organized):
```
STAGE1/                          STAGE2/
├── 20231225_143022.jpg          ├── 2023/
├── 20231225_143023.jpg          │   └── 12/
└── 20240101_000000.mp4          │       ├── 20231225_143022.jpg
                                 │       └── 20231225_143023.jpg
                                 └── 2024/
                                     └── 01/
                                         └── 20240101_000000.mp4
```

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
3. **STAGE2 is for working** - organize it with `--organize-by-date` for easy browsing
4. Use `--verify` for important backups (checks STAGE2)
5. Use `--log` to track what was copied
6. Run `verify_stages.sh` after large copies to ensure both stages match
7. Existing files are automatically skipped (no duplicates)

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

