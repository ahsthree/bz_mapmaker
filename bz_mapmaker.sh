#!/usr/bin/env bash
#
#  bz_mapmaker.sh - Interactive BZFlag Map Builder
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.

cleanup_test_group() {
    local mapfile="$1"
    local groupname="$2"
    if [ -f "$mapfile" ]; then
        # Delete from 'group <name>' down to 'end'
        sed -i "/^group ${groupname}$/,/^end$/d" "$mapfile"
    fi
}

echo "=========================================="
echo "    BZFlag Group & Define Map Builder     "
echo "=========================================="

# 1. Select or Create Map File
existing_maps=( *.bzw )

if [ -e "${existing_maps[0]}" ]; then
    echo "Existing map files found:"
    select mapfile in "${existing_maps[@]}" "Create New Map"; do
        if [ "$mapfile" == "Create New Map" ]; then
            read -p "Enter new map filename (e.g., mymap.bzw): " mapfile
            break
        elif [ -n "$mapfile" ]; then
            break
        fi
    done
else
    read -p "Enter map filename (e.g., mymap.bzw): " mapfile
fi

[[ "$mapfile" != *.bzw ]] && mapfile="${mapfile}.bzw"
touch "$mapfile"

# Check for unfinished define session tag
resumed_define=""
if grep -q "^# IN_PROGRESS_DEFINE:" "$mapfile"; then
    resumed_define=$(grep "^# IN_PROGRESS_DEFINE:" "$mapfile" | head -n 1 | cut -d':' -f2 | xargs)
    echo ""
    echo ">> Found unfinished define session for '$resumed_define' in $mapfile!"
    echo ">> Resuming object creation loop..."
fi

# 2. Options Block Setup
if grep -q "^options" "$mapfile"; then
    echo "Existing options block detected in $mapfile. Skipping options entry."
else
    echo "------------------------------------------"
    echo "Enter server options separated by semicolons (;)."
    echo "Example: -j; +r; -ms 6; -sb; -mp 10,10,0,0,10"
    read -p "Server options [Press Enter to skip]: " user_opts

    if [ -n "$user_opts" ]; then
        IFS=';' read -ra OPT_ARRAY <<< "$user_opts"
        formatted_opts="options"
        for opt in "${OPT_ARRAY[@]}"; do
            trimmed_opt="$(echo "$opt" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            if [ -n "$trimmed_opt" ]; then
                formatted_opts="${formatted_opts}\n  ${trimmed_opt}"
            fi
        done
        formatted_opts="${formatted_opts}\nend"

        temp_file=$(mktemp)
        echo -e "$formatted_opts\n" > "$temp_file"
        cat "$mapfile" >> "$temp_file"
        mv "$temp_file" "$mapfile"
        echo "Options block written to $mapfile"
    fi
fi

# 3. Main Building Loop
while true; do
    if [ -n "$resumed_define" ]; then
        definename="$resumed_define"
        resumed_define=""
    else
        echo ""
        read -p "Enter DEFINE name (or 'quit' to exit): " definename
        [[ "$definename" == "quit" || -z "$definename" ]] && break
    fi

    if ! grep -q "^define $definename" "$mapfile"; then
        echo -e "\n# IN_PROGRESS_DEFINE: $definename\ndefine $definename\nenddef #$definename" >> "$mapfile"
    elif ! grep -q "^# IN_PROGRESS_DEFINE: $definename" "$mapfile"; then
        sed -i "/^define $definename/i # IN_PROGRESS_DEFINE: $definename" "$mapfile"
    fi

    while true; do
        echo "------------------------------------------"
        echo "Adding object to define: $definename"
        read -p "Object type [b=box, p=pyramid, x=exit define]: " objtype

        case "$objtype" in
            b|B) obj_name="box" ;;
            p|P) obj_name="pyramid" ;;
            x|X) break ;;
            *) echo "Invalid choice. Skipping."; continue ;;
        esac

        read -p "Position (x y z) [default: 0 0 0]: " x y z
        x=${x:-0}; y=${y:-0}; z=${z:-0}

        read -p "Size (xs ys zs) [default: 10 10 10]: " xs ys zs
        xs=${xs:-10}; ys=${ys:-10}; zs=${zs:-10}

        read -p "Rotation (rot) [default: 0]: " rot
        rot=${rot:-0}

        obj_block="${obj_name}\n  pos $x $y $z\n  size $xs $ys $zs\n  rot $rot\nend"

        # Insert object right above 'enddef #definename'
        sed -i "/^enddef #$definename/i $obj_block" "$mapfile"

        # Temporary test group
        echo -e "\ngroup $definename\n  shift 0 0 0\nend" >> "$mapfile"

        echo "------------------------------------------"
        echo "Launching bzfs server for testing..."
        echo "Press Ctrl+C or exit server when done."
        echo "------------------------------------------"
        
        bzfs -world "$mapfile"

        cleanup_test_group "$mapfile" "$definename"

        read -p "Keep this object? [Y/n]: " keep_obj
        if [[ "$keep_obj" =~ ^[Nn]$ ]]; then
            # Delete whole block from 'box' or 'pyramid' down to 'end' matching pos
            sed -i "/^${obj_name}$/,/^end$/{ /^  pos $x $y $z$/!b; d; }" "$mapfile" 2>/dev/null || \
            python3 -c "
import sys, re
path = '$mapfile'
with open(path, 'r') as f:
    text = f.read()
pattern = r'${obj_name}\s*\n\s*pos $x $y $z\s*\n\s*size $xs $ys $zs\s*\n\s*rot $rot\s*\nend\n?'
text = re.sub(pattern, '', text, count=1)
with open(path, 'w') as f:
    f.write(text)
"
            echo "Object removed cleanly."
        else
            echo "Object saved to define."
        fi

        read -p "Finish and close define '$definename'? [y/N]: " close_def
        if [[ "$close_def" =~ ^[Yy]$ ]]; then
            sed -i "/^# IN_PROGRESS_DEFINE: $definename$/d" "$mapfile"

            echo "------------------------------------------"
            echo "Placing permanent group instance for '$definename'..."
            read -p "Group Position (gx gy gz) [default: 0 0 0]: " gx gy gz
            gx=${gx:-0}; gy=${gy:-0}; gz=${gz:-0}

            read -p "Group Rotation (grot) [default: 0]: " grot
            grot=${grot:-0}

            echo -e "\ngroup $definename\n  rot $grot\n  shift $gx $gy $gz\nend" >> "$mapfile"
            break
        fi
    done

    read -p "Is the map complete? [y/N]: " map_done
    if [[ "$map_done" =~ ^[Yy]$ ]]; then
        sed -i "/^# IN_PROGRESS_DEFINE:/d" "$mapfile"
        break
    fi
done

echo "Map build session complete. Saved to: $mapfile"
