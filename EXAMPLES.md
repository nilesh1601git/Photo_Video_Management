# Photo Management - Practical Examples

## Example 1: Simple Copy (No Organization)

### Command
```bash
./photomanagement.sh --source /camera/photos
```

### What Happens
1. All photos copied to STAGE1 (flat)
2. All photos copied to STAGE2 (flat)
3. Original filenames preserved
4. Timestamps preserved

### Result
```
STAGE1/                          STAGE2/
├── IMG_1234.jpg                 ├── IMG_1234.jpg
├── IMG_1235.jpg                 ├── IMG_1235.jpg
├── VID_5678.mp4                 ├── VID_5678.mp4
└── PHOTO_9999.png               └── PHOTO_9999.png
```

---

## Example 2: Organize STAGE2 by Filename Date

### Command
```bash
./photomanagement.sh --source /camera/photos --organize-by-date
```

### What Happens
1. All photos copied to STAGE1 (flat - no organization)
2. Photos copied to STAGE2 organized into YYYY/MM folders
3. Date extracted from filename (YYYYMMDD_HHMMSS format)
4. Timestamps preserved

### Result
```
STAGE1/                          STAGE2/
├── 20231225_143022.jpg          ├── 2023/
├── 20231225_143023.jpg          │   └── 12/
├── 20240101_120000.jpg          │       ├── 20231225_143022.jpg
└── 20240115_090000.mp4          │       └── 20231225_143023.jpg
                                 └── 2024/
                                     ├── 01/
                                     │   └── 20240101_120000.jpg
                                     └── 01/
                                         └── 20240115_090000.mp4
```

---

## Example 3: Organize STAGE2 by EXIF Date

### Command
```bash
./photomanagement.sh --source /camera/photos --organize-by-date --use-exif-date
```

### What Happens
1. All photos copied to STAGE1 (flat)
2. Photos copied to STAGE2 organized by EXIF date
3. Date extracted from EXIF DateTimeOriginal/CreateDate
4. Falls back to filename if no EXIF data
5. Timestamps preserved

### Result
```
STAGE1/                          STAGE2/
├── IMG_1234.jpg                 ├── 2023/
├── IMG_1235.jpg                 │   └── 12/
├── VID_5678.mp4                 │       ├── IMG_1234.jpg  (EXIF: 2023-12-25)
└── PHOTO_9999.png               │       └── IMG_1235.jpg  (EXIF: 2023-12-26)
                                 └── 2024/
                                     └── 01/
                                         ├── VID_5678.mp4  (filename: 20240101)
                                         └── PHOTO_9999.png (EXIF: 2024-01-15)
```

---

## Example 4: Full Featured Backup with Verification

### Command
```bash
./photomanagement.sh \
  --source /camera/photos \
  --organize-by-date \
  --use-exif-date \
  --verify \
  --log backup_$(date +%Y%m%d).log \
  --progress
```

### What Happens
1. All photos copied to STAGE1 (flat)
2. Photos copied to STAGE2 organized by EXIF date
3. Each STAGE2 file verified with MD5 checksum
4. Progress bar shown during copy
5. Detailed log written to file
6. Timestamps preserved

### Console Output
```
ℹ️  Starting photo management process...
ℹ️  Source: /camera/photos
ℹ️  STAGE1: ./STAGE1 (flat backup - no organization)
ℹ️  STAGE2: ./STAGE2 (working copy)
ℹ️  STAGE2 Organization: By date (YYYY/MM)
ℹ️  Date source: EXIF metadata (with filename fallback)
ℹ️  Verification: Enabled for STAGE2 (MD5 checksums)

Progress: [####################                              ] 40% (2/5)

✅ Copied to STAGE1: 'IMG_1234.jpg' → './STAGE1/IMG_1234.jpg'
✅ Copied and verified to STAGE2: 'IMG_1234.jpg' → './STAGE2/2023/12/IMG_1234.jpg'
✅ Copied to STAGE1: 'IMG_1235.jpg' → './STAGE1/IMG_1235.jpg'
✅ Copied and verified to STAGE2: 'IMG_1235.jpg' → './STAGE2/2023/12/IMG_1235.jpg'

ℹ️  =========================================
ℹ️  SUMMARY
ℹ️  =========================================
ℹ️  Total files processed: 5
✅ Successfully copied: 5
✅ Verified copies: 5
ℹ️  =========================================
✅ Log file saved to: backup_20240115.log
```

### Log File Content
```
[2024-01-15 14:30:22] Starting photo management process
[2024-01-15 14:30:22] Source: /camera/photos
[2024-01-15 14:30:22] STAGE1: ./STAGE1 (flat backup)
[2024-01-15 14:30:22] STAGE2: ./STAGE2 (working copy)
[2024-01-15 14:30:22] Organize by date: true
[2024-01-15 14:30:22] Use EXIF date: true
[2024-01-15 14:30:22] Verify copy: true
[2024-01-15 14:30:23] SUCCESS STAGE1: Copied 'IMG_1234.jpg' → './STAGE1/IMG_1234.jpg'
[2024-01-15 14:30:23] SUCCESS STAGE2: Copied and verified 'IMG_1234.jpg' → './STAGE2/2023/12/IMG_1234.jpg'
[2024-01-15 14:30:24] SUCCESS STAGE1: Copied 'IMG_1235.jpg' → './STAGE1/IMG_1235.jpg'
[2024-01-15 14:30:24] SUCCESS STAGE2: Copied and verified 'IMG_1235.jpg' → './STAGE2/2023/12/IMG_1235.jpg'
[2024-01-15 14:30:30] Total files processed: 5
[2024-01-15 14:30:30] Successfully copied: 5
[2024-01-15 14:30:30] Verified copies: 5
[2024-01-15 14:30:30] Completed: 2024-01-15 14:30:30
```

---

## Example 5: Dry Run (Preview Mode)

### Command
```bash
./photomanagement.sh --dry-run --source /camera/photos --organize-by-date --use-exif-date
```

### What Happens
1. No files are actually copied
2. Shows what would be copied
3. Shows where files would go
4. Safe to run multiple times

### Console Output
```
ℹ️  DRY RUN MODE - No files will be copied
ℹ️  Would create directories: ./STAGE1 and ./STAGE2
ℹ️  Starting photo management process...
ℹ️  Source: /camera/photos
ℹ️  STAGE1: ./STAGE1 (flat backup - no organization)
ℹ️  STAGE2: ./STAGE2 (working copy)
ℹ️  STAGE2 Organization: By date (YYYY/MM)

ℹ️  Would copy to STAGE1: 'IMG_1234.jpg' → './STAGE1/IMG_1234.jpg'
ℹ️  Would copy to STAGE2: 'IMG_1234.jpg' → './STAGE2/2023/12/IMG_1234.jpg'
ℹ️  Would copy to STAGE1: 'IMG_1235.jpg' → './STAGE1/IMG_1235.jpg'
ℹ️  Would copy to STAGE2: 'IMG_1235.jpg' → './STAGE2/2023/12/IMG_1235.jpg'

ℹ️  This was a DRY RUN - no files were actually copied
```

---

## Example 6: Incremental Backup

### Initial Backup
```bash
./photomanagement.sh --source /photos --organize-by-date
```

Result: 100 files copied to STAGE1 and STAGE2

### Add New Photos (Later)
```bash
./photomanagement.sh --source /photos --organize-by-date
```

### What Happens
1. Existing 100 files are skipped (already exist)
2. Only new files are copied
3. No duplicates created
4. Fast operation

### Console Output
```
⚠️  Skipping STAGE1 'IMG_1234.jpg' - file with same size exists
⚠️  Skipping STAGE2 'IMG_1234.jpg' - file with same size exists
✅ Copied to STAGE1: 'IMG_NEW.jpg' → './STAGE1/IMG_NEW.jpg'
✅ Copied to STAGE2: 'IMG_NEW.jpg' → './STAGE2/2024/01/IMG_NEW.jpg'

ℹ️  Total files processed: 101
✅ Successfully copied: 1
⚠️  Skipped: 100
```

---

## Example 7: Verify Stages Match

### Command
```bash
./verify_stages.sh
```

### What Happens
1. Compares all files in STAGE1 with STAGE2
2. Checks file sizes
3. Calculates MD5 checksums
4. Reports any mismatches

### Console Output (Success)
```
ℹ️  Starting verification...
ℹ️  STAGE1: ./STAGE1
ℹ️  STAGE2: ./STAGE2

✅ Verified: IMG_1234.jpg
✅ Verified: IMG_1235.jpg
✅ Verified: VID_5678.mp4

ℹ️  =========================================
ℹ️  VERIFICATION SUMMARY
ℹ️  =========================================
ℹ️  Total files in STAGE1: 3
✅ Successfully verified: 3
ℹ️  =========================================
✅ Verification PASSED - all files match!
```

### Console Output (With Issues)
```
ℹ️  Starting verification...
ℹ️  STAGE1: ./STAGE1
ℹ️  STAGE2: ./STAGE2

✅ Verified: IMG_1234.jpg
❌ Missing in STAGE2: IMG_1235.jpg
❌ Checksum mismatch: VID_5678.mp4

ℹ️  =========================================
ℹ️  VERIFICATION SUMMARY
ℹ️  =========================================
ℹ️  Total files in STAGE1: 3
✅ Successfully verified: 1
❌ Missing in STAGE2: 1
❌ Checksum mismatches: 1
ℹ️  =========================================
❌ Verification FAILED - issues found!
```

---

## Example 8: Custom Destinations

### Command
```bash
./photomanagement.sh \
  --source /camera/DCIM \
  --stage1 /backup/external/STAGE1 \
  --stage2 /backup/nas/STAGE2 \
  --organize-by-date \
  --verify
```

### What Happens
1. Files copied from /camera/DCIM
2. STAGE1 goes to external drive (flat)
3. STAGE2 goes to NAS (organized)
4. Both verified

---

## Example 9: Specific File Pattern

### Command
```bash
./photomanagement.sh --organize-by-date "*.JPG"
```

### What Happens
1. Only .JPG files are processed
2. Other files (*.mp4, *.png) are ignored
3. STAGE1 gets flat copy
4. STAGE2 gets organized copy

### Multiple Patterns
```bash
# Process JPG files
./photomanagement.sh --organize-by-date "*.JPG"

# Process MP4 files
./photomanagement.sh --organize-by-date "*.mp4"

# Process specific date
./photomanagement.sh --organize-by-date "20231225_*.jpg"
```

---

## Example 10: Disaster Recovery

### Scenario: STAGE2 Corrupted

### Step 1: Verify the Problem
```bash
./verify_stages.sh
```

Output shows mismatches or missing files

### Step 2: Restore from STAGE1
```bash
# Remove corrupted STAGE2
rm -rf ./STAGE2

# Recreate STAGE2 from STAGE1
./photomanagement.sh \
  --source ./STAGE1 \
  --stage1 ./STAGE1_BACKUP \
  --stage2 ./STAGE2 \
  --organize-by-date \
  --use-exif-date
```

### Step 3: Verify Recovery
```bash
./verify_stages.sh
```

---

## Example 11: Camera Import Workflow

### Complete Workflow
```bash
# Step 1: Preview what will be imported
./photomanagement.sh --dry-run --source /media/camera/DCIM --organize-by-date --use-exif-date

# Step 2: Import with full features
./photomanagement.sh \
  --source /media/camera/DCIM \
  --organize-by-date \
  --use-exif-date \
  --verify \
  --log import_$(date +%Y%m%d_%H%M%S).log \
  --progress

# Step 3: Verify both stages
./verify_stages.sh --log verify_$(date +%Y%m%d_%H%M%S).log

# Step 4: Safe to format camera card
echo "Import complete and verified!"
```

---

## Example 12: Quiet Mode (For Scripts)

### Command
```bash
./photomanagement.sh --source /photos --organize-by-date --quiet --log backup.log
```

### What Happens
1. Minimal console output
2. All details go to log file
3. Good for automated scripts/cron jobs

### Console Output
```
ℹ️  Starting photo management process...
ℹ️  =========================================
ℹ️  SUMMARY
ℹ️  =========================================
ℹ️  Total files processed: 100
✅ Successfully copied: 100
ℹ️  =========================================
```

---

## Tips for Each Example

### Example 1 (Simple Copy)
- Use when you just need backup
- No organization needed
- Fast operation

### Example 2 (Organize by Filename)
- Use when files are already named with dates
- No exiftool required
- Works with renamed files

### Example 3 (Organize by EXIF)
- Use for camera photos with metadata
- Most accurate dating
- Requires exiftool

### Example 4 (Full Featured)
- Use for important backups
- Maximum safety
- Slower but thorough

### Example 5 (Dry Run)
- Always use first!
- Preview before committing
- No risk

### Example 6 (Incremental)
- Use for regular backups
- Fast (skips existing)
- No duplicates

### Example 7 (Verify)
- Use after large copies
- Ensures data integrity
- Peace of mind

### Example 8 (Custom Destinations)
- Use for specific backup locations
- Flexible setup
- Multi-drive support

### Example 9 (Specific Pattern)
- Use for selective copying
- Process by file type
- Targeted operations

### Example 10 (Disaster Recovery)
- Use when STAGE2 fails
- STAGE1 is your safety net
- Quick restoration

### Example 11 (Camera Import)
- Complete workflow
- Professional approach
- Safe and verified

### Example 12 (Quiet Mode)
- Use in scripts
- Automated backups
- Cron jobs

