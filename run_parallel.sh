#!/bin/bash

# Function to handle SIGINT (Ctrl+C)
cleanup() {
    echo "Terminating all instances..."
    kill 0 # Send SIGTERM to all processes in the current process group
    exit
}

# Trap SIGINT and call the cleanup function
trap cleanup SIGINT

# Check if the number of instances is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 NUMBER_OF_INSTANCES"
    exit 1
fi

# Get the number of instances from the command line argument
NUM_INSTANCES=$1

# Path to the Ruby script
RUBY_SCRIPT="./parallel_update_embedding_ada2.rb"

# Launch the Ruby script in parallel
for (( i=0; i<$NUM_INSTANCES; i++ )); do
    ruby $RUBY_SCRIPT -i $i -t $NUM_INSTANCES &
done

# Wait for all background jobs to finish
wait
echo "All instances have finished."
