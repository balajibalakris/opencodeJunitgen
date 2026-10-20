#!/usr/bin/env bash
set -e

SOURCE_FILE="$1"

if [ -z "$SOURCE_FILE" ]; then
    echo "❌ Error: No file path provided."
    exit 1
fi

# Convert all backslashes '\' to forward slashes '/' for consistent matching
NORMALIZED_FILE="${SOURCE_FILE//\\//}"

# Check for src/main/java anywhere in the hierarchy (case-insensitive)
shopt -s nocasematch
if [[ "$NORMALIZED_FILE" != *"src/main/java"* ]]; then
    echo "❌ Error: Could not find 'src/main/java' in the path."
    echo "Received Path: $SOURCE_FILE"
    exit 1
fi
shopt -u nocasematch

CLASS_NAME=$(basename "$NORMALIZED_FILE" .java)
TEST_CLASS_NAME="${CLASS_NAME}Test"

# Replace 'src/main/java' with 'src/test/java' anywhere in the hierarchy
TARGET_TEST_FILE="${NORMALIZED_FILE/src\/main\/java/src\/test\/java}"
TARGET_TEST_FILE="${TARGET_TEST_FILE%.java}Test.java"
TARGET_TEST_DIR=$(dirname "$TARGET_TEST_FILE")

echo "=================================================="
echo "🎯 Source Class : $CLASS_NAME"
echo "📁 Target Test   : $TARGET_TEST_FILE"
echo "=================================================="

# Create the test directory structure
mkdir -p "$TARGET_TEST_DIR"

# Locate Project Root & agents.md
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

AGENTS_FILE=""
if [ -f "$PROJECT_ROOT/agents.md" ]; then
    AGENTS_FILE="$PROJECT_ROOT/agents.md"
elif [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
    AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"
fi

PROMPT_TMP=$(mktemp)

cat <<EOF > "$PROMPT_TMP"
You are generating a unit test for the Java class: $CLASS_NAME.

Source file to test: $SOURCE_FILE
Output file to create/overwrite: $TARGET_TEST_FILE

$(if [ -n "$AGENTS_FILE" ]; then
    echo "--- PROJECT CODING STANDARDS ---"
    cat "$AGENTS_FILE"
    echo "--------------------------------"
fi)

STRICT REQUIREMENTS:
1. Write the test class into the exact file: $TARGET_TEST_FILE
2. Follow all rules outlined in the project coding standards above.
3. Use ONLY @ExtendWith(MockitoExtension.class) with @Mock and @InjectMocks.
4. Do NOT use @SpringBootTest or load the Spring Context.
5. Generate tests for:
   - Happy path scenario
   - Edge case / null / exception scenarios
6. Only mock methods that actually exist in the referenced classes. Do not hallucinate methods.
7. Return/write ONLY the valid Java code into $TARGET_TEST_FILE.
EOF

echo "🤖 Generating test with OpenCode..."
opencode "Read $PROMPT_TMP and write the unit test file to $TARGET_TEST_FILE."

rm -f "$PROMPT_TMP"

if [ ! -f "$TARGET_TEST_FILE" ]; then
    echo "❌ Error: OpenCode did not create $TARGET_TEST_FILE."
    exit 1
fi

echo "🧪 Running single test execution via Maven..."
cd "$PROJECT_ROOT"
MAVEN_CMD="./mvnw"
[ ! -f "$MAVEN_CMD" ] && MAVEN_CMD="mvn"

$MAVEN_CMD test -Dtest="$TEST_CLASS_NAME"
