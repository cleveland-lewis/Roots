#!/usr/bin/env bash
set -e

#######################################
# STEP 3 — Create BUSINESS SOURCE LICENSE (BUSL-1.1)
#######################################
cat > LICENSE << 'EOF'
Business Source License 1.1

Licensor: Cleveland Lewis
Licensed Work: Roots (this repository)
Change Date: 2029-01-01
Change License: Apache 2.0

Terms:
This license grants permission to copy, modify, and use the Licensed Work
for non-production, non-commercial purposes only.

You may not use the Licensed Work in a commercial offering, including but
not limited to: selling the software, publishing it on any app store,
hosting it as a service, sublicensing it, or using it to build competing
products.

You may fork or clone the Licensed Work for personal study, experimentation,
code review, or non-commercial research.

After the Change Date, the Licensed Work will switch to the Change License.

This license does not grant trademark rights, brand rights, or any other
intellectual property rights beyond those explicitly stated.
EOF

echo "LICENSE file written."

#######################################
# STEP 4 — Create .gitignore for Xcode / Swift
#######################################
cat > .gitignore << 'EOF'
# Xcode
DerivedData/
build/
xcuserdata/
*.xcuserstate
*.xcsettings
*.xccheckout

# Swift Package Manager
.swiftpm/
.build/

# Logs
*.log

# Fastlane
fastlane/report.xml
fastlane/screenshots/
fastlane/test_output/

# App artifacts
*.ipa
*.dSYM

# macOS Finder
.DS_Store
EOF

echo ".gitignore file written."

#######################################
# STEP 5 — Reset local git repo and push clean BUSL version
#######################################

rm -rf .git
echo "Local .git directory removed."

git init
git add .
git commit -m "Initial commit: Roots under Business Source License 1.1"
git branch -M main

git remote add origin git@github.com:YOUR_GITHUB_USERNAME/REPO_NAME.git

git push -u --force origin main

echo "Done. Clean BUSL-licensed repo pushed to GitHub."
