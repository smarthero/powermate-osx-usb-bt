-- =========================
-- Griffin PowerMate for Screen Studio
-- Edit Mode Only
-- =========================

local TARGET_APP_NAME = "Screen Studio"
local TARGET_BUNDLE_ID = nil -- optional: set this if you want stricter app matching

local holdActive = false
local didRotateWhilePressed = false
local actionTriggered = false

local tapTimer = nil
local TAP_DELAY = 0.18

local FINE_SCRUB_STEPS = 2
local COARSE_SCRUB_STEPS = 5

local DUPLICATE_WINDOW = 0.08
local lastEventObject = nil
local lastEventTime = 0

local function isTargetAppFrontmost()
	local app = hs.application.frontmostApplication()
	if not app then
		return false
	end

	if TARGET_BUNDLE_ID and app:bundleID() == TARGET_BUNDLE_ID then
		return true
	end

	return app:name() == TARGET_APP_NAME
end

local function showHUD(text)
	hs.alert.closeAll()
	hs.alert.show(text, 0.8)
end

local function sendKey(mods, key, count)
	count = count or 1
	for _ = 1, count do
		hs.eventtap.keyStroke(mods or {}, key, 0)
	end
end

local function sendSpacePressRelease()
	hs.eventtap.event.newKeyEvent({}, "space", true):post()
	hs.timer.usleep(20000)
	hs.eventtap.event.newKeyEvent({}, "space", false):post()
end

local function cancelTapTimer()
	if tapTimer then
		tapTimer:stop()
		tapTimer = nil
	end
end

local function resetPressState()
	cancelTapTimer()
	holdActive = false
	didRotateWhilePressed = false
	actionTriggered = false
end

local function isDuplicateEvent(object)
	local now = hs.timer.secondsSinceEpoch()

	if object == lastEventObject and (now - lastEventTime) < DUPLICATE_WINDOW then
		return true
	end

	lastEventObject = object
	lastEventTime = now
	return false
end

local function handlePowerMateEvent(name, object, userInfo)
	if not isTargetAppFrontmost() then
		return
	end

	-- Keep rotation responsive; only dedupe non-rotation events
	if object ~= "kPowermateKnobClockwise"
		and object ~= "kPowermateKnobCounterClockwise"
		and object ~= "kPowermateKnobPressedClockwise"
		and object ~= "kPowermateKnobPressedCounterClockwise" then

		if isDuplicateEvent(object) then
			return
		end
	end

	if object == "kPowermateKnobPress" then
		cancelTapTimer()
		holdActive = false
		didRotateWhilePressed = false
		actionTriggered = false

		-- Treat a lone knob press as a tap unless a hold/pressed-turn follows
		tapTimer = hs.timer.doAfter(TAP_DELAY, function()
			tapTimer = nil

			if not holdActive and not didRotateWhilePressed and not actionTriggered then
				sendSpacePressRelease()
				showHUD("Play / Pause")
			end
		end)

	elseif object == "kPowermateKnobPressed1Second"
		or object == "kPowermateKnobPressed2Second"
		or object == "kPowermateKnobPressed3Second"
		or object == "kPowermateKnobPressed4Second" then

		holdActive = true
		cancelTapTimer()

		if object == "kPowermateKnobPressed1Second" and not actionTriggered then
			sendKey({}, "c", 1)
			showHUD("Cut")
			actionTriggered = true
		end

	elseif object == "kPowermateKnobClockwise" then
		sendKey({}, "right", FINE_SCRUB_STEPS)

	elseif object == "kPowermateKnobCounterClockwise" then
		sendKey({}, "left", FINE_SCRUB_STEPS)

	elseif object == "kPowermateKnobPressedClockwise" then
		holdActive = true
		didRotateWhilePressed = true
		cancelTapTimer()
		sendKey({}, "right", COARSE_SCRUB_STEPS)

	elseif object == "kPowermateKnobPressedCounterClockwise" then
		holdActive = true
		didRotateWhilePressed = true
		cancelTapTimer()
		sendKey({}, "left", COARSE_SCRUB_STEPS)

	elseif object == "kPowermateKnobRelease" then
		resetPressState()
	end
end

powermate = hs.distributednotifications.new(
	handlePowerMateEvent,
	"kPowermateKnobNotification"
)

powermate:start()

-- Edit mode LED indicator
hs.distributednotifications.post(
	"kPowermateLEDNotification",
	"org.hammerspoon",
	{ fn = "kPowermateLEDLevel", level = 0.35 }
)

showHUD("PowerMate: Screen Studio Edit Mode")