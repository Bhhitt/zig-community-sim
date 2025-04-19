#!/bin/bash
# Helper script to run the benchmark with configurable thread count
# Usage: ./run_benchmark.sh [thread_count] [agent_count] [iteration_count]
# Example: ./run_benchmark.sh 4 5000 100

# Default values
THREAD_COUNT=${1:-4}
AGENT_COUNT=${2:-5000}
ITERATION_COUNT=${3:-100}

echo "Running benchmark with the following configuration:"
echo "==================================================="
echo "Threads: $THREAD_COUNT"
echo "Agents: $AGENT_COUNT"
echo "Iterations: $ITERATION_COUNT"
echo ""

# Build the benchmark executable
zig build benchmark

# Run benchmark with specified configuration
zig build benchmark -- --threads $THREAD_COUNT --agents $AGENT_COUNT --iterations $ITERATION_COUNT

echo ""
echo "Benchmark completed"
echo "Results saved in benchmark_results_${AGENT_COUNT}_${ITERATION_COUNT}_${THREAD_COUNT}.csv"