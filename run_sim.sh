#!/bin/bash
# Helper script to run the Zig Community Simulation with various options

# Default options
TEXT_MODE=true
MAX_STEPS=500
WIDTH=60
HEIGHT=30
BENCHMARK=false
BENCHMARK_AGENTS=1000
BENCHMARK_ITERATIONS=100

# Process command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --gui)
      TEXT_MODE=false
      shift
      ;;
    --steps=*)
      MAX_STEPS="${1#*=}"
      shift
      ;;
    --width=*)
      WIDTH="${1#*=}"
      shift
      ;;
    --height=*)
      HEIGHT="${1#*=}"
      shift
      ;;
    --benchmark)
      BENCHMARK=true
      shift
      ;;
    --agents=*)
      BENCHMARK_AGENTS="${1#*=}"
      shift
      ;;
    --iterations=*)
      BENCHMARK_ITERATIONS="${1#*=}"
      shift
      ;;
    --help)
      echo "Zig Community Simulation Helper Script"
      echo ""
      echo "Usage: ./run_sim.sh [options]"
      echo ""
      echo "Options:"
      echo "  --gui                  Try to run with SDL3 graphical interface"
      echo "  --steps=NUMBER         Set maximum simulation steps (default: 500)"
      echo "  --width=NUMBER         Set map width (default: 60)"
      echo "  --height=NUMBER        Set map height (default: 30)"
      echo "  --benchmark            Run in benchmark mode"
      echo "  --agents=NUMBER        Set number of agents for benchmark (default: 1000)"
      echo "  --iterations=NUMBER    Set number of iterations for benchmark (default: 100)"
      echo "  --help                 Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./run_sim.sh --steps=200                  Run 200 steps in text mode"
      echo "  ./run_sim.sh --gui --width=80 --height=40 Run with GUI and larger map"
      echo "  ./run_sim.sh --benchmark --agents=2000    Run benchmark with 2000 agents"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Build command
BUILD_CMD="zig build"

# Run command
if [ "$BENCHMARK" = true ]; then
  RUN_CMD="$BUILD_CMD run -- benchmark $BENCHMARK_AGENTS $BENCHMARK_ITERATIONS"
  echo "Running benchmark with $BENCHMARK_AGENTS agents for $BENCHMARK_ITERATIONS iterations..."
else
  OPTS=""
  
  # Add text/gui mode
  if [ "$TEXT_MODE" = true ]; then
    OPTS="$OPTS --text"
    echo "Running in text mode..."
  else
    OPTS="$OPTS --gui"
    echo "Attempting to run with GUI (requires SDL3)..."
  fi
  
  # Add steps
  OPTS="$OPTS --steps=$MAX_STEPS"
  
  # Add map dimensions
  OPTS="$OPTS --width=$WIDTH --height=$HEIGHT"
  
  RUN_CMD="$BUILD_CMD run -- $OPTS"
  echo "Running simulation with map size ${WIDTH}x${HEIGHT}, max steps: $MAX_STEPS"
fi

# Execute the command
echo "Command: $RUN_CMD"
eval $RUN_CMD

# Check if the map_state.txt file was created
if [ -f "map_state.txt" ]; then
  echo ""
  echo "Map state was saved to map_state.txt"
  echo "To view it: cat map_state.txt"
fi