-- State variables and initialization for Flipper UI

local state = {}

state.currentFlipper = nil
state.bet = 1
state.guess = 'heads'
state.flipState = 'idle'
state.flipTimer = 0
state.flipResult = nil
state.win = false
state.FLIP_ANIM_SPEED = 0.1
state.flipAnimFrame = 1
state.flipAnimTimer = 0
state.squash = 1
state.squashTarget = 1
state.squashSpeed = 8
state.popTimer = 0
state.popDuration = 0.15
state.pendingPayout = nil
state.rewardText = nil
state.rewardTimer = 0
state.REWARD_DURATION = 1.0
state.targetFrame = 1
state.mouseX, state.mouseY = 0, 0
state.buttonLayout = {}

return state 