#!/bin/bash

MEGS=2000

path="/tmp/${0##*/}"

echo "Preparing source file..."
mkdir -p "$path" && mount -t tmpfs -o size="${MEGS}M" tmpfs "$path" || exit 1
dd if=/dev/urandom of="$path/big" bs=1M count="$MEGS"

echo "Starting benchmark..."
ionice -c2  bash -c "dd if=\"$path/big\" of=ionice-a bs=8M && rm ionice-a && echo 'best-effort done'" &
ionice -c3  bash -c "dd if=\"$path/big\" of=ionice-b bs=8M && rm ionice-b && echo 'idle done'" &

wait

umount "$path" && rmdir "$path"
