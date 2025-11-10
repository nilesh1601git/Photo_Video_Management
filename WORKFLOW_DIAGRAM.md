# Photo Management Workflow Diagram

## Basic Workflow

```
┌─────────────────┐
│  SOURCE FILES   │
│  /photos/       │
│                 │
│  IMG_1234.jpg   │
│  IMG_1235.jpg   │
│  VID_5678.mp4   │
└────────┬────────┘
         │
         │ ./photomanagement.sh --source /photos
         │
         ├──────────────────┬──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│    STAGE2       │  │   LOG FILE      │  │ STRUCTURED LOG │
│  (Renamed Copy) │  │  (Optional)     │  │  (Optional)    │
│                 │  │                 │  │                 │
│  20231225_      │  │  backup.log     │  │  mapping.csv    │
│    143022.jpg   │  │                 │  │                 │
│  20231225_      │  │  [timestamp]    │  │  Source|Dates|  │
│    143023.jpg   │  │  FILENAME       │  │  Final|Remark   │
│  20240101_      │  │  MAPPING: ...   │  │  IMG_1234|...|  │
│    000000.mp4   │  │  SUCCESS: ...   │  │  20231225_...   │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## File Renaming Process

```
┌──────────────────┐
│  Input File       │
│  IMG_1234.jpg     │
└────────┬──────────┘
         │
         ▼
┌─────────────────────────────┐
│  Extract EXIF CreateDate    │
│  (using exiftool)          │
└────┬────────────────────┬───┘
     │ EXIF found          │ No EXIF
     ▼                     │
┌──────────────────┐      │
│  Format Date     │      │
│  YYYYMMDD_HHMMSS │      │
└────┬─────────────┘      │
     │                     │
     │                     ▼
     │            ┌──────────────────┐
     │            │  Use File Stat   │
     │            │  Date (oldest)   │
     │            └────┬─────────────┘
     │                 │
     │                 ▼
     │            ┌──────────────────┐
     │            │  Format Date     │
     │            │  YYYYMMDD_HHMMSS │
     │            └────┬─────────────┘
     │                 │
     └────────┬─────────┘
              │
              ▼
     ┌─────────────────┐
     │  Check for      │
     │  Duplicates    │
     └────┬────────┬───┘
          │ Yes    │ No
          ▼        │
     ┌─────────┐  │
     │ Add     │  │
     │ _001    │  │
     │ suffix  │  │
     └────┬────┘  │
          │        │
          └───┬────┘
              │
              ▼
     ┌─────────────────┐
     │  Final Filename │
     │  20231225_      │
     │  143022.jpg     │
     └─────────────────┘
```

## Complete Workflow with All Features

```
┌─────────────────────────┐
│    SOURCE FILES         │
│    /photos/             │
│                         │
│   IMG_1234.jpg          │
│   IMG_1235.jpg          │
│   VID_5678.mp4          │
└────────────┬────────────┘
             │
             │ ./photomanagement.sh \
             │   --source /photos \
             │   --verify \
             │   --log backup.log \
             │   --structured-log mapping.csv \
             │   --set-remark "Vacation 2024"
             │
             ├──────────────────────┬──────────────────────┬──────────────────┐
             │                      │                      │                  │
             ▼                      ▼                      ▼                  ▼
┌──────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐  ┌──────────────┐
│      STAGE2          │  │   LOG FILE            │  │ STRUCTURED LOG  │  │  EXIF TAGS   │
│   (Renamed Copy)     │  │                       │  │                 │  │              │
│                      │  │  backup.log           │  │  mapping.csv     │  │  Remarks     │
│  20231225_143022.jpg │  │                       │  │                 │  │  Updated     │
│  20231225_143023.jpg │  │  [timestamp]          │  │  Source|Dates|  │  │              │
│  20240101_000000.mp4 │  │  FILENAME MAPPING:   │  │  Final|Remark   │  │  ImageDesc:  │
│                      │  │  IMG_1234 → 2023...  │  │  IMG_1234|...|  │  │  "Vacation"  │
│  ✓ Renamed           │  │  SUCCESS: Copied...    │  │  20231225_...|  │  │  UserComment:│
│  ✓ MD5 verified      │  │  VERIFIED: ...        │  │  "Vacation 2024"│  │  "Vacation"  │
│  ✓ Timestamps kept   │  │  SUMMARY: ...         │  └─────────────────┘  └──────────────┘
└──────────────────────┘  └──────────────────────┘
```

## Command Examples with Results

### Example 1: Basic Copy
```bash
./photomanagement.sh --source /camera/DCIM
```

**Result:**
```
STAGE2/
├── 20231225_143022.jpg
├── 20231225_143023.jpg
└── 20240101_000000.mp4
```

### Example 2: Copy with Verification
```bash
./photomanagement.sh --source /camera/DCIM --verify
```

**Result:**
```
STAGE2/
├── 20231225_143022.jpg  (verified)
├── 20231225_143023.jpg  (verified)
└── 20240101_000000.mp4  (verified)
```

### Example 3: Full Featured
```bash
./photomanagement.sh \
  --source /camera/DCIM \
  --verify \
  --log backup.log \
  --structured-log mapping.csv \
  --progress
```

**Result:**
```
STAGE2/                    backup.log                  mapping.csv
├── 20231225_143022.jpg   ├── [2024-01-15 14:30:22]  ├── Source|Dates|Final|Remark
├── 20231225_143023.jpg   │   Starting...            ├── IMG_1234|...|20231225_...|
└── 20240101_000000.mp4   ├── FILENAME MAPPING:      ├── IMG_1235|...|20231225_...|
                          │   IMG_1234 → 2023...     └── VID_5678|...|20240101_...|
                          ├── SUCCESS: Copied...
                          └── Summary: 3 files, 3 success
```

## Verification Workflow

```
┌─────────────────┐         ┌─────────────────┐
│    STAGE2       │         │  VERIFICATION    │
│                 │         │                 │
│  20231225_      │         │  ✓ file1.jpg    │
│    143022.jpg   │         │  ✓ file2.jpg    │
│  20231225_      │         │  ✓ file3.mp4    │
│    143023.jpg   │         │                 │
│  20240101_      │         │  Total: 3 files  │
│    000000.mp4   │         │  Verified: 3     │
│                 │         │  Failed: 0      │
└────────┬────────┘         └─────────────────┘
         │
         │ ./verify_stages.sh
         │
         ▼
┌───────────────────────┐
│  VERIFICATION REPORT   │
│                        │
│  ✓ 20231225_143022.jpg│
│  ✓ 20231225_143023.jpg│
│  ✓ 20240101_000000.mp4│
│                        │
│  Total: 3 files       │
│  Verified: 3           │
│  Failed: 0             │
└───────────────────────┘
```

## Date Extraction Logic

```
┌──────────────────┐
│  Input File       │
│  IMG_1234.jpg     │
└────────┬──────────┘
         │
         ▼
┌─────────────────────────────┐
│  Try EXIF CreateDate        │
│  (using exiftool)           │
└────┬────────────────────┬───┘
     │ EXIF found         │ No EXIF
     ▼                    │
┌──────────────────┐      │
│  Validate Date   │      │
│  (not 0000:00:00)│      │
└────┬─────────┬───┘      │
     │ Valid   │ Invalid   │
     │         │          │
     │         └──────────┤
     │                    │
     │                    ▼
     │            ┌──────────────────┐
     │            │  Try File Stat   │
     │            │  Dates (oldest)  │
     │            └────┬─────────────┘
     │                 │
     │                 ▼
     │            ┌──────────────────┐
     │            │  Date found?     │
     │            └────┬────────┬───┘
     │                 │ YES    │ NO
     │                 │        │
     │                 │        ▼
     │                 │  ┌──────────────┐
     │                 │  │  Use original│
     │                 │  │  filename    │
     │                 │  └──────────────┘
     │                 │
     └────────┬────────┘
              │
              ▼
     ┌─────────────────┐
     │  Format to      │
     │  YYYYMMDD_      │
     │  HHMMSS.ext     │
     └─────────────────┘
```

## Use Cases

### Use Case 1: Camera Import
```
Scenario: Import photos from camera SD card
Command: ./photomanagement.sh --source /media/sdcard --verify --structured-log mapping.csv
Result: STAGE2 = renamed files with standardized names
```

### Use Case 2: Archive Organization
```
Scenario: Organize existing photo archive
Command: ./photomanagement.sh --source /old/photos --verify
Result: STAGE2 = renamed files with standardized names
```

### Use Case 3: Incremental Backup
```
Scenario: Add new photos to existing backup
Command: ./photomanagement.sh --source /new/photos --log incremental.log
Result: New files added, existing files skipped
```

### Use Case 4: Move with Remarks
```
Scenario: Move photos and add remarks
Command: ./photomanagement.sh --source /photos --move --set-remark "Vacation 2024" --verify
Result: Files moved to STAGE2, renamed, remarks added, source deleted
```

## Progress Bar Display

```
Progress: [████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 48% (24/50) - IMG_1234.JPG
```

The progress bar shows:
- Visual progress (filled blocks)
- Percentage complete
- Current file number / total files
- Current filename being processed

## Structured Log Format

```
Source_filename,[EXIF]ModifyDate,[EXIF]DateTimeOriginal,[EXIF]CreateDate,[Composite]SubSecCreateDate,[Composite]SubSecDateTimeOriginal,STAGE2,Remark
IMG_1234.JPG,20231225_143022,20231225_143022,20231225_143022,,,20231225_143022.jpg,
DSC_5678.jpg,20240115_094510,20240115_094510,20240115_094510,,,20240115_094510.jpg,Family vacation
```

This CSV format can be opened in spreadsheet applications for analysis.
