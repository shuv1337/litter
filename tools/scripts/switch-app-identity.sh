#!/usr/bin/env bash
# DEPRECATED: This script is no longer functional after the Litter → Shitter rebrand.
#
# The application now uses fixed identifiers:
#   - iOS:     io.latitudes.shitter (main) / io.latitudes.shitter.remote (remote-only)
#   - Android: io.latitudes.shitter.android
#
# If you need to modify bundle IDs or package names for local development:
#   1. Edit apps/ios/project.yml directly and regenerate with xcodegen
#   2. Edit apps/android/app/build.gradle.kts directly
#
# For more information, see: docs/ios/quickstart.md and apps/android/README.md

cat >&2 <<'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                              SCRIPT DEPRECATED                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  switch-app-identity.sh is no longer supported after the Litter → Shitter   ║
║  rebrand. The app now uses fixed identifiers:                                ║
║                                                                              ║
║    iOS:     io.latitudes.shitter / io.latitudes.shitter.remote               ║
║    Android: io.latitudes.shitter.android                                     ║
║                                                                              ║
║  To modify identifiers for local development:                                ║
║    • iOS: Edit apps/ios/project.yml, then run:                               ║
║           xcodegen generate --spec apps/ios/project.yml                      ║
║    • Android: Edit apps/android/app/build.gradle.kts                         ║
║                                                                              ║
║  See docs/ios/quickstart.md and apps/android/README.md for details.          ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF

exit 1
