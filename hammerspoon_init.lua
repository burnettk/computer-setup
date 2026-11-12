local log = hs.logger.new("hammerspoon_init_lua")

log.i("Initializing hammerspoon")

HYPER = { "ctrl", "shift", "alt", "cmd" }
ctrl_option_command = { "ctrl", "alt", "cmd" }

-- tell hammerspoon to automatically launch on login
hs.autoLaunch(true)

hs.loadSpoon("SpoonInstall")

spoon.SpoonInstall.repos.ShiftIt = {
	url = "https://github.com/peterklijn/hammerspoon-shiftit",
	desc = "ShiftIt spoon repository",
	branch = "master",
}

spoon.SpoonInstall:andUse("ShiftIt", { repo = "ShiftIt" })
spoon.ShiftIt:bindHotkeys({})

spoon.SpoonInstall:andUse("ReloadConfiguration", {})
spoon.ReloadConfiguration:bindHotkeys({
	reloadConfiguration = { ctrl_option_command, "r" },
})
spoon.SpoonInstall:andUse("Calendar", {})
-- spoon.SpoonInstall:andUse("HCalendar", {})
-- spoon.ReloadConfiguration:start()

-- Clipboard history limits. The upstream spoon persists the whole history to
-- hs.settings on every copy, so one giant copy (or a few screenshots) bloats it
-- until Hammerspoon falls over.
local CLIPBOARD_HISTORY_ENTRIES = 100
local CLIPBOARD_MAX_TEXT_CHARS = 10000 -- longer text is truncated before storing
local CLIPBOARD_MAX_IMAGE_BYTES = 1024 * 1024 -- larger images are not stored

local function truncateUtf8(text, maxChars)
	local ok, cut = pcall(utf8.offset, text, maxChars + 1)
	if ok and cut then
		return text:sub(1, cut - 1)
	end
	if ok then
		return text -- fewer than maxChars characters
	end
	return text:sub(1, maxChars) -- not valid utf8, fall back to bytes
end

-- https://www.hammerspoon.org/Spoons/ClipboardTool
function setUpClipboardTool()
	spoon.SpoonInstall:andUse("ClipboardTool", {})
	local ct = spoon.ClipboardTool
	ct.paste_on_select = true
	ct.show_in_menubar = false
	ct.hist_size = CLIPBOARD_HISTORY_ENTRIES
	-- the spoon's own max_size check pops a blocking dialog on every big copy
	-- (and its "copy partially" path can crash), so we cap sizes ourselves below
	ct.max_size = false

	-- defaults to 0.8, but that seems kind of often to check
	ct.frequency = 2

	local originalPasteboardToClipboard = ct.pasteboardToClipboard
	function ct:pasteboardToClipboard(itemType, item)
		if type(item) ~= "string" then
			return
		end
		if itemType == "image" then
			if #item > CLIPBOARD_MAX_IMAGE_BYTES then
				log.i("ClipboardTool: not storing image of " .. #item .. " bytes")
				return
			end
		elseif #item > CLIPBOARD_MAX_TEXT_CHARS then
			item = truncateUtf8(item, CLIPBOARD_MAX_TEXT_CHARS)
		end
		return originalPasteboardToClipboard(self, itemType, item)
	end

	-- start fresh on each load (also wipes any bloated history saved by older configs)
	ct:clearAll()

	ct:bindHotkeys({
		toggle_clipboard = { ctrl_option_command, "v" },
	})
	ct:start()
end

local HELP_TEXT = [[
Hammerspoon Hotkeys:

HYPER = Ctrl + Shift + Alt + Cmd
CtrlOptCmd = Ctrl + Alt + Cmd

--- General ---
CtrlOptCmd + r : Reload Hammerspoon Config
CtrlOptCmd + h : Toggle this help (Esc also closes)
HYPER + h      : Toggle this help (Esc also closes)
HYPER + 0      : Restart System
HYPER + r      : Toggle Display Mirroring

--- Applications & Tabs ---
HYPER + i : Switch to iTerm
HYPER + m : Switch to Mail (Chrome Tab 1)
HYPER + s : Switch to Slack (Chrome Tab 2)
HYPER + c : Switch to Calendar (Chrome Tab 4)
HYPER + k : Switch to Karma (Chrome Tab 5)
HYPER + b : Open Agile Board (Chrome Search)

--- Clipboard & Typing ---
CtrlOptCmd + v : Toggle Clipboard History
HYPER + delete : Clear Clipboard History
HYPER + v      : Clean clipboard text & paste
HYPER + d      : Type 'du -sh * | sort -h'
HYPER + e      : Type 'Use ASD-STE100 Simplified Technical English.'
HYPER + y      : Type 'sudo mysql --defaults-file=...'

--- Other ---
CtrlOptCmd + j : Run notification dismissal script
]]

-- Help overlay: stays up until toggled off (same hotkey) or Esc. State is reset
-- before anything that could fail, so repeated presses can never wedge it.
local helpAlertUUID = nil
local helpModal = hs.hotkey.modal.new()

local function hideHelp()
	local uuid = helpAlertUUID
	helpAlertUUID = nil
	helpModal:exit()
	if uuid then
		pcall(hs.alert.closeSpecific, uuid, 0)
	end
end

helpModal:bind({}, "escape", hideHelp)

function showHelp()
	if helpAlertUUID then
		hideHelp()
		return
	end
	-- a non-number duration means "show until explicitly closed"
	local ok, uuid = pcall(hs.alert.show, HELP_TEXT, {}, hs.screen.mainScreen(), true)
	if ok and uuid then
		helpAlertUUID = uuid
		helpModal:enter()
	else
		log.e("Could not display help alert: " .. tostring(uuid))
	end
end

-- Main

-- function from here:
-- https://msol.io/blog/tech/work-more-efficiently-on-your-mac-for-developers/

setUpClipboardTool()

-- use vimium's search tab feature (T) to find the first chrome tab matching the term "Agile Board"
hs.hotkey.bindSpec({ HYPER, "b" }, function()
	hs.notify.show("Hello World!", "Welcome to Agile Board", "")
	hs.application.launchOrFocus("Google Chrome")

	-- a random tab that will allow us to use vimium's search tab feature
	hs.eventtap.keyStroke("cmd", "5")

	hs.eventtap.keyStroke({}, "escape")
	hs.eventtap.keyStroke("shift", "t")

	hs.eventtap.keyStrokes("Agile Board")
	hs.timer.doAfter(0.1, function()
		hs.eventtap.keyStroke({}, "return")
	end)
end)

-- "paste" command and output without the extra unpretty stuff from the prompt
hs.hotkey.bindSpec({ HYPER, "v" }, function()
	hs.notify.show("Hello World!", "updating clipboard text for pasting command and output", "")
	local selectedText = hs.pasteboard.getContents()
	local updatedText = string.gsub(selectedText, ".*> ", "> ")
	hs.pasteboard.setContents(updatedText)
	-- why doAfter? https://githubmemory.com/repo/Hammerspoon/hammerspoon/issues/2889
	hs.timer.doAfter(0.5, function()
		hs.eventtap.keyStroke("cmd", "v")
	end)
	hs.notify.show("Hello World!", "doing it. updating clipboard text for pasting command and output", "")
end)

-- clear clipboard history (same call the chooser's "Clear history" item makes).
-- "delete" is the normal Mac delete/backspace key; "forwarddelete" is fn+delete
-- or the Del key on a full-size keyboard.
local function clearClipboardHistory()
	log.i("Clearing clipboard history")
	spoon.ClipboardTool:clearAll()
	hs.alert.show("Clipboard history cleared")
end
hs.hotkey.bindSpec({ HYPER, "delete" }, clearClipboardHistory)
hs.hotkey.bindSpec({ HYPER, "forwarddelete" }, clearClipboardHistory)

-- mail is in chrome tab 1
hs.hotkey.bindSpec({ HYPER, "m" }, function()
	hs.notify.show("Hello World!", "Welcome to mail", "")
	hs.application.launchOrFocus("Google Chrome")
	hs.eventtap.keyStroke("cmd", "1")
end)

-- slack is in chrome tab 2
hs.hotkey.bindSpec({ HYPER, "s" }, function()
	hs.notify.show("Hello World!", "Welcome to slack", "")
	hs.application.launchOrFocus("Google Chrome")
	hs.eventtap.keyStroke("cmd", "2")
end)

-- calendar is in chrome tab 4
hs.hotkey.bindSpec({ HYPER, "c" }, function()
	hs.notify.show("Hello World!", "Welcome to calendar", "")
	hs.application.launchOrFocus("Google Chrome")
	hs.eventtap.keyStroke("cmd", "4")
end)

-- karma is in chrome tab 5
hs.hotkey.bindSpec({ HYPER, "k" }, function()
	hs.notify.show("Hello World!", "Welcome to karma", "")
	hs.application.launchOrFocus("Google Chrome")
	hs.eventtap.keyStroke("cmd", "5")
end)

hs.hotkey.bindSpec({ HYPER, "i" }, function()
	hs.notify.show("Hello World!", "Welcome to iterm", "")
	hs.application.launchOrFocus("iTerm")
end)
hs.hotkey.bindSpec({ ctrl_option_command, "h" }, showHelp)

hs.hotkey.bindSpec({ HYPER, "h" }, showHelp)

-- mirror displays
hs.hotkey.bindSpec({ HYPER, "r" }, function()
	-- hs.screen.allScreens()[0].id
	local all_screens = hs.screen.allScreens()
	if #all_screens ~= 1 then
		hs.alert.show("More than one screen detected!\nNot in mirrored mode?")
		-- hs.alert.show(all_screens[1])
		-- hs.alert.show(all_screens[2])

		-- hs.screen.mirrorOf(all_screens[1], all_screens[2])
		-- 1 is the primary macbook screen
		if all_screens[2].mirrorOf(all_screens[2], all_screens[1]) then
			hs.alert.show("turned on mirroring")
		else
			hs.alert.show("failed to turn on mirroring")
		end
	else
		-- it doesn't make sense to me that you have to pass the screen twice (caller and param). feels like a bug. to investigate, see:
		-- https://www.hammerspoon.org/docs/hs.screen.html#mirrorOf
		-- https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/screen/libscreen.m#L1117
		if all_screens[1].mirrorStop(all_screens[1]) then
			hs.alert.show("successfully called mirrorStop")
		else
			hs.alert.show("failed when calling mirrorStop")
		end
		-- screen1.mirrorStop()
	end

	return

	-- local screen1 = hs.screen.primaryScreen()
	-- hs.alert.show(screen1.id)
	-- local screen2 = screen1.next()
	-- hs.alert.show("next")
	-- hs.alert.show(screen2.id)
	-- if screen1 == screen2 then
	--   screen1.mirrorStop()
	-- else
	--   screen1.mirrorOf(screen2)
	-- end
end)

-- macro to type the following: du -sh * | sort -h
hs.hotkey.bindSpec({ HYPER, "d" }, function()
	hs.eventtap.keyStrokes("du -sh * | sort -h")
end)

-- macro to tell agents to write plainly (ASD-STE100 = Simplified Technical English)
hs.hotkey.bindSpec({ HYPER, "e" }, function()
	hs.eventtap.keyStrokes("Use ASD-STE100 Simplified Technical English.")
end)

-- macro to type the following: mysql --defaults-file=/etc/mysql/myadmin.cnf
hs.hotkey.bindSpec({ HYPER, "y" }, function()
	hs.eventtap.keyStrokes("sudo mysql --defaults-file=/etc/mysql/myadmin.cnf")
end)

hs.hotkey.bindSpec({ ctrl_option_command, "j" }, function()
	successful_execute_result =
		os.execute(os.getenv("HOME") .. "/projects/github/computer-setup/respond_to_mac_notifications.js")

	-- i'm hoping os.execute returns a boolean like this
	if successful_execute_result then
		hs.notify.show("nailed it", "removed notification", "")
	else
		hs.notify.show("OH NO!", "DID NOT remove notification", "")
	end
end)

-- https://github.com/Hammerspoon/hammerspoon/issues/834 talks about keyboard shortcut to restart
hs.hotkey.bindSpec({ HYPER, "0" }, function()
	hs.caffeinate.restartSystem()
end)

hs.alert.show("Hammerspoon config loaded")
