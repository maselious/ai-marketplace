# Script Testing

Verification patterns for generated shell scripts during Gate 3.5.

## Platform Detection

    os=$(uname -s)
    case "$os" in
      Linux*)  platform="linux" ;;
      Darwin*) platform="mac" ;;
      MINGW*|MSYS*|CYGWIN*) platform="windows-native" ;;
      *) platform="unknown" ;;
    esac

    # Detect WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
      platform="windows-wsl"
    fi

    # Check git autocrlf
    autocrlf=$(git config core.autocrlf || echo "not set")
    if [ "$autocrlf" = "true" ]; then
      echo "⚠️ core.autocrlf=true may corrupt scripts"
      echo "Recommend: git config core.autocrlf input"
    fi

## .gitattributes

Generate at `.claude/.gitattributes`:

    *.sh text eol=lf
    *.yaml text eol=lf

## Validation Steps

### Permissions

    chmod +x .claude/scripts/*.sh

### Syntax Check

    for script in .claude/scripts/*.sh; do
      bash -n "$script" 2>&1 && echo "✅ $(basename $script)" || echo "❌ $(basename $script)"
    done

### Line Endings

    for script in .claude/scripts/*.sh; do
      if file "$script" | grep -q CRLF; then
        sed -i 's/\r$//' "$script"
        echo "Fixed CRLF → LF: $(basename $script)"
      fi
    done

## Integration Smoke Tests

### GitHub

    # Create test issue
    test_id=$(gh issue create \
      --title "pm-core-smoke-test-$(date +%s)" \
      --label "pm:task" \
      --body "Automated smoke test — will be deleted" \
      --json number -q .number)

    # Test sync
    .claude/scripts/pm-sync.sh "$test_id"

    # Test close
    .claude/scripts/pm-close.sh "$test_id"

    # Cleanup
    gh issue delete "$test_id" --yes 2>/dev/null || \
      gh issue edit "$test_id" --add-label "pm-test-cleanup"

### BACKLOG.md

    # Verify structure
    for section in "Active" "Ready" "Blocked" "Done"; do
      grep -q "## $section" ".claude/pm/BACKLOG.md" || echo "❌ Missing: ## $section"
    done

## Iteration Protocol

If any test fails:
1. Read error output
2. Read the failing script source
3. Identify root cause
4. Fix the script
5. Re-run only the failed test
6. Max 3 attempts per script — then escalate to user
