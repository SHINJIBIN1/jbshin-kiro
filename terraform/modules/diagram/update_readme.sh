#!/bin/bash

# Script to update README.md with generated diagrams
# This script is called by the diagram module after generating diagrams

# Parameters
README_PATH=$1
DIAGRAM_DIR=$2
SCALE=$3
MERMAID_CODE=$4  # Optional: Mermaid code if no image is available

# Check if parameters are provided
if [ -z "$README_PATH" ] || [ -z "$DIAGRAM_DIR" ] || [ -z "$SCALE" ]; then
  echo "Usage: $0 <readme_path> <diagram_dir> <scale> [mermaid_code]"
  exit 1
fi

# Check if README file exists
if [ ! -f "$README_PATH" ]; then
  echo "README file not found at $README_PATH"
  exit 1
fi

# Create backup of README
cp "$README_PATH" "${README_PATH}.bak"

# Check for diagram files in order of preference
DIAGRAM_FORMATS=("png" "svg" "jpg" "jpeg" "gif")
DIAGRAM_PATH=""
DIAGRAM_FORMAT=""

for format in "${DIAGRAM_FORMATS[@]}"; do
  if [ -f "${DIAGRAM_DIR}/${SCALE}_infrastructure.${format}" ]; then
    DIAGRAM_PATH="${DIAGRAM_DIR}/${SCALE}_infrastructure.${format}"
    DIAGRAM_FORMAT="${format}"
    break
  fi
done

# Check if we have a diagram file or Mermaid code
if [ -n "$DIAGRAM_PATH" ]; then
  # Create relative path from README to diagram
  RELATIVE_PATH=$(realpath --relative-to=$(dirname "$README_PATH") "$DIAGRAM_PATH")
  
  # Prepare the diagram markdown
  DIAGRAM_MARKDOWN="![${SCALE^} Scale Infrastructure]($RELATIVE_PATH)"
  echo "Using diagram image: $DIAGRAM_PATH"
elif [ -n "$MERMAID_CODE" ]; then
  # Use Mermaid code if provided and no image is available
  DIAGRAM_MARKDOWN="\`\`\`mermaid\n$MERMAID_CODE\n\`\`\`"
  echo "Using Mermaid code (no image available)"
elif [ -f "${DIAGRAM_DIR}/${SCALE}_infrastructure.txt" ]; then
  # Use Mermaid code from text file if available
  MERMAID_CODE=$(cat "${DIAGRAM_DIR}/${SCALE}_infrastructure.txt")
  DIAGRAM_MARKDOWN="\`\`\`mermaid\n$MERMAID_CODE\n\`\`\`"
  echo "Using Mermaid code from text file"
else
  echo "No diagram image or Mermaid code available"
  exit 1
fi

# Function to update or add diagram section
update_readme() {
  local title="${SCALE^} Scale Infrastructure Diagram"
  local section_exists=$(grep -c "## ${title}" "$README_PATH")
  
  if [ "$section_exists" -gt 0 ]; then
    # Update existing diagram section
    # Use perl for multiline replacement (more reliable than sed for complex replacements)
    perl -i -0pe "s|(## ${title}\n\n).*?(\n\n##|\n\$)|\\1$DIAGRAM_MARKDOWN\\2|s" "$README_PATH"
    echo "Updated existing diagram section in README"
  else
    # Add new diagram section
    if grep -q "^## Infrastructure Diagrams" "$README_PATH"; then
      # Add under existing Infrastructure Diagrams section
      perl -i -0pe "s|(## Infrastructure Diagrams\n\n)|\1## ${title}\n\n$DIAGRAM_MARKDOWN\n\n|s" "$README_PATH"
      echo "Added new diagram section under Infrastructure Diagrams section"
    elif grep -q "^## Usage" "$README_PATH"; then
      # Add before Usage section
      perl -i -0pe "s|(## Usage)|\n## ${title}\n\n$DIAGRAM_MARKDOWN\n\n\1|s" "$README_PATH"
      echo "Added new diagram section before Usage section"
    else
      # Append to the end of the file
      cat >> "$README_PATH" << EOF

## ${title}

$DIAGRAM_MARKDOWN

EOF
      echo "Added new diagram section at the end of README"
    fi
  fi
}

# Check if we need to create an Infrastructure Diagrams section
if ! grep -q "^## Infrastructure Diagrams" "$README_PATH" && ! grep -q "## ${SCALE^} Scale Infrastructure Diagram" "$README_PATH"; then
  # Find a good place to insert the section
  if grep -q "^## Usage" "$README_PATH"; then
    # Add before Usage section
    perl -i -0pe "s|(## Usage)|\n## Infrastructure Diagrams\n\n\1|s" "$README_PATH"
  else
    # Append to the end of the file
    echo -e "\n## Infrastructure Diagrams\n" >> "$README_PATH"
  fi
  echo "Created Infrastructure Diagrams section"
fi

# Update the README with the diagram
update_readme

echo "README updated successfully with ${SCALE} scale diagram"

# Add a note about the diagram generation
cat >> "$README_PATH" << EOF

> Note: The ${SCALE} scale infrastructure diagram was automatically generated on $(date '+%Y-%m-%d %H:%M:%S').

EOF

echo "Added timestamp to README"