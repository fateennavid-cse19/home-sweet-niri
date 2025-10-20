#!/bin/bash

# Rofi Wallpaper Picker with Icon Preview and Thumbnail Caching - FINAL FIX

# --- CONFIGURATION & SETUP ---

# CRITICAL FIX: Define the HOME directory reliably (for use in Rofi keybinds)
USER_HOME=$(getent passwd "$USER" | cut -d: -f6)
USER_HOME="${USER_HOME:-$HOME}"

WALLPAPER_ROOT="$USER_HOME/.config/niri/niri-walls"
CACHE_DIR="$USER_HOME/.config/rofi-wallpaper-cache"
CACHE_ROOT="$CACHE_DIR/thumbs"

# CRITICAL FIX: Delete and Recreate Cache Directory on every run 
rm -rf "$CACHE_DIR"

# Create directories (now recreated after deletion)
mkdir -p "$WALLPAPER_ROOT"
mkdir -p "$CACHE_ROOT"

# ----------------------------------------------------
# --- FUNCTIONS (MUST BE DEFINED BEFORE BEING CALLED) ---
# ----------------------------------------------------

# Function to create a 600x600 square thumbnail using ffmpeg
function cacheImg {
    # NOTE: Function name is corrected to lowercase 'cacheImg'
    local input_path="$1"
    local output_path="$2"
    
    # Use ffmpeg with correct line continuations (\)
    ffmpeg -i "$input_path" -y -loglevel quiet \
        -vf "scale='if(lt(iw,ih),600,-1)':'if(lt(iw,ih),-1,600)',crop=600:600:exact=1" \
        "$output_path"
        
    # CRITICAL FIX: Clean spacing for 'if' statement
    if [ -f "$output_path" ]; then
        echo "$output_path"
    else
        # Print an error to stderr (not to Rofi) and return an empty path
        echo "ERROR: Failed to create thumbnail for $input_path. Check file or ffmpeg." >&2
        # Return an empty string which will be ignored by Rofi
        echo ""
    fi
}

# Function to get the filename without extension
function getFileName {
    echo "$1" | xargs basename | awk -F'.' '{print $1}' | tr '[:upper:]' '[:lower:]'
}


# --- 2. GATHER WALLPAPERS AND CACHE THUMBNAILS ---

# Find all full-size wallpaper paths, EXCLUDING the cache directory.
mapfile -t originPath < <(find "${WALLPAPER_ROOT}" -maxdepth 1 -type f -regex '.*\.\(jpg\|jpeg\|png\|gif\|apng\)$' -not -path "${CACHE_ROOT}/*")

# The cachedPath array is no longer strictly necessary since the cache is deleted every time,
# but we'll keep the associated loop structure for robust variable definition.
declare -A bgresult
declare -A cachedresult
bgnames=()

# Populate bgresult and bgnames from WALLPAPER_ROOT
for pathIDX in "${!originPath[@]}"; do
    filename=$(getFileName "${originPath[$pathIDX]}")
    bgresult["${filename}"]="${originPath[$pathIDX]}"
    bgnames[$pathIDX]+="${filename}"
done

# Force cache creation for all wallpapers
for fName in "${bgnames[@]}"; do
    # Call the function using the correct lowercase name: cacheImg
    cachedresult[$fName]=$(cacheImg "${bgresult[$fName]}" "${CACHE_ROOT}/${fName}.png")
done


# --- 3. GENERATE ROFI LIST & LAUNCH ---

strrr=""
# Format: <display_name>\0icon\x1f<icon_path>\n
for fName in "${bgnames[@]}"; do
    THUMB_PATH="${cachedresult[$fName]}"

    # Only add the entry to Rofi if a valid thumbnail path exists
    if [[ -n "$THUMB_PATH" ]]; then
        strrr+="$(echo -n "${fName}\0icon\x1f${THUMB_PATH}\n")"
    else
        # Skipping entry message is sent to stderr
        echo "Skipping entry for ${fName} due to failed thumbnail." >&2
    fi
done

# Use simplified Rofi call since keybind is used (no need for complex config handling)
selected=$(echo -en "${strrr}" | rofi -dmenu -show-icons -p "Select Wallpaper" )


# Check if a wallpaper was selected
if [[ -z "$selected" ]]; then
    exit 0
fi

# --- 4. APPLY WALLPAPER ---

# Apply the selected wallpaper using swww
swww img "${bgresult[$selected]}" --transition-type=wave --transition-angle=30 --transition-duration=2

echo "Successfully set ${selected} as wallpaper."
