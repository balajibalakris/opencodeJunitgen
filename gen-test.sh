#!/usr/bin/env bash
set -e

SOURCE_FILE="$1"

# --- 1. Validation ---
if [ -z "$SOURCE_FILE" ]; then
    echo "❌ Error: No file provided."
    echo "Usage: ./scripts/gen-test.sh <path-to-java-file>"
    exit 1
fi

if [[ "$SOURCE_FILE" != *.java ]]; then
    echo "❌ Error: '$SOURCE_FILE' is not a Java file."
    exit 1
fi

if [[ "$SOURCE_FILE" != *"src/main/java"* ]]; then
    echo "❌ Error: The file must be inside 'src/main/java'."
    exit 1
fi

# --- 2. Calculate Target Test Path and Module ---
CLASS_NAME=$(basename "$SOURCE_FILE" .java)
TEST_CLASS_NAME="${CLASS_NAME}Test"

# Replace 'src/main/java' with 'src/test/java' and append 'Test.java'
TARGET_TEST_FILE="${SOURCE_FILE/src\/main\/java/src\/test\/java}"
TARGET_TEST_FILE="${TARGET_TEST_FILE%.java}Test.java"
TARGET_TEST_DIR=$(dirname "$TARGET_TEST_FILE")

echo "=================================================="
echo "🎯 Source Class : $CLASS_NAME ($SOURCE_FILE)"
echo "📁 Target Test   : $TARGET_TEST_FILE"
echo "=================================================="

# Create the test directory structure if it doesn't exist
mkdir -p "$TARGET_TEST_DIR"

# --- 3. Locate Project Root & agents.md ---
# Find project root where pom.xml or .git resides
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

AGENTS_FILE=""
if [ -f "$PROJECT_ROOT/agents.md" ]; then
    AGENTS_FILE="$PROJECT_ROOT/agents.md"
elif [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
    AGENTS_FILE="$PROJECT_ROOT/AGENTS.md"
fi

if [ -n "$AGENTS_FILE" ]; then
    echo "📋 Found project instructions at: $(basename "$AGENTS_FILE")"
fi

# --- 4. Construct Prompt & Run OpenCode ---
PROMPT_TMP=$(mktemp)

cat <<EOF > "$PROMPT_TMP"
You are generating a unit test for the Java class: $CLASS_NAME.

Source file to test: $SOURCE_FILE
Output file to create/overwrite: $TARGET_TEST_FILE

$(if [ -n "$AGENTS_FILE" ]; then
    echo "--- PROJECT CODING STANDARDS (from $(basename "$AGENTS_FILE")) ---"
    cat "$AGENTS_FILE"
    echo "---------------------------------------------------------"
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

# --- 5. Verify the Generated Test ---
if [ ! -f "$TARGET_TEST_FILE" ]; then
    echo "❌ Error: OpenCode did not create $TARGET_TEST_FILE."
    exit 1
fi

echo "🧪 Running single test execution via Maven..."
cd "$PROJECT_ROOT"

if [ -f "./mvnw" ]; then
    MAVEN_CMD="./mvnw"
else
    MAVEN_CMD="mvn"
fi

# Run only this specific test class
$MAVEN_CMD test -Dtest="$TEST_CLASS_NAME"

if [ $? -eq 0 ]; then
    echo "✅ Success! $TEST_CLASS_NAME generated and passed all tests."
else
    echo "⚠️ $TEST_CLASS_NAME was created but failed to pass/compile. Review the test file."
fi
