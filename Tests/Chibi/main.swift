import Foundation

for (body,phase,idle) in [("Stand",0,0),("Sit",0,1),("Focus",30,0)] {
    for (time,suffix) in [(9.8,""),(10.08,"Blink"),(10.22,"Gaze"),(11.2,"Gaze"),(12.24,"Blink"),(12.5,"")] {
        let pose=ChibiPose(phase:phase,time:time,elapsed:2,idlePose:idle,glances:true)
        assert(pose.imageName==body+suffix)
    }
    assert(ChibiPose(phase:phase,time:11.2,elapsed:2,idlePose:idle).imageName==body)
    assert(ChibiPose(phase:phase,time:11.2,elapsed:2,idlePose:idle,reduceMotion:true,glances:true).imageName==body)
}
assert(ChibiPose(phase:0,time:57.08,elapsed:2,glances:true).imageName=="StandBlink")
assert(ChibiPose(phase:30,time:108.2,elapsed:2,glances:true).imageName=="FocusGaze")
assert(ChibiPose(phase:20,time:11.2,elapsed:0.1,glances:true).imageName=="StandExpression0")
assert(ChibiPose(phase:31,time:11.2,elapsed:2,glances:true).imageName=="Rest")
assert(ChibiPose(phase:10,time:11.2,elapsed:0.2,glances:true).imageName=="DragRight")
print("PASS: neutral gaze follows a blink and returns through a blink; optional/reduced-motion behavior; repeat cycles; reaction, rest and dragging priorities")

for (phase, idle, prefix) in [(0, 0, "Stand"), (0, 1, "Sit"), (30, 0, "Focus"), (31, 0, "Rest")] {
    for expression in 0...3 {
        let pose = ChibiPose(phase: phase, time: 1, elapsed: 10, basePhase: phase, idlePose: idle, expression: expression, expressionActive: true)
        assert(pose.imageName == prefix + "Expression" + String(expression))
    }
}
assert(ChibiPose(phase: 10, time: 1, elapsed: 10, expression: 3, expressionActive: true).imageName == "DragRight")
print("PASS: speech preserves all four pose expressions and suspended drag silhouette")
