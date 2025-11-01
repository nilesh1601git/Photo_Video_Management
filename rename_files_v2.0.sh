#!/bin/bash

declare -A timestamp_counters  # associative array to track per-timestamp counters

rename_function() {
    ext=$1

    for file in *."$ext"; do
        if [ -f "$file" ]; then
            # Get modification date and time in YYYYMMDD_HHMMSS format
            datetime=$(stat -c %y "$file" | awk '{print $1"_"$2}' | sed 's/[-:]//g' | cut -c1-15)

            base_name="${datetime}"
            new_name="${base_name}.$ext"

            # If file with that name already exists, use counter suffix
            if [ -e "$new_name" ]; then
                # Initialize counter for this timestamp if not already done
                counter=${timestamp_counters[$base_name]:-1}

                # Loop until a unique name is found
                while true; do
                    new_name="${base_name}_$(printf "%03d" $counter).$ext"
                    if [ ! -e "$new_name" ]; then
                        break
                    fi
                    ((counter++))
                done

                timestamp_counters[$base_name]=$((counter + 1))
            fi

            # ✅ Final safety check to prevent overwriting
            if [ ! -e "$new_name" ]; then
                echo "Renaming: \"$file\" -> \"$new_name\""
                mv "$file" "$new_name"
            else
                echo "Skipping \"$file\" → \"$new_name\" already exists."
            fi
        fi
    done
}

# Run for all desired extensions
rename_function AVI
rename_function avi
rename_function jpg
rename_function JPG
rename_function MOV
rename_function MP4
rename_function mp4

