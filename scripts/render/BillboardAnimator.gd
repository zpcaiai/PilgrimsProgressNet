extends Node
## DEPRECATED / RETIRED. The cast are now real in-engine 3D bodies, so the old
## flat-billboard walk-bob animator is gone. Its role is filled by
## HumanoidAnimator (the bipedal walk cycle) and the shared shadow helpers in
## CharacterBillboard. This stub is kept only so any stale reference still
## resolves; nothing instantiates it. Safe to delete once no scene references it.
##
## Use HumanoidAnimator.find_in(root) / HumanoidAnimator.nudge() instead.
