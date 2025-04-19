#!/bin/bash
# Helper script to run a short benchmark test with different thread counts

echo "Running benchmark tests with different thread counts"
echo "===================================================="

# Build the benchmark executable
zig build benchmark

# Run benchmark with single thread
echo -e "\nSingle-Threaded Benchmark (1 thread):"
zig build benchmark -- --threads 1 --agents 2000 --iterations 50

# Run benchmark with 2 threads
echo -e "\nMulti-Threaded Benchmark (2 threads):"
zig build benchmark -- --threads 2 --agents 2000 --iterations 50

# Run benchmark with 4 threads 
echo -e "\nMulti-Threaded Benchmark (4 threads):"
zig build benchmark -- --threads 4 --agents 2000 --iterations 50

echo -e "\nBenchmark tests completed"