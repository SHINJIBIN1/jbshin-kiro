#!/bin/bash
# Script to package the Lambda function for deployment

# Create a temporary directory
mkdir -p temp

# Copy the Lambda function to the temporary directory
cp scale_transition_handler.js temp/index.js

# Create a package.json file
cat > temp/package.json << EOF
{
  "name": "scale-transition-handler",
  "version": "1.0.0",
  "description": "Lambda function to handle infrastructure scale transitions",
  "main": "index.js",
  "dependencies": {
    "aws-sdk": "^2.1001.0"
  }
}
EOF

# Install dependencies
cd temp
npm install --production
cd ..

# Create the zip file
cd temp
zip -r ../scale_transition_handler.zip .
cd ..

# Clean up
rm -rf temp

echo "Lambda function packaged successfully as scale_transition_handler.zip"