# Photo Management Workflow Diagram

## Basic Workflow (No Organization)

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
         │ ./photomanagement.sh
         │
         ├──────────────────┬──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│    STAGE1       │  │    STAGE2       │  │   LOG FILE      │
│  (Flat Backup)  │  │  (Flat Copy)    │  │  (Optional)     │
│                 │  │                 │  │                 │
│  IMG_1234.jpg   │  │  IMG_1234.jpg   │  │  backup.log     │
│  IMG_1235.jpg   │  │  IMG_1235.jpg   │  │                 │
│  VID_5678.mp4   │  │  VID_5678.mp4   │  │  [timestamp]    │
└─────────────────┘  └─────────────────┘  │  SUCCESS: ...   │
                                          │  SUCCESS: ...   │
                                          └─────────────────┘
```

## Advanced Workflow (With Date Organization)

```
┌─────────────────────────┐
│    SOURCE FILES         │
│    /photos/             │
│                         │
│  20231225_143022.jpg    │
│  20231225_143023.jpg    │
│  20240101_000000.mp4    │
└────────────┬────────────┘
             │
             │ ./photomanagement.sh --organize-by-date --use-exif-date --verify --log backup.log
             │
             ├──────────────────────┬──────────────────────┐
             │                      │                      │
             ▼                      ▼                      ▼
┌──────────────────────┐  ┌──────────────────────┐  ┌─────────────────┐
│      STAGE1          │  │      STAGE2          │  │   LOG FILE      │
│   (Flat Backup)      │  │   (Organized)        │  │                 │
│   NO ORGANIZATION    │  │   BY DATE            │  │  backup.log     │
│                      │  │                      │  │                 │
│  20231225_143022.jpg │  │  2023/               │  │  [timestamp]    │
│  20231225_143023.jpg │  │  └── 12/             │  │  STAGE1: ...    │
│  20240101_000000.mp4 │  │      ├── 20231225... │  │  STAGE2: ...    │
│                      │  │      └── 20231225... │  │  VERIFIED ✓     │
│  ✓ Pristine backup   │  │  2024/               │  │  SUCCESS: ...   │
│  ✓ Original names    │  │  └── 01/             │  └─────────────────┘
│  ✓ Easy recovery     │  │      └── 20240101... │
│                      │  │                      │
│                      │  │  ✓ Organized         │
│                      │  │  ✓ Easy browsing     │
│                      │  │  ✓ MD5 verified      │
└──────────────────────┘  └──────────────────────┘
```

## Feature Breakdown

### STAGE1 - Flat Backup
```
Purpose: Safety and recovery
Structure: Flat (no subdirectories)
Naming: Original filenames preserved
Operations: Copy only (no organization)
Use case: Quick recovery, data integrity
```

### STAGE2 - Organized Copy
```
Purpose: Working copy for browsing/operations
Structure: Optional YYYY/MM organization
Naming: Original filenames preserved
Operations: Copy + organize + verify
Use case: Daily browsing, photo management
```

## Command Examples with Results

### Example 1: Basic Copy
```bash
./photomanagement.sh --source /camera/DCIM
```

**Result:**
```
STAGE1/                    STAGE2/
├── IMG_1234.jpg          ├── IMG_1234.jpg
├── IMG_1235.jpg          ├── IMG_1235.jpg
└── VID_5678.mp4          └── VID_5678.mp4
```

### Example 2: Organized Copy
```bash
./photomanagement.sh --source /camera/DCIM --organize-by-date
```

**Result:**
```
STAGE1/                    STAGE2/
├── 20231225_143022.jpg   ├── 2023/
├── 20231225_143023.jpg   │   └── 12/
└── 20240101_000000.mp4   │       ├── 20231225_143022.jpg
                          │       └── 20231225_143023.jpg
                          └── 2024/
                              └── 01/
                                  └── 20240101_000000.mp4
```

### Example 3: Full Featured
```bash
./photomanagement.sh \
  --source /camera/DCIM \
  --organize-by-date \
  --use-exif-date \
  --verify \
  --log backup.log \
  --progress
```

**Result:**
```
STAGE1/                    STAGE2/                    backup.log
├── IMG_1234.jpg          ├── 2023/                  ├── [2024-01-15 14:30:22]
├── IMG_1235.jpg          │   └── 12/                │   Starting...
└── VID_5678.mp4          │       ├── IMG_1234.jpg   ├── STAGE1: Copied IMG_1234.jpg
                          │       └── IMG_1235.jpg   ├── STAGE2: Copied and verified
                          └── 2024/                  ├── STAGE1: Copied IMG_1235.jpg
                              └── 01/                ├── STAGE2: Copied and verified
                                  └── VID_5678.mp4   └── Summary: 3 files, 3 success
```

## Verification Workflow

```
┌─────────────────┐         ┌─────────────────┐
│    STAGE1       │         │    STAGE2       │
│                 │         │                 │
│  file1.jpg      │         │  2023/12/       │
│  file2.jpg      │         │    file1.jpg    │
│  file3.mp4      │         │    file2.jpg    │
│                 │         │  2024/01/       │
│                 │         │    file3.mp4    │
└────────┬────────┘         └────────┬────────┘
         │                           │
         │                           │
         │  ./verify_stages.sh       │
         │                           │
         └───────────┬───────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  VERIFICATION REPORT  │
         │                       │
         │  ✓ file1.jpg - OK     │
         │  ✓ file2.jpg - OK     │
         │  ✓ file3.mp4 - OK     │
         │                       │
         │  Total: 3 files       │
         │  Verified: 3          │
         │  Failed: 0            │
         └───────────────────────┘
```

## Date Extraction Logic

```
┌──────────────────┐
│  Input File      │
│  IMG_1234.jpg    │
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────┐
│  --use-exif-date specified? │
└────┬────────────────────┬───┘
     │ YES                │ NO
     ▼                    │
┌──────────────────┐      │
│  Read EXIF data  │      │
│  DateTimeOriginal│      │
│  CreateDate      │      │
│  ModifyDate      │      │
└────┬─────────────┘      │
     │                    │
     ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│  EXIF date found?│  │  Parse filename  │
└────┬─────────┬───┘  │  YYYYMMDD_HHMMSS │
     │ YES     │ NO   └────┬─────────────┘
     │         │           │
     │         └───────────┤
     │                     │
     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐
│  Use EXIF date   │  │  Use filename    │
│  2023:12:25      │  │  date 20231225   │
└────┬─────────────┘  └────┬─────────────┘
     │                     │
     └──────────┬──────────┘
                │
                ▼
       ┌─────────────────┐
       │  Date found?    │
       └────┬────────┬───┘
            │ YES    │ NO
            ▼        ▼
       ┌─────────┐  ┌──────────────┐
       │ 2023/12/│  │  Root dir    │
       └─────────┘  └──────────────┘
```

## Use Cases

### Use Case 1: Camera Import
```
Scenario: Import photos from camera SD card
Command: ./photomanagement.sh --source /media/sdcard --organize-by-date --use-exif-date --verify
Result: STAGE1 = flat backup, STAGE2 = organized by photo date
```

### Use Case 2: Archive Organization
```
Scenario: Organize existing photo archive
Command: ./photomanagement.sh --source /old/photos --organize-by-date
Result: STAGE1 = flat backup, STAGE2 = organized by filename date
```

### Use Case 3: Incremental Backup
```
Scenario: Add new photos to existing backup
Command: ./photomanagement.sh --source /new/photos --organize-by-date --log incremental.log
Result: New files added, existing files skipped
```

### Use Case 4: Disaster Recovery
```
Scenario: STAGE2 corrupted, need to restore
Action: Copy from STAGE1 (pristine backup) to new STAGE2
Command: ./photomanagement.sh --source ./STAGE1 --stage2 ./STAGE2_NEW --organize-by-date
```

