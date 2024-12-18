#!/bin/bash

# Usage: ./multiple_files.sh <number_of_copies> <target_directory>
# Example: ./multiple_files.sh 100000 /mnt

# Number of files to create
NUM_FILES=$1

# Target directory where files will be created
TARGET_DIR=$2

RUN=$3

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Target directory $TARGET_DIR does not exist. Exiting."
  exit 1
fi

# Create files
for i in $(seq 1 $NUM_FILES); do
  DIR_PATH="$TARGET_DIR/dir_$(($i % 1000))"  # Create subdirectories to avoid too many files in a single directory
  FILE_PATH="$DIR_PATH/file_$i-$RUN.txt"

  # Create nested directory if it doesn't exist
  mkdir -p $DIR_PATH

  # Create a file with random content
  FILE_PATH="$DIR_PATH/file_$i-$RUN-1.txt"
  base64 /dev/urandom | head -c 5K > $FILE_PATH &
  FILE_PATH="$DIR_PATH/file_$i-$RUN-2.txt"
  base64 /dev/urandom | head -c 5K > $FILE_PATH &
  FILE_PATH="$DIR_PATH/file_$i-$RUN-3.txt"
  base64 /dev/urandom | head -c 5K > $FILE_PATH &
  FILE_PATH="$DIR_PATH/file_$i-$RUN-4.txt"
  base64 /dev/urandom | head -c 5K > $FILE_PATH &
  wait $!

  if [ $((i % 1000)) -eq 0 ]; then
    echo "Created $i files..."
  fi
done

echo "File creation complete."
