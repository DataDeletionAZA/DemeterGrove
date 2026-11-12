#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
checks_dir="$(mktemp -d "${TMPDIR:-/tmp}/daygarden-ranch-checks.XXXXXX")"
trap 'rm -rf "$checks_dir"' EXIT
model=(Sources/EconomyBalance.swift Sources/PetDialogue.swift Sources/Model.swift Sources/Cooking.swift Sources/Progression.swift Sources/HabitProgress.swift Sources/ActionCounts.swift Sources/PotionSelection.swift Sources/SceneGeometry.swift Sources/ToastLifetime.swift Sources/CalendarDates.swift Sources/Recurrence.swift Sources/ReminderPlanner.swift Sources/AIConfiguration.swift Sources/AIPrompts.swift Sources/FocusRecords.swift Sources/Inventory.swift Sources/NatureCatalog.swift Sources/Ranch.swift Sources/Pond.swift Sources/Fishing.swift Sources/Expedition.swift Sources/Mining.swift Sources/AutoShop.swift Sources/FocusWorld.swift Sources/Forging.swift Sources/CraftRoll.swift Sources/FoodContent.swift Sources/ItemLore.swift)
xcrun swiftc -swift-version 5 -parse-as-library "${model[@]}" Sources/AIClient.swift Sources/Store.swift Tests/Store/support.swift Tests/Ranch/main.swift -o "$checks_dir/ranch" -framework AppKit -framework Combine -framework Carbon -framework UserNotifications -framework Security -framework LocalAuthentication
"$checks_dir/ranch"
