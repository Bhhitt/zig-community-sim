#!/bin/bash
# Helper script to build and run the Zig Community Simulation in text mode

zig build run -- --text "$@"