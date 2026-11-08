#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
checks_dir="$(mktemp -d "${TMPDIR:-/tmp}/daygarden-planting-checks.XXXXXX")"
trap 'rm -rf "$checks_dir"' EXIT
model=(Sources/EconomyBalance.swift Sources/PetDialogue.swift Sources/Model.swift Sources/Cooking.swift Sources/Progression.swift Sources/HabitProgress.swift Sources/ActionCounts.swift Sources/PotionSelection.swift Sources/SceneGeometry.swift Sources/ToastLifetime.swift Sources/CalendarDates.swift Sources/Recurrence.swift Sources/ReminderPlanner.swift Sources/AIConfiguration.swift Sources/AIPrompts.swift Sources/FocusRecords.swift Sources/Inventory.swift)
xcrun swiftc -swift-version 5 -parse-as-library "${model[@]}" Sources/AIClient.swift Sources/Store.swift Tests/Store/support.swift Tests/Planting/main.swift -o "$checks_dir/planting" -framework AppKit -framework Combine -framework Carbon -framework UserNotifications -framework Security -framework LocalAuthentication
"$checks_dir/planting"
