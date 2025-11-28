#!/bin/bash
# scripts/analyze-ci-flakiness.sh
#
# Analyzes CI test flakiness by mining GitHub Actions logs
# Usage: ./scripts/analyze-ci-flakiness.sh [num_runs]
#
# Output: CSV database of test results + summary statistics

set -euo pipefail

NUM_RUNS="${1:-150}"
OUTPUT_DIR="/tmp/ci-flakiness-analysis"
RESULTS_CSV="$OUTPUT_DIR/test-results.csv"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"

echo "🔍 Analyzing last $NUM_RUNS CI runs for test flakiness..."
mkdir -p "$OUTPUT_DIR"

# Initialize CSV with headers
echo "run_id,date,branch,test_suite,test_name,result,duration_seconds" > "$RESULTS_CSV"

# Fetch CI run list
echo "📥 Fetching CI run history..."
gh run list --workflow=ci.yml --limit "$NUM_RUNS" --json databaseId,conclusion,createdAt,headBranch \
  > "$OUTPUT_DIR/runs.json"

# Count runs by status
total_runs=$(jq 'length' "$OUTPUT_DIR/runs.json")
failed_runs=$(jq '[.[] | select(.conclusion == "failure")] | length' "$OUTPUT_DIR/runs.json")
success_runs=$(jq '[.[] | select(.conclusion == "success")] | length' "$OUTPUT_DIR/runs.json")
cancelled_runs=$(jq '[.[] | select(.conclusion == "cancelled")] | length' "$OUTPUT_DIR/runs.json")

echo "📊 Run Summary:"
echo "  Total: $total_runs"
echo "  Failed: $failed_runs ($(awk "BEGIN {printf \"%.1f\", ($failed_runs/$total_runs)*100}")%)"
echo "  Success: $success_runs ($(awk "BEGIN {printf \"%.1f\", ($success_runs/$total_runs)*100}")%)"
echo "  Cancelled: $cancelled_runs"
echo ""

# Get list of failed run IDs
failed_run_ids=$(jq -r '.[] | select(.conclusion == "failure") | .databaseId' "$OUTPUT_DIR/runs.json")

# Sample 20 failed runs for detailed analysis (to avoid rate limits)
sampled_run_ids=$(echo "$failed_run_ids" | head -20)

echo "🔬 Extracting test results from $(echo "$sampled_run_ids" | wc -l | tr -d ' ') failed runs..."
echo ""

run_count=0
for run_id in $sampled_run_ids; do
  run_count=$((run_count + 1))
  echo "[$run_count/20] Processing run $run_id..."

  # Get run metadata
  run_data=$(jq -r ".[] | select(.databaseId == $run_id) | [.createdAt, .headBranch] | @tsv" "$OUTPUT_DIR/runs.json")
  run_date=$(echo "$run_data" | cut -f1)
  run_branch=$(echo "$run_data" | cut -f2)

  # Fetch logs and extract test results
  gh run view "$run_id" --log 2>/dev/null | \
    grep -E "Test Case .* (passed|failed)" | \
    while IFS= read -r line; do
      # Parse test result line
      # Format: Test Case '-[Suite.TestClass testName]' passed/failed (X.XXX seconds).

      if [[ $line =~ Test\ Case\ .*-\[([^\]]+)\.([^\ ]+)\ ([^\]]+)\].*\ (passed|failed)\ \(([0-9.]+)\ seconds\) ]]; then
        suite="${BASH_REMATCH[1]}"
        test_class="${BASH_REMATCH[2]}"
        test_name="${BASH_REMATCH[3]}"
        result="${BASH_REMATCH[4]}"
        duration="${BASH_REMATCH[5]}"

        # Write to CSV
        echo "$run_id,$run_date,$run_branch,$test_class,$test_name,$result,$duration" >> "$RESULTS_CSV"
      fi
    done
done

echo ""
echo "✅ Data collection complete!"
echo ""

# Generate summary statistics
total_test_results=$(tail -n +2 "$RESULTS_CSV" | wc -l | tr -d ' ')
total_failures=$(tail -n +2 "$RESULTS_CSV" | grep ",failed," | wc -l | tr -d ' ')

echo "📈 Test Result Summary:" | tee "$SUMMARY_FILE"
echo "  Total test executions analyzed: $total_test_results" | tee -a "$SUMMARY_FILE"
echo "  Total failures: $total_failures" | tee -a "$SUMMARY_FILE"
echo "" | tee -a "$SUMMARY_FILE"

# Find flakiest test suites
echo "🔥 Top 10 Flakiest Test Suites:" | tee -a "$SUMMARY_FILE"
tail -n +2 "$RESULTS_CSV" | \
  grep ",failed," | \
  cut -d, -f4 | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{printf "  %3d failures - %s\n", $1, $2}' | tee -a "$SUMMARY_FILE"
echo "" | tee -a "$SUMMARY_FILE"

# Find flakiest individual tests
echo "🔥 Top 20 Flakiest Individual Tests:" | tee -a "$SUMMARY_FILE"
tail -n +2 "$RESULTS_CSV" | \
  grep ",failed," | \
  awk -F, '{print $4 "::" $5}' | \
  sort | uniq -c | sort -rn | head -20 | \
  awk '{printf "  %3d failures - %s\n", $1, $2}' | tee -a "$SUMMARY_FILE"
echo "" | tee -a "$SUMMARY_FILE"

# Analyze flakiness by branch
echo "📊 Failures by Branch:" | tee -a "$SUMMARY_FILE"
tail -n +2 "$RESULTS_CSV" | \
  grep ",failed," | \
  cut -d, -f3 | \
  sort | uniq -c | sort -rn | head -10 | \
  awk '{printf "  %3d failures - %s\n", $1, $2}' | tee -a "$SUMMARY_FILE"
echo "" | tee -a "$SUMMARY_FILE"

echo "💾 Results saved to:"
echo "  CSV Database: $RESULTS_CSV"
echo "  Summary: $SUMMARY_FILE"
echo ""
echo "📋 Next steps:"
echo "  1. Review $SUMMARY_FILE for top flaky tests"
echo "  2. Calculate per-test failure rates"
echo "  3. Create baseline report (dev-log/02.7.1-flakiness-baseline-report.md)"
