#!/bin/bash
# This scipt create 100000 files in the mounted ceph volume. This should be ran from the client where the ceph volume is mounted.

cat <<'EOF' > multiple_files.sh
#!/bin/bash

# Usage: ./multiple_files.sh <number_of_copies> <target_directory>
# Example: ./multiple_files.sh 100000 /mnt

# Number of files to create
NUM_FILES=$1

# Target directory where files will be created
TARGET_DIR=$2

# Check if target directory exists
if [ ! -d "$TARGET_DIR" ]; then
  echo "Target directory $TARGET_DIR does not exist. Exiting."
  exit 1
fi

# Create files
for i in $(seq 1 $NUM_FILES); do
  DIR_PATH="$TARGET_DIR/dir_$(($i % 1000))"  # Create subdirectories to avoid too many files in a single directory
  FILE_PATH="$DIR_PATH/file_$i.txt"

  # Create nested directory if it doesn't exist
  mkdir -p $DIR_PATH

  # Create a file with random content
  base64 /dev/urandom | head -c 10K > $FILE_PATH

  if [ $((i % 1000)) -eq 0 ]; then
    echo "Created $i files..."
  fi
done

echo "File creation complete."
EOF

chmod +x multiple_files.sh


# Step 5: Copy and execute the file creation script
#cp ./multiple_files.sh $POD_NAME:/mnt/multiple_files.sh -n openshift-storage
chmod +x /root/multiple_files.sh
/root/multiple_files.sh 100000 /mnt
