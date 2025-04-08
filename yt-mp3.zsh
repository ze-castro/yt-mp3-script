#!/bin/zsh

# CONFIGURATION
BASE_DIR="$HOME/Downloads"
MUSIC_DIR="$BASE_DIR/music"
BROWSER="firefox"
COOKIES_FILE="youtube.cookies.txt"

# FUNCTION DEFINITIONS
check_dependencies() {
  if ! command -v yt-dlp &> /dev/null; then
    echo "Error: yt-dlp is not installed! Please install yt-dlp before running this script."
    exit 1
  fi
  
  if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg is not installed! Please install ffmpeg before running this script."
    exit 1
  fi
}

get_browser_cookies() {
  echo "Getting cookies from $BROWSER browser..."
  yt-dlp --cookies-from-browser $BROWSER --cookies $COOKIES_FILE -f "bestaudio" --skip-download "https://www.youtube.com"
  
  if [ ! -f $COOKIES_FILE ]; then
    echo "Error: Failed to get cookies! Make sure you are logged into YouTube in your browser."
    exit 1
  fi
  
  echo "Successfully retrieved cookies from $BROWSER"
}

get_youtube_url() {
  echo -n "Enter YouTube Playlist or Song URL: "
  read url
  
  if [[ -z "$url" ]]; then
    echo "Error: Invalid input. You must provide a song or playlist URL."
    exit 1
  fi
  
  echo "Downloading from URL: $url"
  return 0
}

download_audio() {
  local url=$1
  
  # Create folder if it doesn't exist
  mkdir -p "$MUSIC_DIR"
  
  # Download using yt-dlp
  yt-dlp -x --audio-format aac \
    --audio-quality 0 \
    --embed-thumbnail \
    --embed-metadata \
    --add-metadata \
    --cookies $COOKIES_FILE \
    --metadata-from-title "%(title)s" \
    -o "$MUSIC_DIR/%(title)s.%(ext)s" \
    "$url"
    
  echo "Download complete!"
}

sanitize_filename() {
  local original_filename=$1
  local file_path=$2
  
  # Create fully sanitized version (removing parentheses)
  local clean_filename=$(echo "$original_filename" | sed -E 's/\([^)]*\)//g')
  clean_filename=$(echo "$clean_filename" | sed -E 's/\[[^]]*\]//g')
  clean_filename=$(echo "$clean_filename" | sed -E $'s/[|｜/].*$//')
  clean_filename=$(echo "$clean_filename" | sed -E 's/^[^-]+ - //g')
  clean_filename=$(echo "$clean_filename" | tr -s ' ' | sed -E 's/^ +| +$//g')
  
  # Check if sanitized name would cause a conflict
  local potential_new_file="${file_path%/*}/${clean_filename}.m4a"
  
  if [ -f "$potential_new_file" ] && [ "$file_path" != "$potential_new_file" ]; then
    # Conflict detected! Create version that preserves parentheses
    local preserved_filename=$(echo "$original_filename" | sed -E 's/\[[^]]*\]//g')
    preserved_filename=$(echo "$preserved_filename" | sed -E $'s/[|｜/].*$//')
    preserved_filename=$(echo "$preserved_filename" | sed -E 's/^[^-]+ - //g')
    preserved_filename=$(echo "$preserved_filename" | tr -s ' ' | sed -E 's/^ +| +$//g')
    
    echo "${preserved_filename}"
  else
    # No conflict, use fully sanitized version
    echo "${clean_filename}"
  fi
}

update_metadata() {
  local file_path=$1
  local clean_artist=$2
  local sanitized_title=${3%.m4a}  # Remove extension for title
  
  ffmpeg -i "$file_path" \
    -metadata artist="$clean_artist" \
    -metadata title="$sanitized_title" \
    -codec copy "${file_path%.m4a}_temp.m4a"
    
  mv "${file_path%.m4a}_temp.m4a" "$file_path"
  echo "Updated metadata for: $file_path"
}

process_files() {
  for file in "$MUSIC_DIR/"*.m4a; do
    if [ ! -f "$file" ]; then
      continue
    fi
    
    # Extract metadata using ffprobe
    local artist=$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$file")
    
    if [[ -n "$artist" ]]; then
      # Keep only the first artist name
      local clean_artist=$(echo "$artist" | sed -E 's/[,&;].*//')
      
      # Get original filename without extension
      local original_filename=$(basename "$file" .m4a)
      echo "Original: $original_filename"
      
      # Sanitize the filename
      local sanitized_filename=$(sanitize_filename "$original_filename" "$file")
      
      # Add extension back
      sanitized_filename="${sanitized_filename}.m4a"
      
      # Create new file path
      local new_file="${file%/*}/$sanitized_filename"
      
      # Rename file
      mv "$file" "$new_file"
      echo "Sanitized filename: $file -> $new_file"
      
      # Update metadata
      update_metadata "$new_file" "$clean_artist" "$sanitized_filename"
      
    else
      echo "Error: Failed to extract artist metadata for $file. Skipping..."
    fi
  done
  
  echo "Sanitization complete!"
}

cleanup() {
  rm -f $COOKIES_FILE
  echo "All tasks completed successfully!"
}

# MAIN SCRIPT EXECUTION
check_dependencies
get_browser_cookies
get_youtube_url
download_audio "$url"
process_files
cleanup