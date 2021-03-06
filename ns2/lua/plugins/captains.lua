Script.Load("lua/TGNSCommon.lua")

// Constants
local CHAT_TAG = "[CAPTAINS]"
local NOTE_MAX_LENGTH = 20
local PLAYNAME_MAX_LENGTH = 39

local CAPTAINSCOMMAND = "captains"
local NOTECOMMAND = "/note"
local NOTESCOMMAND = "/notes"
local CAPTAINCOMMAND = "/captain"

local allowNotesDisplay = true
local captain1id = -1
local captain2id = -1
local notes = {}
local captainsEnabled = false;

/******************************************
THESE SHOULD BE PUT IN A COMMON FILE
*******************************************/

local function isCommand(message, command)
	index, _, match = string.find(message, "(/%a+)")
	if index == 1 and match == command then
		return true
	end
	return false
end

local function getArgs(message, command)
	index, _, match, args = string.find(message, "(/%a+) (.*)")
	if index == 1 and match == command then
		return args
	end
	return nil
end

/******************************************
End common functions
*******************************************/

local function DisplayMessage(player, message)

	if type(message) == "string" then
		TGNS.SendChatMessage(player, message, CHAT_TAG)
	elseif type(message) == "table" then
		for _, m in pairs(message) do
			TGNS.SendChatMessage(player, m, CHAT_TAG)
		end
	end

end

local function DisplayMessageAll(message)

	if type(message) == "string" then
		chatMessage = string.sub(message, 1, kMaxChatLength)
		Server.SendNetworkMessage("Chat", BuildChatMessage(false, CHAT_TAG, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
	elseif type(message) == "table" then
		for _, m in pairs(message) do
			chatMessage = string.sub(m, 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, CHAT_TAG, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		end
	end

end

local function DisplayMessageConsole(player, message)
	if type(message) == "string" then
		TGNS.ConsolePrint(client, message, CHAT_TAG)
	elseif type(message) == "table" then
		for _, m in pairs(message) do
			TGNS.ConsolePrint(client, m, CHAT_TAG)
		end
	end
end

local function isCaptainsMode()
	return captainsEnabled
end

local function isCaptain(id)
	return captain1id == id or captain2id == id
end


local function StartCaptains()
	if DAK.config and DAK.config.tournamentmode then
		local tournamentMode = TGNS.IsTournamentMode()
		captainsEnabled = true;
		captain1id = -1
		captain2id = -1
		notes = {}
		DisplayMessageAll("Captains game starting.  Return to the readyroom to pick teams.")
		
		// TODO: Adjust server settings (time limit, others?)
			// server_cmd("mp_timelimit 45")
		if Server then
			Shared.ConsoleCommand("sv_tournamentmode 1 0 1")
		end
		//todo: make sure pubmode gets reset after a map change
		DAK.config.tournamentmode.kTournamentModePubMode = false
	end
end

local function makeCaptain(client, playerName, isChat)
	local DisplayMessageSelf
	if isChat then
		DisplayMessageSelf = DisplayMessage
	else
		DisplayMessageSelf = DisplayMessageConsole
	end
	local sourcePlayer = TGNS.GetPlayer(client)
	if isCaptainsMode() then
		if playerName then
			local targetPlayer = TGNS.GetPlayerMatching(playerName)
			if targetPlayer ~= nil then
				local targetClient = Server.GetOwner(targetPlayer)
				if targetClient ~= nil then
					local targetSteamId = TGNS.GetClientSteamId(targetClient)
					local targetName = string.sub(targetPlayer:GetName(), 1, PLAYNAME_MAX_LENGTH)
					if isCaptain(targetSteamId) then
						if captain1id  == targetSteamId then
							captain1id = -1
						elseif captain2id  == targetSteamId then
							captain2id = -1
						end
						DisplayMessageSelf(sourcePlayer, string.format("You have unset %s as a captain.", targetName))
						DisplayMessageAll(string.format("%s is no longer a captain.",  targetName))
					else
						if captain1id  == -1 then
							captain1id = targetSteamId
							Shared.ConsoleCommand(string.format("sv_setcaptain 1 %d", targetSteamId))
						elseif captain2id  == -1 then
							captain2id = targetSteamId
							Shared.ConsoleCommand(string.format("sv_setcaptain 2 %d", targetSteamId))
						end
						if isCaptain(targetSteamId) then
							DisplayMessageSelf(sourcePlayer, string.format("You have set %s as a captain.", targetName))
							DisplayMessageAll(string.format("%s is a captain.", targetName))
						else
							DisplayMessageSelf(sourcePlayer, "Two captains already exist.  You must first unset a captain.")
						end
					end
				end
			else
				DisplayMessageSelf(sourcePlayer, string.format("'%s' does not uniquely match a player.", playerName))
			end
		else
			DisplayMessageSelf(sourcePlayer, "Captains are:")
			local player1 = TGNS.GetPlayerMatchingSteamId(captain1id)
			local player2 = TGNS.GetPlayerMatchingSteamId(captain2id)
			if player1 then
				local name = string.sub(player1:GetName(), 1, PLAYNAME_MAX_LENGTH)
				DisplayMessageSelf(sourcePlayer, name)
			end
			if player2 then
				local name = string.sub(player2:GetName(), 1, PLAYNAME_MAX_LENGTH)
				DisplayMessageSelf(sourcePlayer, name)
			end
		end
	else
		DisplayMessageSelf(sourcePlayer, "Captains mode is not enabled.")
	end
end

local function buildTeamNotes(team)
	local notesTable = {}
	local playername
	local notesLine
	for _, player in pairs(TGNS.GetPlayerList()) do
		local steamId = TGNS.ClientAction(player, TGNS.GetClientSteamId)
		local playername = player:GetName()
		if player:GetTeamNumber() == team then
			if isCaptain(steamId) then
				playername = playername .. "*"
			end
			if notes[steamId] ~= nil and string.len(notes[steamId]) > 0 then
				local note = notes[steamId]
				notesLine = string.format("%s: %s\n", playername, note)
				table.insert(notesTable, notesLine)
			end
		end
	end
	return notesTable
end

local function showTeamNotes(player, isChat)
	local DisplayMessageSelf
	if isChat then
		DisplayMessageSelf = DisplayMessage
	else
		DisplayMessageSelf = DisplayMessageConsole
	end
	local team = player:GetTeamNumber()
	if isCaptainsMode() then
		if team ~= kTeamReadyRoom and team ~= kSpectatorIndex then
			local notes = buildTeamNotes(team)
			if notes ~= nil and #notes > 0 then
				if not isChat then
					DisplayMessageConsole(player, "")
				end
				DisplayMessageSelf(player, notes)
			else
				DisplayMessageSelf(player, "There are no notes set for your team.")
			end
		else
			DisplayMessageSelf(player, "You must be on a team to view the notes")
		end
	end
end

local function showNotesToTeam(team)
	if allowNotesDisplay == true and isCaptainsMode() then
		for _, player in pairs(TGNS.GetPlayerList()) do
			if player:GetTeamNumber() == team then
				showTeamNotes(player, true)
			end
		end
	end
end

local function assignNote(client, targetName, note, isChat)
	local DisplayMessageSelf
	if isChat then
		DisplayMessageSelf = DisplayMessage
	else
		DisplayMessageSelf = DisplayMessageConsole
	end
	if isCaptainsMode() then
		local sourcePlayer = TGNS.GetPlayer(client)
		local steamId = TGNS.GetClientSteamId(client)
		local team = sourcePlayer:GetTeamNumber()
		if sourcePlayer and team ~= kTeamReadyRoom and team ~= kSpectatorIndex then
			if targetName ~= nil then
				local targetPlayer = TGNS.GetPlayerMatching(targetName, team)
				if targetPlayer ~= nil then
					local targetSteamId = TGNS.ClientAction(targetPlayer, TGNS.GetClientSteamId)
					if steamId == targetSteamId or isCaptain(steamId) then
						if sourcePlayer:GetTeamNumber() == targetPlayer:GetTeamNumber() then
							if note ~= nil and string.len(note) > 0 then
								notes[targetSteamId] = string.sub(note, 1, NOTE_MAX_LENGTH)
							else
								notes[targetSteamId] = nil
							end
							if note == nil then
								note = "<Blank>"
							end
							DisplayMessage(targetPlayer, string.format("A note has been set for you: \"%s\"", note))
							DisplayMessageSelf(sourcePlayer, string.format("You set the note for %s to \"%s\"", targetPlayer:GetName(), note))
							showNotesToTeam(sourcePlayer:GetTeamNumber())
						else
							DisplayMessageSelf(sourcePlayer, "You may only set notes for players on your own team.")
						end
					else
						DisplayMessageSelf(sourcePlayer, "Only captains may set others' notes.  You may only set your own.")
					end
				else
					DisplayMessageSelf(sourcePlayer, string.format("'%s' does not uniquely match a teammate.  Try again.", targetName))
				end
			else
				DisplayMessageSelf(sourcePlayer, "You must enter a player name")
			end
		else
			DisplayMessageSelf(sourcePlayer, "You must be on a team to use this command.")
		end
	else
		DisplayMessageSelf(sourcePlayer, "Captains mode is not enabled.")
	end
end

local function do_roundbegin()
	if isCaptainsMode() then
		allowNotesDisplay = false
	end
end

local function do_roundend()
	if isCaptainsMode() then
		allowNotesDisplay = true
	end
end

local function onGameStateChange(self, state, currentstate)

	if state ~= currentstate then
		if state == kGameState.Started then
			do_roundbegin()
		elseif state == kGameState.Team1Won or
			   state == kGameState.Team2Won or
			   state == kGameState.Draw then
			do_roundend()
		end
	end
	
end
TGNS.RegisterEventHook("OnSetGameState", onGameStateChange)

local function client_putinserver(client)
	if isCaptainsMode() then
		DisplayMessage(TGNS.GetPlayer(client), "You're joining a captains game.  Please ASK FOR ORDERS when you join a team.")
	end
end

TGNS.RegisterEventHook("OnClientDelayedConnect", client_putinserver)

local function announceCaptDisc()
	DisplayMessageAll("A captain has left the server.")
end

local function client_disconnect(client)
	if client ~= nil and TGNS.VerifyClient(client) ~= nil then
		if isCaptainsMode() then
			local id = TGNS.GetClientSteamId(client)
			local team = TGNS.PlayerAction(client, TGNS.GetPlayerTeamNumber)
			if team ~= kTeamReadyRoom and team ~= kSpectatorIndex then
				for _, player in pairs(TGNS.GetPlayerList()) do
					if team == player:GetTeamNumber() and notes[id] ~= nil and string.len(notes[id]) > 0 then
						DisplayMessage(player, string.format("Teammate with note '%s' has left the server.", notes[id]))
					end
				end
			end
			notes[id] = nil // remove note from table
			if (captain1id == id) then
				captain1id = -1
				announceCaptDisc()
			elseif (captain2id == id) then
				captain2id = -1
				announceCaptDisc()
			end
		end
	end
end
TGNS.RegisterEventHook("OnClientDisconnect", client_disconnect)

local function CaptainsJoinTeam(self, player, newTeamNumber, force)
	if isCaptainsMode() then
		client = Server.GetOwner(player)
		if client ~= nil then
			local steamId = TGNS.GetClientSteamId(client)
			//if isCaptain(steamId) and newTeamNumber ~= kTeamReadyRoom and GetGamerules():GetGameState() == kGameState.PreGame then
			//	allowNotesDisplay = true
			//end
			if notes[steamId] ~= nil then
				notes[steamId] = nil // clear the note when a player changes teams
			end
		end
	end
end
TGNS.RegisterEventHook("OnTeamJoin", CaptainsJoinTeam)

local function OnCaptainsChatMessage(client, networkMessage)
	local message = networkMessage.message
	if isCaptainsMode() then
		if client then
			local steamId = TGNS.GetClientSteamId(client)
			if steamId and steamId ~= 0 then
				if isCommand(message, NOTECOMMAND) then
					local args = getArgs(message, NOTECOMMAND)
					if args ~= nil then
						local firstspace = string.find(args, " ")
						if firstspace ~= nil then
							local playername = string.sub(args, 1, firstspace - 1)
							local note = string.sub(args, firstspace + 1)
							assignNote(client, playername, note, true)
						end
					end
					return true
				elseif isCommand(message, CAPTAINCOMMAND) then
					local args = getArgs(message, CAPTAINCOMMAND)
					if TGNS.ClientCanRunCommand(client, CAPTAINCOMMAND) then
						makeCaptain(client, args, true)
					end
					return true
				elseif isCommand(message, NOTESCOMMAND) then
					showTeamNotes(TGNS.GetPlayer(client), true)
					return true
				end
			end
		end
	end
	return false
end
TGNS.RegisterNetworkMessageHook("ChatClient", OnCaptainsChatMessage, 5)

TGNS.RegisterCommandHook("Console_" .. CAPTAINSCOMMAND, StartCaptains, "configures the server for Captains Games", false)
TGNS.RegisterCommandHook("Console_" .. CAPTAINCOMMAND, function(client, playerName) if client ~= nil then makeCaptain(client, playerName) end end, "<playerName> Set/unset a team captain.", false)
TGNS.RegisterCommandHook("Console_" .. NOTESCOMMAND, function(client) if client ~= nil then TGNS.PlayerAction(client, showTeamNotes) end end, "Lists all notes assigned to your team", true)
TGNS.RegisterCommandHook("Console_" .. NOTECOMMAND, function(client, playerName, ...)  if client ~= nil then assignNote(client, playerName, StringConcatArgs(...)) end end, "<playerName> <note>, Set a note for yourself.  If you are a captain, you can set a note for a teammate", true)

/*
	// Mute team picking functionality in progress
	local function OnMutePlayer(client, networkMessage)
		local cancel = false
		if isCaptainsMode() then
			local steamId = TGNS.GetClientSteamId(client)
			if isCaptain(steamId) then
				clientIndex, isMuted = ParseMutePlayerMessage(networkMessage)
				for _, player in pairs(TGNS.GetPlayerList()) do
					if player:GetClientIndex() == clientIndex then
Print("found clicked player")
						local teamNumber
						if captain1id == steamId then
							teamNumber = kTeam1Index
						else
							teamNumber = kTeam2Index
						end
						
						if player:GetTeamNumber() == kTeamReadyRoom then
Print("player is in readyroom")
							local gamerules = GetGamerules()
							if gamerules then
								gamerules:JoinTeam(player, teamNumber)
							end
							
							DisplayMessageAll(string.format("%s was selected for %s.", player:GetName(), TGNS.GetTeamName(teamNumber)))
							Print("Selected")
						elseif player:GetTeamNumber() == teamNumber then
Print("player is on captain's team")
							local gamerules = GetGamerules()
							if gamerules then
								gamerules:JoinTeam(player, kTeamReadyRoom)
							end
							Print("Unselected")
						end
						break
					end
				end
				cancel = true
			end
		end
		return cancel
	end

	TGNS.RegisterNetworkMessageHook("MutePlayer", OnMutePlayer, 10)
*/