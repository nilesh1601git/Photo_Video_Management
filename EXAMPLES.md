# Photo Management - Practical Examples

## Example 1: Simple Copy

### Command
```bash
./photomanagement.sh --source /camera/photos
```

### What Happens
1. All photos copied to STAGE2
2. Files renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate
3. Original timestamps preserved
4. Progress bar shown automatically

### Result
```
STAGE2/
├── 20231225_143022.jpg
├── 20231225_143023.jpg
├── 20240101_000000.mp4
└── 20240115_090000.jpg
```

---

## Example 2: Copy with Verification

### Command
```bash
./photomanagement.sh --source /camera/photos --verify
```

### What Happens
1. All photos copied to STAGE2
2. Files renamed to YYYYMMDD_HHMMSS.ext format
3. Each file verified with MD5 checksum
4. Timestamps preserved

### Result
```
STAGE2/
├── 20231225_143022.jpg  (verified)
├── 20231225_143023.jpg  (verified)
├── 20240101_000000.mp4  (verified)
└── 20240115_090000.jpg  (verified)
```

---

## Example 3: Full Featured Backup with Verification

### Command
```bash
./photomanagement.sh \
  --source /camera/photos \
  --verify \
  --log backup_$(date +%Y%m%d).log \
  --progress \
  --structured-log mapping_$(date +%Y%m%d).csv
```

### What Happens
1. All photos copied to STAGE2
2. Files renamed to YYYYMMDD_HHMMSS.ext format based on EXIF CreateDate
3. Each file verified with MD5 checksum
4. Progress bar shown during copy
5. Detailed log written to file
6. Structured CSV log created with filename mappings
7. Timestamps preserved

### Console Output
```
ℹ️  Starting photo management process...
ℹ️  Source: /camera/photos
ℹ️  STAGE2: ./STAGE2 (renamed to YYYYMMDD_HHMMSS.ext based on EXIF CreateDate)
ℹ️  Verification: Enabled for STAGE2 (MD5 checksums)

Progress: [####################                              ] 40% (2/5) - IMG_1234.JPG

ℹ️  Filename mapping: 'IMG_1234.jpg' → '20231225_143022.jpg'
✅ Copied and verified: 'IMG_1234.jpg' → './STAGE2/20231225_143022.jpg'
ℹ️  Filename mapping: 'IMG_1235.jpg' → '20231225_143023.jpg'
✅ Copied and verified: 'IMG_1235.jpg' → './STAGE2/20231225_143023.jpg'

ℹ️  =========================================
ℹ️  SUMMARY
ℹ️  =========================================
ℹ️  Total files processed: 5
✅ Successfully copied: 5
✅ Verified copies: 5
ℹ️  =========================================
✅ Log file saved to: backup_20240115.log
✅ Structured log file saved to: mapping_20240115.csv
```

### Log File Content
```
[2024-01-15 14:30:22] Starting photo management process
[2024-01-15 14:30:22] Source: /camera/photos
[2024-01-15 14:30:22] STAGE2: ./STAGE2 (working copy)
[2024-01-15 14:30:22] Verify copy: true
[2024-01-15 14:30:23] FILENAME MAPPING: 'IMG_1234.jpg' → '20231225_143022.jpg'
[2024-01-15 14:30:23] SUCCESS: Copied and verified 'IMG_1234.jpg' → './STAGE2/20231225_143022.jpg'
[2024-01-15 14:30:24] FILENAME MAPPING: 'IMG_1235.jpg' → '20231225_143023.jpg'
[2024-01-15 14:30:24] SUCCESS: Copied and verified 'IMG_1235.jpg' → './STAGE2/20231225_143023.jpg'
[2024-01-15 14:30:30] Total files processed: 5
[2024-01-15 14:30:30] Successfully copied: 5
[2024-01-15 14:30:30] Verified copies: 5
[2024-01-15 14:30:30] Completed: 2024-01-15 14:30:30
```

### Structured Log File Content (CSV)
```
Source_filename,[EXIF]ModifyDate,[EXIF]DateTimeOriginal,[EXIF]CreateDate,[Composite]SubSecCreateDate,[Composite]SubSecDateTimeOriginal,STAGE2,Remark
IMG_1234.JPG,20231225_143022,20231225_143022,20231225_143022,,,20231225_143022.jpg,
IMG_1235.JPG,20231225_143023,20231225_143023,20231225_143023,,,20231225_143023.jpg,
VID_5678.mp4,20240101_000000,20240101_000000,20240101_000000,,,20240101_000000.mp4,
```

---

## Example 4: Incremental Backup

### Initial Backup
```bash
./photomanagement.sh --source /photos --verify
```

Result: 100 files copied to STAGE2 and renamed

### Add New Photos (Later)
```bash
./photomanagement.sh --source /photos --verify
```

### What Happens
1. Existing 100 files are skipped (already exist by checksum)
2. Only new files are copied
3. New files are renamed to YYYYMMDD_HHMMSS.ext format
4. No duplicates created
5. Fast operation

### Console Output
```
⚠️  Skipping STAGE2 '20231225_143022.jpg' - identical file exists (verified)
✅ Copied and verified: 'IMG_NEW.jpg' → './STAGE2/20240115_094510.jpg'

ℹ️  Total files processed: 101
✅ Successfully copied: 1
⚠️  Skipped: 100
```

---

## Example 5: Set Remarks

### Command
```bash
./photomanagement.sh --set-remark "Family vacation 2024" --source /path/to/photos
```

### What Happens
1. Remarks are set in EXIF ImageDescription and UserComment tags
2. Files are then copied to STAGE2
3. Files are renamed to YYYYMMDD_HHMMSS.ext format
4. Remarks are preserved in copied files

### Result
Files in STAGE2 have remarks stored in EXIF metadata, visible in photo management software.

---

## Example 6: Display Remarks

### Command
```bash
./photomanagement.sh --get-remark --source /path/to/photos
```

### What Happens
1. Reads remarks from EXIF tags
2. Displays remarks for each file
3. No files are copied

### Console Output
```
ℹ️  Displaying remarks for files in: /path/to/photos
ℹ️  Pattern: *

📝 Remarks:
  IMG_1234.JPG: Family vacation 2024
  IMG_1235.JPG: Family vacation 2024
  VID_5678.mp4: (no remark)
```

---

## Example 7: Show Dates Only

### Command
```bash
./photomanagement.sh --show-dates --source /path/to/photos
```

### What Happens
1. Displays all date-related EXIF tags for each file
2. No files are copied
3. Useful for inspecting EXIF metadata

### Console Output
```
ℹ️  Date-related EXIF tags for 'IMG_1234.JPG':
  [EXIF]          DateTimeOriginal                  : 2023:12:25 14:30:22
  [EXIF]          CreateDate                        : 2023:12:25 14:30:22
  [EXIF]          ModifyDate                        : 2023:12:25 14:30:22
  [File]          FileModifyDate                    : 2023:12:25 14:30:22
```

---

## Example 8: Move Files (Delete Source)

### Command
```bash
./photomanagement.sh --move --source /path/to/photos --verify
```

### What Happens
1. Files copied to STAGE2
2. Files renamed to YYYYMMDD_HHMMSS.ext format
3. Files verified with MD5 checksum
4. Source files deleted after successful copy
5. Source files NOT deleted if copy failed or file was skipped

### Console Output
```
✅ Copied and verified: 'IMG_1234.jpg' → './STAGE2/20231225_143022.jpg'
✅ Moved (deleted source): 'IMG_1234.jpg'
```

---

## Example 9: Custom Destination

### Command
```bash
./photomanagement.sh \
  --source /camera/DCIM \
  --stage2 /backup/nas/STAGE2 \
  --verify
```

### What Happens
1. Files copied from /camera/DCIM
2. STAGE2 goes to NAS (/backup/nas/STAGE2)
3. Files renamed to YYYYMMDD_HHMMSS.ext format
4. Files verified

---

## Example 10: Specific File Pattern

### Command
```bash
./photomanagement.sh --source /path/to/photos "*.JPG"
```

### What Happens
1. Only .JPG files are processed
2. Other files (*.mp4, *.png) are ignored
3. STAGE2 gets renamed copy

### Multiple Patterns
```bash
# Process JPG files
./photomanagement.sh --source /path/to/photos "*.JPG"

# Process MP4 files
./photomanagement.sh --source /path/to/photos "*.mp4"

# Process specific date
./photomanagement.sh --source /path/to/photos "20231225_*.jpg"
```

---

## Example 11: Camera Import Workflow

### Complete Workflow
```bash
# Step 1: Import with full features
./photomanagement.sh \
  --source /media/camera/DCIM \
  --verify \
  --log import_$(date +%Y%m%d_%H%M%S).log \
  --progress \
  --structured-log mapping_$(date +%Y%m%d_%H%M%S).csv

# Step 2: Safe to format camera card
echo "Import complete and verified!"
```

---

## Example 12: Quiet Mode (For Scripts)

### Command
```bash
./photomanagement.sh --source /photos --quiet --log backup.log
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

## Example 13: Structured Logging

### Command
```bash
./photomanagement.sh \
  --source /path/to/photos \
  --structured-log mapping.csv \
  --verify
```

### What Happens
1. Creates CSV file with filename mappings
2. Includes all date-related EXIF tags
3. Includes final filename in STAGE2
4. Includes remarks if available

### CSV File Content
```
Source_filename,[EXIF]ModifyDate,[EXIF]DateTimeOriginal,[EXIF]CreateDate,[Composite]SubSecCreateDate,[Composite]SubSecDateTimeOriginal,STAGE2,Remark
IMG_1234.JPG,20231225_143022,20231225_143022,20231225_143022,,,20231225_143022.jpg,
DSC_5678.jpg,20240115_094510,20240115_094510,20240115_094510,,,20240115_094510.jpg,Family vacation
```

This CSV file can be opened in Excel, Google Sheets, or any spreadsheet application for analysis.

---

## Example 14: Limit Files for Testing

### Command
```bash
./photomanagement.sh --source /path/to/photos --limit 10
```

### What Happens
1. Only first 10 files are processed
2. Useful for testing before processing large batches
3. All features work normally

---

## Tips for Each Example

### Example 1 (Simple Copy)
- Use when you just need basic backup
- Fast operation
- Files automatically renamed

### Example 2 (With Verification)
- Use for important backups
- Ensures data integrity
- Slower but thorough

### Example 3 (Full Featured)
- Use for important backups
- Maximum safety
- Complete logging

### Example 4 (Incremental)
- Use for regular backups
- Fast (skips existing)
- No duplicates

### Example 5 (Set Remarks)
- Use to add notes to photos
- Visible in photo management software
- Preserved in copied files

### Example 6 (Get Remarks)
- Use to view all remarks
- No files copied
- Quick inspection

### Example 7 (Show Dates)
- Use to inspect EXIF metadata
- No files copied
- Useful for troubleshooting

### Example 8 (Move Files)
- Use when you want to delete source
- Only deletes after successful copy
- Safe operation

### Example 9 (Custom Destination)
- Use for specific backup locations
- Flexible setup
- Multi-drive support

### Example 10 (Specific Pattern)
- Use for selective copying
- Process by file type
- Targeted operations

### Example 11 (Camera Import)
- Complete workflow
- Professional approach
- Safe and verified

### Example 12 (Quiet Mode)
- Use in scripts
- Automated backups
- Cron jobs

### Example 13 (Structured Logging)
- Use for analysis
- CSV format
- Spreadsheet compatible

### Example 14 (Limit Files)
- Use for testing
- Process small batches
- Verify before full run
