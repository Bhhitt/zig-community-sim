#!/bin/bash
# Simple script to build and run all tests for the project

set -e

echo "Building and running all tests..."
zig build test

EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "\nAll tests passed!"
else
    echo "\nSome tests failed. Check the output above."
fi
