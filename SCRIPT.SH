#!/bin/bash
set -e

FILE_PATH="$1"          # Absolute path to active file in IntelliJ ($FilePath$)
PROJECT_DIR="$2"        # Project root ($ProjectFileDir$)

if [[ -z "$FILE_PATH" || -z "$PROJECT_DIR" ]]; then
  echo "Error: FilePath or ProjectDir not provided."
  exit 1
fi

if [[ "$FILE_PATH" != *"src/main/java"* ]]; then
  echo "Notice: Opened file is not under src/main/java. Skipping."
  exit 0
fi

# 1. Resolve matching Test file path
TEST_FILE_PATH="${FILE_PATH/src\/main\/java/src\/test\/java}"
TEST_FILE_PATH="${TEST_FILE_PATH%.java}Test.java"

# 2. Get git diff for the file (uncommitted changes)
cd "$PROJECT_DIR"
DIFF=$(git diff HEAD -- "$FILE_PATH")

if [ -z "$DIFF" ]; then
  # Fallback to the latest commit if already committed
  DIFF=$(git diff HEAD~1 -- "$FILE_PATH" || true)
fi

echo "Source File : $FILE_PATH"
echo "Test File   : $TEST_FILE_PATH"

# 3. Call OpenCode with only the dynamic file context and diff
# OpenCode will automatically adhere to your agent.md guidelines
opencode run "Follow the testing instructions and rules in agent.md.
Analyze the diff for '$FILE_PATH' and update or create its unit tests in '$TEST_FILE_PATH' to ensure full branch and line coverage for the new changes:

\`\`\`diff
$DIFF
\`\`\`"
