#!/bin/bash
# Helper script to run benchmarks with different thread counts
# Usage: ./run_thread_benchmarks.sh [agent_count] [iteration_count]

# Default values
AGENT_COUNT=${1:-5000}
ITERATION_COUNT=${2:-100}

echo "Building benchmark executable..."
zig build -Doptimize=ReleaseFast

echo "Running benchmarks with different thread counts..."
echo "Agent count: $AGENT_COUNT"
echo "Iteration count: $ITERATION_COUNT"

# Run benchmarks with different thread counts
for THREAD_COUNT in 1 2 4 8; do
  echo ""
  echo "====================================="
  echo "Running benchmark with $THREAD_COUNT threads"
  echo "====================================="
  ./zig-out/bin/benchmark --threads $THREAD_COUNT --agents $AGENT_COUNT --iterations $ITERATION_COUNT
  echo ""
done

echo "All benchmarks completed."
echo "Results saved to benchmark_results_*.csv files."