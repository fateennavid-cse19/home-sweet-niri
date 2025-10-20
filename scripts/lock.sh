#!/bin/bash

# Define the paths and colors
WALLPAPER_PATH=$(swww query | awk '{print $NF}')
TEMP_IMAGE="/tmp/gtklock-blurred-wallpaper.png"

# --- Dynamic Color Calculation & Image Processing ---
if [ -f "$WALLPAPER_PATH" ]; then
    
    # Create the blurred image (using 'magick' as specified in your script)
    magick "$WALLPAPER_PATH" -blur 0x10 "$TEMP_IMAGE"
    gtklock -c ~/.config/gtklock/config.ini

    # Get the average brightness (Lightness) of the original wallpaper.
    # The output is a number from 0 to 100%. We use 'bc -l' for floating point math.

else
    echo "Error: Could not find wallpaper path. Using fallback color."
    gtklock -c ~/.config/gtklock/config.ini
    # Use a default color if the image is missing (e.g., light text for a dark default background) 
fi

