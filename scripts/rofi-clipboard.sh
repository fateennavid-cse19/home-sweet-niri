#!/usr/bin/env bash

# requires ImageMagick to generate thumbnails

# --- Configuration ---
thumbnail_size=64
thumbnail_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cliphist/thumbnails"

# --- Setup and List Generation ---
cliphist_list=$(cliphist list)

if [ -z "$cliphist_list" ]; then
    # Use rofi's message mode or a dummy list for "no content"
    rofi -dmenu -theme-str 'listview { enabled: false; }' -p "cliphist" -mesg "cliphist: please store something first"
    rm -rf "$thumbnail_dir"
    exit
fi

[ -d "$thumbnail_dir" ] || mkdir -p "$thumbnail_dir"

# --- Thumbnail Generation and Formatting for Rofi ---

read -r -d '' thumbnail_gawk <<'EOF'
/^[0-9]+\s<meta http-equiv=/ { next }
# Match binary items (images)
match($0, /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/, grp) {
    cliphist_item_id=grp[1]
    ext=grp[3]
    thumbnail_file=cliphist_item_id "." ext

    # Compose full thumbnail path from gawk variables
    cmd = "[ -f \"" thumbnail_dir "/" thumbnail_file "\" ] || " \
          "printf \"%s\t\" " cliphist_item_id " | " \
          "cliphist decode | " \
          "magick - -thumbnail " thumbnail_size "^ -gravity center " \
          "-extent " thumbnail_size "x" thumbnail_size " \"" thumbnail_dir "/" thumbnail_file "\""

    # Generate thumbnail if not exists
    system(cmd)

    # Print entry with icon in rofi's expected format with thumbnail:// prefix
    print "Image #" cliphist_item_id " (" ext ")" "\0icon\x1fthumbnail://" thumbnail_dir "/" thumbnail_file
    next
}
# Print all other (text) entries as is
1
EOF

# --- Rofi Execution ---
item=$(echo "$cliphist_list" | gawk -v thumbnail_dir="$thumbnail_dir" -v thumbnail_size="$thumbnail_size" "$thumbnail_gawk" | rofi -dmenu \
    -show-icons \
    -theme ~/.config/rofi/clipboard-theme/clipboard-theme.rasi \
    -format 's' \
    -p "Clipboard History" \
    -i \
    -no-sort \
    -columns 1 \
    -matching fuzzy \
    -kb-custom-1 'Alt+c' \
    -lines 10)
exit_code=$?

# --- Post-selection Actions ---

# Alt+C to clear history (exit code 10)
if [ "$exit_code" -eq 10 ]; then
    confirmation=$(echo -e "Yes\nNo" | rofi -dmenu -format 's' -p "Delete history?" -lines 2)
    if [ "$confirmation" == "Yes" ]; then
        rm ~/.cache/cliphist/db 2>/dev/null
        rm -rf "$thumbnail_dir" 2>/dev/null
    fi
elif [ "$exit_code" -eq 0 ]; then
    [ -n "$item" ] && echo "$item" | cliphist decode | wl-copy
fi

# --- Cleanup Thumbnails ---

find "$thumbnail_dir" -type f | while IFS= read -r thumbnail_file; do
    cliphist_item_id=$(basename "${thumbnail_file%.*}")
    if ! grep -q "^${cliphist_item_id}\s" <<< "$cliphist_list"; then
        rm "$thumbnail_file"
    fi
done
