#!/bin/bash

# Build script to identify and report errors
cd /Users/clevelandlewis/Desktop/Roots

echo "🧹 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/RootsApp-*

echo "🔨 Building iOS target..."
xcodebuild \
  -project RootsApp.xcodeproj \
  -scheme Roots \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  clean build \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee ios_build_fix.log

echo ""
echo "📋 Build errors:"
grep -A 3 "error:" ios_build_fix.log | head -50

echo ""
echo "⚠️  Build warnings:"
grep -A 2 "warning:" ios_build_fix.log | head -30

echo ""
if grep -q "BUILD SUCCEEDED" ios_build_fix.log; then
  echo "✅ Build succeeded!"
else
  echo "❌ Build failed. Check ios_build_fix.log for details."
fi
