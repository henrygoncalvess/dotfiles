#!/usr/bin/env bash

SRC_DIR="$1"
THUMB_DIR="$2"

mkdir -p "$THUMB_DIR"

if command -v magick &> /dev/null; then
  CMD="magick"
else
  CMD="convert"
fi

# Find all valid wallpaper files and generate missing thumbnails
find "$SRC_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) | while read -r file; do
  fname=$(basename "$file")
  if [ ! -f "$THUMB_DIR/$fname" ]; then
    $CMD "$file" -resize x250 -quality 70 "$THUMB_DIR/$fname" &
  fi
done

# For videos
if command -v ffmpeg &> /dev/null; then
  find "$SRC_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.webm" \) | while read -r file; do
    fname=$(basename "$file")
    if [ ! -f "$THUMB_DIR/$fname" ]; then
      ffmpeg -i "$file" -vframes 1 -vf "scale=-1:250" -q:v 2 "$THUMB_DIR/${fname%.*}.jpg" -y &
      # Quickshell WallpaperPicker seems to expect exact filename for videos too
      # Wait, how does localFolderModel know it's a video if the thumbnail is .jpg?
      # WallpaperPicker uses fileName from localFolderModel. So the thumbnail MUST have the original extension, even if it's actually a jpeg image!
      mv "$THUMB_DIR/${fname%.*}.jpg" "$THUMB_DIR/$fname" 2>/dev/null || true
    fi
  done
fi

wait
