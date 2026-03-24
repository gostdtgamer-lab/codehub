#!/bin/bash

clear
echo "================================"
echo "        CODEHUB INSTALLER"
echo "================================"

echo "Updating server..."
apt update -y

echo "Installing basic tools..."
apt install curl wget git docker.io -y

echo "Setup completed!"

echo "Thanks for using CodeHub"
