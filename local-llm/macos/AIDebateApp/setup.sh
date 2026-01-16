#!/bin/bash

echo "🚀 Setting up AI Debate App with Gemma..."
echo ""

# Create directories
mkdir -p ~/models
mkdir -p Sources/AIDebateApp

echo "📦 Installing Homebrew dependencies..."
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Python if needed for model download
if ! command -v python3 &> /dev/null; then
    echo "Installing Python..."
    brew install python
fi

echo ""
echo "📥 Downloading Gemma model..."
echo "This will download Gemma 2B IT model (~5GB)"
echo ""

# Install huggingface-cli
pip3 install huggingface-hub --quiet

# Download Gemma model
echo "Downloading to ~/models/gemma-2b-it..."
huggingface-cli download google/gemma-2b-it --local-dir ~/models/gemma-2b-it --local-dir-use-symlinks False

echo ""
echo "✅ Model downloaded successfully!"
echo ""
echo "📝 Next steps:"
echo "1. Open the project in Xcode: open AIDebateApp"
echo "2. Wait for SPM to resolve dependencies"
echo "3. Build and run (Cmd+R)"
echo ""
echo "⚙️  Model location: ~/models/gemma-2b-it"
echo ""

