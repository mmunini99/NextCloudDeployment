#!/bin/bash

# Create a 1KB file with 
dd if=/dev/zero of="1KB__file" bs=1K count=1

# Create a 1MB file 
dd if=/dev/zero of="1MB__file" bs=1M count=1

# Create a 1GB file 
dd if=/dev/zero of="1GB__file" bs=1G count=1

echo "Files created: '1KB file', '1MB file', '1GB file'"
