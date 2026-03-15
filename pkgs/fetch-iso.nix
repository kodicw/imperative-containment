{ pkgs, gum, jq, quickemu }:

pkgs.writeShellApplication {
  name = "fetch-iso";
  runtimeInputs = [ quickemu gum jq pkgs.coreutils pkgs.findutils pkgs.gnugrep ];
  text = ''
    set -e

    if [ "$#" -gt 0 ]; then
      echo "Usage: fetch-iso"
      echo "  Starts an interactive CLI to download an OS ISO."
      exit 1
    fi

    echo "Fetching available OS list from quickget..."
    
    # Run quickget in a subshell to capture output without polluting terminal
    # Redirect stderr to /dev/null to suppress "Project -" banner
    OS_JSON=$(quickget --list-json 2>/dev/null)

    if [ -z "$OS_JSON" ]; then
      echo "Failed to fetch OS list from quickget."
      exit 1
    fi

    # Parse JSON into "OS Release Option" format for selection
    # Using tab as separator for cleaner display
    # We pipe into gum filter for interactive selection
    SELECTION=$(echo "$OS_JSON" | jq -r '.[] | "\(.OS)\t\(.Release)\t\(.Option // "")"' | \
      gum filter --placeholder "Select OS to download..." --height 20)

    if [ -z "$SELECTION" ]; then
      echo "No OS selected."
      exit 1
    fi

    # Extract fields from selection
    OS=$(echo "$SELECTION" | cut -f1)
    RELEASE=$(echo "$SELECTION" | cut -f2)
    OPTION=$(echo "$SELECTION" | cut -f3)

    echo "Selected: $OS $RELEASE $OPTION"
    
    # Create temporary directory for quickget operations
    TMP_DIR=$(mktemp -d)
    # Ensure cleanup on exit
    trap 'rm -rf "$TMP_DIR"' EXIT

    # Change to temp dir to contain downloads
    cd "$TMP_DIR" || exit 1

    echo "Downloading ISO... (This may take a while)"
    
    # Run quickget directly to show progress bars
    # Using 'eval' to handle empty option correctly if it's empty string
    if [ -n "$OPTION" ]; then
      quickget "$OS" "$RELEASE" "$OPTION"
    else
      quickget "$OS" "$RELEASE"
    fi

    # Find the largest ISO file (assumed to be the main OS image)
    # quickget sometimes downloads small unattended ISOs or virtio ISOs
    # We want the big one.
    ISO_FILE=$(find . -name "*.iso" -type f -exec du -b {} + | sort -rn | head -n1 | cut -f2)

    if [ -z "$ISO_FILE" ]; then
      echo "No ISO file found downloaded by quickget."
      ls -Rlh .
      exit 1
    fi
    
    # Remove leading ./ from find output
    ISO_FILENAME=$(basename "$ISO_FILE")

    echo "Downloaded: $ISO_FILENAME"

    # Ask user for destination filename, defaulting to original name
    TARGET_NAME=$(gum input --value "$ISO_FILENAME" --placeholder "Save as filename...")

    if [ -z "$TARGET_NAME" ]; then
      TARGET_NAME="$ISO_FILENAME"
    fi
    
    # Move file to original directory (OLDPWD)
    TARGET_PATH="$OLDPWD/$TARGET_NAME"

    if [ -e "$TARGET_PATH" ]; then
      if ! gum confirm "File '$TARGET_NAME' already exists. Overwrite?"; then
        echo "Aborted."
        exit 1
      fi
    fi

    mv "$ISO_FILE" "$TARGET_PATH"
    echo "Saved to $TARGET_PATH"
    
    # Trap will clean up TMP_DIR
  '';
}
