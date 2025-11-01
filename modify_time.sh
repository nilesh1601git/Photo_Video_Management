#!/bin/bash

echo "Fixing EXIF timestamps using filename..."

for file in  `ls *.AVI`
do
    [ -f "$file" ] || continue

    echo "Processing: $file"

    # Extract timestamp from filename (expects format: YYYYMMDD_HHMMSS.jpg)
    base=$(basename "$file")
    name="${base%.*}"
    
    if [[ $name =~ ^([0-9]{8})_([0-9]{6})$ ]]; then
        date_part=${BASH_REMATCH[1]}
        time_part=${BASH_REMATCH[2]}
        
        # Format as: YYYY:MM:DD HH:MM:SS
        ts="${date_part:0:4}:${date_part:4:2}:${date_part:6:2} ${time_part:0:2}:${time_part:2:2}:${time_part:4:2}"

        # Update all EXIF and file timestamps
        exiftool \
          "-FileModifyDate=$ts" \
          "$file"
#        exiftool \
#          "-DateTimeOriginal=$ts" \
#          "-CreateDate=$ts" \
#          "-ModifyDate=$ts" \
#          "-FileModifyDate=$ts" \
#          "$file"
    else
        echo "⚠️ Skipping $file (filename doesn't match expected format)"
    fi
done

echo "Done!"

