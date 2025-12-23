#!/bin/bash

echo "════════════════════════════════════════════════════"
echo "  FIXING BINARY LOADING CRASH (0xfeedfacf)"
echo "════════════════════════════════════════════════════"
echo ""

echo "Step 1: Cleaning all build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/RootsApp-*
echo "✅ Derived data cleaned"

echo ""
echo "Step 2: Cleaning build folder..."
cd /Users/clevelandlewis/Desktop/Roots
xcodebuild clean -project RootsApp.xcodeproj -scheme Roots > /dev/null 2>&1
echo "✅ Build folder cleaned"

echo ""
echo "Step 3: Removing module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex/*
echo "✅ Module cache cleared"

echo ""
echo "════════════════════════════════════════════════════"
echo "  DONE - Now try these steps in Xcode:"
echo "════════════════════════════════════════════════════"
echo ""
echo "1. In Xcode: Product → Clean Build Folder (⌘⇧K)"
echo "2. Close Xcode completely"
echo "3. Reopen Xcode"
echo "4. Build and Run"
echo ""
echo "If still crashing, the issue is likely:"
echo "  - Incompatible deployment target"
echo "  - Missing framework/library"
echo "  - Corrupted Xcode installation"
echo ""
echo "════════════════════════════════════════════════════"

