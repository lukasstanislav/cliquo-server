#!/bin/bash

# checks that the docker is running
if ! docker info &> /dev/null; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

echo "Docker is running. Proceeding with the update..."