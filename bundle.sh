#!/bin/bash
set -e

echo_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

echo_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

# Define the bundle directory
BUNDLE_DIR="bundle"

if [ -d "$BUNDLE_DIR" ]; then
    echo_info "Removing existing '$BUNDLE_DIR' directory..."
    rm -rf "$BUNDLE_DIR"
fi

echo_info "Creating '$BUNDLE_DIR' directory structure..."
mkdir -p "$BUNDLE_DIR/assets" "$BUNDLE_DIR/css" "$BUNDLE_DIR/posts"

echo_info "Copying .html files to '$BUNDLE_DIR'..."
cp *.html "$BUNDLE_DIR/"

echo_info "Copying 'assets' directory to '$BUNDLE_DIR/assets'..."
cp -r assets/* "$BUNDLE_DIR/assets/"

echo_info "Copying 'css' directory to '$BUNDLE_DIR/css'..."
cp -r css/* "$BUNDLE_DIR/css/"

echo_info "Running 'convert.sh' in the 'posts' directory..."
pushd posts > /dev/null
if [ -x "./convert.sh" ]; then
    ./convert.sh
else
    echo_error "'convert.sh' is not executable or not found in 'posts' directory."
    exit 1
fi
popd > /dev/null

echo_info "Copying .md files to '$BUNDLE_DIR/posts'..."
cp posts/*.md "$BUNDLE_DIR/posts/"

# Verify that the necessary files have been copied.
echo_info "Verifying bundle contents..."
if [ -d "$BUNDLE_DIR" ] && \
   ls "$BUNDLE_DIR"/*.html &> /dev/null && \
   [ -d "$BUNDLE_DIR/assets" ] && \
   [ -d "$BUNDLE_DIR/css" ] && \
   [ -d "$BUNDLE_DIR/posts" ] && \
   ls "$BUNDLE_DIR/posts"/*.md &> /dev/null; then
    echo -e "\033[1;32mBundle created successfully in '$BUNDLE_DIR' directory.\033[0m"
else
    echo_error "Bundle creation failed. Please check the script for issues."
    exit 1
fi
