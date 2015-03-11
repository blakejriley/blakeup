#!/bin/bash

# Blakeup
# Back up selected folders using rsync and preserve a limited history to allow for rollbacks.
# Copyright (C) 2014–2015  Blake J. Riley
#
#
# Created 2014-01-16
# Last updated 2015-03-10
# 
#
# The most recent backup is stored in dst_dir/Current
# The previous backup is stored in dst_dir/History/B-1
# The backup before that is stored in dst_dir/History/B-2
# etc
# Each backup contains a log file of all the changes since the previous backup.
#
# Note that among all these backups, only files that changed between backups have more than 1 physical copy, although it looks like there are multiple copies of every file. This is because each backup contains a hard link to each file.
#
# Some inspiration and methodology from Mike Rubel at http://www.mikerubel.org/computers/rsync_snapshots/

#########################################
# Configure your backup here:

# directories to back up (minimum 1; no maximum)
src_dirs=(\
 /source/directory/one\
 /source/directory/two\
)

# backup destination (list exactly 1)
dst_dir=/destination/directory

# number of backups (minimum 1; no maximum)
declare -i nBackups=4

# Are all of the source and destination directories located in Linux (ext) filesystems? If yes, set this to true. If no (for example, if one of the directories is located in an NTFS or FAT filesystem), set this to false. IF UNSURE, SET THIS TO false. (See link-dest_problems.txt to understand the purpose of this flag.)
ext_only=false
#########################################



# verify user input
if [ "$nBackups" -lt 1 ]; then
	echo "Invalid input (number of backups)"
	echo "Backup canceled"
	exit 1
fi

# begin
echo "Backup now in progress"

# verify existence of configured directories
echo "Verifying configured directories..."
dir_missing=false
for dir in ${src_dirs[@]}; do
	if [ ! -d "$dir" ]; then
		printf "Source directory not found: %s\n", "$dir"
		dir_missing=true
	fi
done
if [ ! -d "$dst_dir" ]; then
	printf "Destination directory not found: %s\n", "$dst_dir"
	dir_missing=true
fi
if [ "$dir_missing" == true ]; then
	echo "Backup canceled"
	exit 1
fi

# shift all backups
echo "Shifting locations of previous backups..."
b=$nBackups
while [ $b -gt 1 ]; do
	if [ -d "$dst_dir"/History/B-$(($b-1)) ]; then
		mv "$dst_dir"/History/B-$(($b-1)) "$dst_dir"/History/B-$b
	fi
    let b--
done
if [ -d "$dst_dir"/Current ]; then
	mkdir -p "$dst_dir"/History
	if [ "$ext_only" == true ]; then
		mv "$dst_dir"/Current "$dst_dir"/History/B-1
	else
		cp -al "$dst_dir"/Current "$dst_dir"/History/B-1
	fi
fi

# prepare for log file
log_dir="$dst_dir"/Current
if [ -d "$log_dir" ]; then	
	rm "$log_dir"/rsync.log.* # make room for new log file
else
	mkdir -p "$log_dir" # must exist before rsync --log-file is executed
fi
log_name="$log_dir"/rsync.log.$(date +%Y%m%d%H%M%S)

# create new backup and log it
echo "Performing new backup..."
if [ "$ext_only" == true ]; then
	rsync -avi --delete --progress --log-file="$log_name" "${src_dirs[@]}" --link-dest="$dst_dir" "$dst_dir"/Current
else
	rsync -avi --delete --progress --log-file="$log_name" "${src_dirs[@]}" "$dst_dir"/Current
fi

# remove oldest backup
if [ -d "$dst_dir"/History/B-$(($nBackups)) ]; then
	echo "Removing oldest backup..."
	rm -rf "$dst_dir"/History/B-$(($nBackups))
fi

echo "Backup complete!"

