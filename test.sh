#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
checks_dir="$(mktemp -d "${TMPDIR:-/tmp}/demetergrove-checks.XXXXXX")"
trap 'rm -rf "$checks_dir"' EXIT
model=(Sources/Model.swift Sources/Cooking.swift Sources/Progression.swift Sources/HabitProgress.swift Sources/ActionCounts.swift Sources/PotionSelection.swift Sources/SceneGeometry.swift Sources/ToastLifetime.swift Sources/CalendarDates.swift Sources/Recurrence.swift Sources/ReminderPlanner.swift Sources/AIConfiguration.swift)
for suite in Model Kitchen Habits Scenes Feedback Recurrence; do
    file="Tests/$suite/main.swift"
    [[ "$suite" != Model ]] || file=Tests/main.swift
    xcrun swiftc -swift-version 5 "${model[@]}" "$file" -o "$checks_dir/$suite"
    "$checks_dir/$suite"
done
xcrun swiftc Sources/CalendarDates.swift Tests/Calendar/main.swift -o "$checks_dir/calendar"
"$checks_dir/calendar"
xcrun swiftc "${model[@]}" Sources/StatsPeriod.swift Sources/HabitDayState.swift Tests/Statistics/main.swift -o "$checks_dir/statistics"
"$checks_dir/statistics"
xcrun swiftc Sources/PetPlacement.swift Tests/Placement/main.swift -o "$checks_dir/placement"
"$checks_dir/placement"
xcrun swiftc Sources/WindowResize.swift Tests/Resize/main.swift -o "$checks_dir/resize" -framework SwiftUI -framework AppKit
"$checks_dir/resize"
xcrun swiftc -swift-version 5 Sources/ChibiAnimation.swift Tests/Chibi/main.swift -o "$checks_dir/chibi" -framework SwiftUI -framework AppKit
"$checks_dir/chibi"
xcrun swiftc Sources/SceneObject.swift Tests/SceneObjects/main.swift -o "$checks_dir/scenes" -framework AppKit -framework SwiftUI
"$checks_dir/scenes" Resources/Game
xcrun swiftc -swift-version 5 -parse-as-library "${model[@]}" Sources/Store.swift Tests/Store/support.swift Tests/Store/main.swift -o "$checks_dir/store" -framework AppKit -framework Combine -framework Carbon -framework UserNotifications
"$checks_dir/store"
xcrun swiftc -swift-version 5 -parse-as-library Sources/AIConfiguration.swift Sources/AIClient.swift Tests/AI/main.swift -o "$checks_dir/ai" -framework Security -framework LocalAuthentication
"$checks_dir/ai"
xcrun swiftc -swift-version 5 -typecheck Sources/*.swift -framework SwiftUI -framework AppKit -framework UserNotifications -framework Carbon -framework Charts
