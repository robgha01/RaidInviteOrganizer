-- Author      : Matthew Enthoven (Alias: Blacksen)

local sortMethod = "asc"
local currSortIndex = 0;
local displayingGuild = true;
local displayOnline = true;
local validSortCall;
local RIO_displayRanks = {true, true, true, true, true, true, true, true, true, true};
local RIO_ShowOffline = true;
local invitingParty = false;
local invitingRaid = false;
local raidMode = false;
local waitingOnRaidConversion = false;
local partyCount = 0;
local partySpots = 0;

local AcceptedList = {};
local PendingList = {};
local RejectList = {};
local NeedToInvite = {};
local TestInviteError = {};
local codeTimerActive = false;
local codewordString = "Invite";
local totalTimeNum = 0;
local absoluteGuildList = {};
local timerRunning = true;
local needToBeRaid = true;
local needToToggleRaid = true;
local notSetRaidDifficulty = true;
local thisHasLoaded = false;
local numChecked = 0;
RIO_DefaultInviteText = "Raid invites started! Whisper me %s for an invite!"

local RIO_ColorTable = {
	["DEATH KNIGHT"] = "C41F36",
	["DRUID"] = "FF7D0A",
	["HUNTER"] = "ABD473",
	["MAGE"] = "69CCF0",
	["PALADIN"] = "F58CBA",
	["PRIEST"] = "FFFFFF",
	["ROGUE"] = "FFF569",
	["SHAMAN"] = "2459FF",
	["WARLOCK"] = "9482C9",
	["WARRIOR"] = "C79C6E",
};

SLASH_RIO1 = "/rio";
SLASH_RIO2 = "/raidinviteorganizer";
SlashCmdList["RIO"] = function(msg)
	local cmd, arg = string.split(" ", msg, 2);
	cmd = cmd:lower()
	if cmd == "show" then
		RIOMain_Browser.showMainFrame();
	elseif cmd == "hide" then
		RIOMain_Browser.hideMainFrame()
	elseif cmd == "reset" then
		RIO_MainFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);
		RIO_MainFrame:SetScale(1);
		RIO_MainFrameScale = 1;
		RIO_ScaleInputThing:SetNumber(1);
		RIO_MainFrame:Hide()
		RIO_MainFrame:Show()
	elseif cmd == "" then
		print("|cFFFF0000Raid Invite Organizer|r:");
		print("prefix: /rio");
		print(" - show - shows the main frame")
		print(" - hide - hide the main frame")
		print(" - reset - resets the scale / position of the main frame")
	else
		print(""..msg.." is not a valid command for /rio");
	end
end

function RIOMain_Browser.showMainFrame()
	RIO_MainFrame:Show();
end

function RIOMain_Browser.hideMainFrame()
	RIO_MainFrame:Hide();
end

function RIO_EventHandler(self, event, ...)
	if event == "VARIABLES_LOADED" then
		RIO_MainFrameHeight = RIO_MainFrame:GetHeight()
		if RIO_InvText == nil or RIO_InvText == "" then
			RIO_InvText = RIO_DefaultInviteText;
		else
			local txt = strtrim(RIO_InvText)
			if string.find(txt, "%%s") == nil then
				txt = txt.." %s"
			end
			RIO_InvText = txt
		end

		_G["RIO_InviteTextEditBox"]:SetText(RIO_InvText);
		for ci=1, 10 do
			 _G["RIO_ShowRank"..ci]:SetChecked(RIO_displayRanksMaster[ci]);
		end
		RIO_displayRanks = RIO_displayRanksMaster;
		RIO_ShowOffline = RIO_ShowOfflineMaster;
		_G["RIO_ShowOfflineBox"]:SetChecked(RIO_ShowOfflineMaster);
		codewordString = RIO_CodeWordString;
		RIOMain_Browser.updateCodeWords();
		_G["RIO_CodeWordEditBox"]:SetText(RIO_CodeWordString);
		_G["RIO_NotifyWhenTimerDone"]:SetChecked(RIO_NotifyWhenDone);
		_G["RIO_OnlyGuildMembers"]:SetChecked(RIO_GuildWhispersOnly);
		_G["RIO_GuildMessageAtStart"]:SetChecked(RIO_SendGuildMsg);
		_G["RIO_AlwaysInviteListen"]:SetChecked(RIO_AlwaysOn);
		
		if RIO_AlwaysOn then
			RIOMain_Browser.loginCodewordStart()
		end
		
		RIO_ShowMinimapIconConfig:SetChecked(RIO_MinimapShow);
		if RIO_MinimapShow then
			RIO_Mod_MinimapButton_Reposition()
		else
			RIO_Mod_MinimapButton:Hide();
		end
		
		RIO_AutoSetDifficultyBox:SetChecked(RIO_AutoSetDifficulty);
		RIO_AutoSet25manBox:SetChecked(RIO_AutoSet25man)
		
		if RIO_AutoSetDifficulty then
			RIO_AutoSetDifficultyHeroicRadio:Enable();
			RIO_AutoSetDifficultyNormalRadio:Enable();
			if RIO_AutoDifficultySetting == 1 then
				RIO_AutoSetDifficultyNormalRadio:SetChecked(false);
				RIO_AutoSetDifficultyHeroicRadio:SetChecked(true);
			else
				RIO_AutoSetDifficultyNormalRadio:SetChecked(true);
				RIO_AutoSetDifficultyHeroicRadio:SetChecked(false);
			end	
		else
			_G["RIO_AutoSetDifficultyNormalRadioText"]:SetText("|cFF888888Normal|r");
			_G["RIO_AutoSetDifficultyHeroicRadioText"]:SetText("|cFF888888Heroic|r");
			RIO_AutoSetDifficultyHeroicRadio:Disable();
			RIO_AutoSetDifficultyNormalRadio:Disable();
		end
		
		
		RIO_AutoSetMasterLooter:SetChecked(RIO_MasterLooter)
		RIO_ScaleInputThing:SetNumber(RIO_MainFrameScale);
		RIO_MainFrame:SetScale(RIO_MainFrameScale);
		RIO_MainFrame:SetWidth(450)
		
	elseif event == "GUILD_ROSTER_UPDATE" then
		RIOMain_Browser.buildGuildList();
	elseif event == "CHAT_MSG_WHISPER" and codeTimerActive then
		local msg, author, theRest = ...;
		local inviteThem = false;
		if RIO_GuildWhispersOnly then
			if absoluteGuildList[author] then 
				inviteThem = RIOMain_Browser.checkFilters(msg);
			end
		else
			inviteThem = RIOMain_Browser.checkFilters(msg);
			
		end
		
		if inviteThem then
			InviteUnit(author);
			if NeedToInvite[author] and NeedToInvite[author] == 1 then 
				NeedToInvite[author] = 0;
				numToInvite = numToInvite - 1;
				TestInviteError[author] = 1;
			end
			if RIO_AutoSet25man then
				if needToToggleRaid then
					if GetNumRaidMembers() > 17 then
						needToToggleRaid = false;
						if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
							SetRaidDifficulty(4)
							notSetRaidDifficulty = false;
						else
							SetRaidDifficulty(2)
							notSetRaidDifficulty = false;
						end
					end
				end
			end
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		local msg = ...;
		if string.find(msg, string.gsub(ERR_ALREADY_IN_GROUP_S, "%%s", "(%%S+)")) then -- This person is already in a group
			local playerName = string.match(msg, string.gsub(ERR_ALREADY_IN_GROUP_S, "%%s", "(%%S+)"));
			TestInviteError[playerName] = 0;
			if (not ((PendingList[playerName] and PendingList[playerName] == 1) or (AcceptedList[playerName] and AcceptedList[playerName] == 1))) then -- Check to make sure this isn't a "repeat" invite
				RejectList[playerName] = 1;
				PendingList[playerName] = 0;
				AcceptedList[playerName] = 0;
				partySpots = partySpots + 1;
			end
		elseif string.find(msg, string.gsub(ERR_JOINED_GROUP_S, "%%s", "%%S+")) then -- Player joined group
			partyCount = partyCount + 1;
			local playerName = string.match(msg, string.gsub(ERR_JOINED_GROUP_S, "%%s", "(%%S+)"));
			AcceptedList[playerName] = 1;
			RejectList[playerName] = 0;
			PendingList[playerName] = 0;
			TestInviteError[playerName] = 0;
			
		elseif string.find(msg, string.gsub(ERR_LEFT_GROUP_S, "%%s", "%%S+")) then -- Player left group
			local playerName = string.match(msg, string.gsub(ERR_LEFT_GROUP_S, "%%s", "(%%S+)"));
			AcceptedList[playerName] = 0;
			RejectList[playerName] = 1;
			PendingList[playerName] = 0;
			TestInviteError[playerName] = 0;
		elseif string.find(msg, string.gsub(ERR_INVITE_PLAYER_S, "%%s", "%%S+")) then -- sent Valid Invitation
			local playerName = string.match(msg, string.gsub(ERR_INVITE_PLAYER_S, "%%s", "(%%S+)"));
			AcceptedList[playerName] = 0;
			RejectList[playerName] = 0;
			PendingList[playerName] = 1;
			TestInviteError[playerName] = 0;
		elseif string.find(msg, string.gsub(ERR_RAID_MEMBER_ADDED_S, "%%s", "%%S+")) then -- Player joined raid group
			local playerName = string.match(msg, string.gsub(ERR_RAID_MEMBER_ADDED_S, "%%s", "(%%S+)"));
			AcceptedList[playerName] = 1;
			RejectList[playerName] = 0;
			PendingList[playerName] = 0;
			TestInviteError[playerName] = 0;
		elseif string.find(msg, string.gsub(ERR_RAID_MEMBER_REMOVED_S, "%%s", "%%S+")) then -- Player left raid group
			local playerName = string.match(msg, string.gsub(ERR_RAID_MEMBER_REMOVED_S, "%%s", "(%%S+)"));
			AcceptedList[playerName] = 0;
			RejectList[playerName] = 1;
			PendingList[playerName] = 0;
			TestInviteError[playerName] = 0;
		elseif string.find(msg, string.gsub(ERR_BAD_PLAYER_NAME_S, "%%s", "%%S+")) then -- Player was not online
			local playerName = string.match(msg, string.gsub(ERR_BAD_PLAYER_NAME_S, "%%s", "(%%S+)"));
			partySpots = partySpots + 1;
			AcceptedList[playerName] = 0;
			RejectList[playerName] = 1;
			PendingList[playerName] = 0;
			TestInviteError[playerName] = 0;
		elseif string.find(msg, string.gsub(ERR_DECLINE_GROUP_S, "%%s", "%%S+")) then -- Player joined group
			partySpots = partySpots + 1;
			local playerName = string.match(msg, string.gsub(ERR_DECLINE_GROUP_S, "%%s", "(%%S+)"));
			AcceptedList[playerName] = 0;
			RejectList[playerName] = 1;
			PendingList[playerName] = 0;
			TestInviteError[playerName] = 0;
		elseif string.find(msg, ERR_LEFT_GROUP_YOU) or string.find(msg, ERR_RAID_YOU_LEFT) then -- Player left group
			AcceptedList = {};
			RejectList = {};
			PendingList = {};
			invitingParty = false;
			invitingRaid = false;
			NeedToInvite = {};
			RIO_MainFrame:SetScript("OnUpdate", nil);
			if codeTimerActive then
				RIOMain_Browser.toggleCodewordInvites()
			end
		end
		
		RIOMain_Browser.updateListing();
	end
end
	

function RIOMainFrame_OnLoad()
	RIO_MainFrame:SetScript("OnEvent", RIO_EventHandler);
	RIO_MainFrame:RegisterEvent("VARIABLES_LOADED");
	RIO_MainFrame:RegisterEvent("GUILD_ROSTER_UPDATE");
	RIO_MainFrame:RegisterEvent("CHAT_MSG_SYSTEM");
	RIO_MainFrame.TimeSinceLastUpdate = 0
	RIO_TabPage2.TimeSinceLastUpdate = 0
	local entry = CreateFrame("Button", "$parentEntry1", RIO_GuildMemberFrame, "RIO_GuildEntry"); -- Creates the first entry
	entry:SetID(1); -- Sets its id
	entry:SetPoint("TOPLEFT", 4, -28) --Sets its anchor
	entry:Show()
	for ci = 2, 20 do --Loops through to create more rows
		local entry = CreateFrame("Button", "$parentEntry"..ci, RIO_GuildMemberFrame, "RIO_GuildEntry");
		entry:SetID(ci);
		entry:SetPoint("TOP", "$parentEntry"..(ci-1), "BOTTOM") -- sets the anchor to the row above
		entry:Show()
	end
	
	_G["RIO_GuildMessageAtStartText"]:SetText("Send Guild Message at Start");
	_G["RIO_NotifyWhenTimerDoneText"]:SetText("Notify When Timer Ends");
	_G["RIO_OnlyGuildMembersText"]:SetText("Only Accept Whispers From Guild");
	_G["RIO_AlwaysInviteListenText"]:SetText("Start Codeword Invites at Login");
	_G["RIO_ShowOfflineBoxText"]:SetText("Show Offline");
	_G["RIO_ShowOfflineBox"]:SetChecked(RIO_ShowOffline);
end

function RIOMainFrame_OnShow()
	if displayingGuild then
		local numRanks = GuildControlGetNumRanks();
		for ci=1, 10 do
			if ci <= numRanks then
				_G["RIO_ShowRank"..ci]:Show();
				_G["RIO_ShowRank"..ci.."Text"]:SetText(GuildControlGetRankName(ci));
				_G["RIO_ShowRank"..ci]:SetChecked(RIO_displayRanks[ci]);
			else
				_G["RIO_ShowRank"..ci]:Hide();
			end
		end
		RIOMain_Browser.buildGuildList();
	end
end

-- Function: buildGuildList
-- Purpose: Builds data for listing guild members
function RIOMain_Browser.buildGuildList() 
	local numMembers = GetNumGuildMembers(true);
	RIO_totalGuildNumber = 0;
	RIO_FullGuildList = {};
	RIO_totalNumber = 0;
	absoluteGuildList = {};
	for ci=1, numMembers do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(ci);
		
		if name then
			absoluteGuildList[name] = 1;		
			local classReal = string.upper(class);
						
			local color = "";
			if RIO_ColorTable[classReal] then
				color = "|cFF" .. RIO_ColorTable[classReal];
			end
			
			if RIO_ShowOffline == true or online then
				if RIO_displayRanks[(rankIndex+1)] == true then
					RIO_totalGuildNumber = RIO_totalGuildNumber+1;
					table.insert(RIO_FullGuildList, {
								name,
								rank,
								rankIndex,
								color,
								online
							});
					thisHasLoaded = true;
				end
			end
		end
	end
	
	if RIO_totalGuildNumber > 20 then
		local newVal = RIO_totalGuildNumber-20;
		_G["RIO_SliderContainer"]:Show();
		_G["RIO_GuildSlider"]:SetValueStep(1);
		if RIO_totalGuildOffset > newVal then
			RIO_totalGuildOffset = newVal;
		else
			RIO_totalGuildOffset = _G["RIO_GuildSlider"]:GetValue();
		end
		_G["RIO_GuildSlider"]:SetMinMaxValues(0, newVal);
		_G["RIO_GuildSlider"]:SetValue(RIO_totalGuildOffset);
	else
		RIO_totalGuildOffset = 0;
		_G["RIO_SliderContainer"]:Hide();
		_G["RIO_GuildSlider"]:SetValue(RIO_totalGuildOffset);
	end
	
	if displayingGuild then
		validSortCall = false;
		RIOMain_Browser.sortTable(currSortIndex);
		RIOMain_Browser.updateListing();
	end
end

-- Function: updateListing
-- Purpose: Displays the data for the faux
--		scrolling table.
function RIOMain_Browser.updateListing() 
	for ci = 1, 20 do
		local theRow = RIO_FullGuildList[ci+RIO_totalGuildOffset];
		if theRow then
			_G["RIO_GuildMemberFrameEntry"..ci.."Name"]:SetText(theRow[4] .. theRow[1]);
			if theRow[5] then
				_G["RIO_GuildMemberFrameEntry"..ci.."Rank"]:SetText(theRow[2]);
			else
				_G["RIO_GuildMemberFrameEntry"..ci.."Rank"]:SetText(GRAY_FONT_COLOR_CODE .. theRow[2]);
			end
			_G["RIO_GuildMemberFrameEntry"..ci]:Show();
			local theName = theRow[1];
			if RIO_SelectedList[theName] and RIO_SelectedList[theName] == 1 then
				_G["RIO_GuildMemberFrameEntry"..ci.."Check"]:Show();
			else
				_G["RIO_GuildMemberFrameEntry"..ci.."Check"]:Hide();
			end
			
			local seen = true;
			if PendingList[theName] and PendingList[theName] == 1 then
				_G["RIO_GuildMemberFrameEntry"..ci.."Status"]:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting");
				seen = false;
			end
			
			if AcceptedList[theName] and AcceptedList[theName] == 1 then
				_G["RIO_GuildMemberFrameEntry"..ci.."Status"]:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready");
				seen = false;
			end
			
			if RejectList[theName] and RejectList[theName] == 1 then
				_G["RIO_GuildMemberFrameEntry"..ci.."Status"]:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady");
				seen = false;
			end
			
			if seen then
				_G["RIO_GuildMemberFrameEntry"..ci.."Status"]:SetTexture("");
			end
			
		else
			_G["RIO_GuildMemberFrameEntry"..ci]:Hide();
		end
	end
end


-- Function: sortTable
-- Input: Column Header to sort by
-- Purpose: Sorts the guild member listing table
--		so that it's easily viewable
function RIOMain_Browser.sortTable(id)
	if currSortIndex == id and validSortCall then -- if we're already sorting this one
		if sortMethod == "asc" then -- then switch the order
			sortMethod = "desc"
		else
			sortMethod = "asc"
		end
	elseif id then -- if we got a valid id
		currSortIndex = id -- then initialize our sort index
		sortMethod = "asc" -- and the order we're sorting in
	end
	
	if validSortCall == false then
		validSortCall = true;
	end
	
	if (id == 1) then -- Char Name sorting (alphabetically)
		table.sort(RIO_FullGuildList, function(v1, v2)
			if sortMethod == "desc" then
				return v1 and v1[1] > v2[1]
			else
				return v1 and v1[1] < v2[1]
			end
		end)
	elseif (id == 2) then -- Guild Rank sorting (numerically)
		table.sort(RIO_FullGuildList, function(v1, v2)
			if sortMethod == "desc" then
				return v1 and v1[3] > v2[3]
			else
				return v1 and v1[3] < v2[3]
			end
		end)
	elseif (id == 3) then
		if thisHasLoaded then
			table.sort(RIO_FullGuildList, function(v1, v2)
					if v1 == nil then return false end
					if v2 == nil then return true end
					if RIO_SelectedList[v1[1]] then
						if RIO_SelectedList[v2[1]] then
							return RIO_SelectedList[v1[1]] < RIO_SelectedList[v2[1]] 
						else
							return true
						end
					else
						return false
					end
			end)
		end
	end
end

function RIOMain_Browser.selectRow(rowNum)
	local theRow = RIO_FullGuildList[rowNum+RIO_totalGuildOffset];
	if theRow then
		local theName = theRow[1];
		if theName then
			if RIO_SelectedList[theName] and RIO_SelectedList[theName] == 1 then
				RIO_SelectedList[theName] = 0;
			else
				RIO_SelectedList[theName] = 1;
			end
		end
	end
	
	RIOMain_Browser.updateListing();
	
end

function RIOMain_Browser.rankBoxToggle(numID)
	local toggleCheck = _G["RIO_ShowRank"..numID]:GetChecked();
	if toggleCheck == nil then
		RIO_displayRanks[numID] = false;
		RIO_displayRanksMaster[numID] = false;
	elseif toggleCheck == 1 then
		RIO_displayRanks[numID] = true;
		RIO_displayRanksMaster[numID] = true;
	end
	RIOMain_Browser.buildGuildList();
end

function RIOMain_Browser.offlineBoxToggle()
	local toggleCheck = _G["RIO_ShowOfflineBox"]:GetChecked();
	if toggleCheck == nil then
		RIO_ShowOffline = false;
		RIO_ShowOfflineMaster = false;
	elseif toggleCheck == 1 then
		RIO_ShowOffline = true;
		RIO_ShowOfflineMaster = true;
	end
	RIOMain_Browser.buildGuildList();
end

function RIOMain_Browser.sliderButtonPushed(dir)
	local currValue = _G["RIO_GuildSlider"]:GetValue();
	if (dir == 1) and currValue > 0 then
		newVal = currValue-3;
		if newVal < 0 then
			newVal = 0;
		end
		_G["RIO_GuildSlider"]:SetValue(newVal);
	elseif (dir == 2) and (currValue < (RIO_totalGuildNumber-20)) then
		newVal = currValue+3;
		if newVal > (RIO_totalGuildNumber-20) then
			newVal = (RIO_totalGuildNumber-20);
		end
		_G["RIO_GuildSlider"]:SetValue(newVal);
	end
end

function RIOMain_Browser.quickScroll(self, delta)
	local currValue = _G["RIO_GuildSlider"]:GetValue();
	if (delta > 0) and currValue > 0 then
		newVal = currValue-1;
		if newVal < 0 then
			newVal = 0;
		end
		_G["RIO_GuildSlider"]:SetValue(newVal);
	elseif (delta < 0) and (currValue < (RIO_totalGuildNumber-20)) then
		newVal = currValue+1;
		if newVal > (RIO_totalGuildNumber-20) then
			newVal = (RIO_totalGuildNumber-20);
		end
		_G["RIO_GuildSlider"]:SetValue(newVal);
	end
end

function RIOMain_Browser.clearSelection()
	RIO_SelectedList = {};
	RIOMain_Browser.updateListing() 
end

function RIOMain_Browser.selectAll()
	RIO_SelectedList = {};
	local numMembers = GetNumGuildMembers(true);
	for ci=1, numMembers do
		local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName = GetGuildRosterInfo(ci);
		if RIO_ShowOffline == true or online then
			if RIO_displayRanks[(rankIndex+1)] == true then
				RIO_SelectedList[name] = 1;
			end
		end
	end
	RIOMain_Browser.updateListing() 
end

function RIOMain_Browser.sendMassGuildInvite()
	local playerName = UnitName("player");
	numToInvite = 0;
	NeedToInvite = {};
	invitingRaid = false;
	notSetRaidDifficulty = RIO_AutoSetDifficulty;
	numChecked = 0;
	for k,v in pairs(RIO_SelectedList) do
		if v == 1 then
			NeedToInvite[k] = 1;
			numToInvite = numToInvite + 1;
			numChecked = numChecked+1;
		end
	end
	if NeedToInvite[playerName] and NeedToInvite[playerName] == 1 then
		NeedToInvite[UnitName("player")] = 0;
		numToInvite = numToInvite - 1;
	end
	
	AcceptedList[UnitName("player")] = 1;
	PendingList = {};
	RejectList = {};
	
	if (# RIO_SelectedList) == 0 then
		RIOMain_Browser.updateListing();
	end
	
	-- TODO: Check for people already in group/raid
	
	
	if (GetNumPartyMembers() == 0 and (not (UnitInRaid("player")))) then -- If we're solo
		waitingOnRaidConversion = false;
		RIO_MainFrame:SetScript("OnUpdate", RIO_OnUpdate);
		partySpots = 4;
		partyCount = 0;
		invitingParty = true;
		invitingRaid = false;
		local loopIndex = 0;
		for k,v in pairs(NeedToInvite) do
			if v == 1 then
				InviteUnit(k);
				TestInviteError[k] = 1;
				partySpots = partySpots - 1;
				NeedToInvite[k] = 0;
				numToInvite = numToInvite - 1;
				if (loopIndex ==3) then
					break;
				end
				loopIndex = loopIndex + 1;
			end
		end
	elseif (UnitIsPartyLeader("player") and (not (UnitInRaid("player")))) then -- If we're in a party already and we ARE the party leader.
		invitingParty = false;
		invitingRaid = true;
		ConvertToRaid();
		if (RIO_AutoSet25man and (numChecked > 17)) then
			if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
				SetRaidDifficulty(4)
				notSetRaidDifficulty = false;
			else
				SetRaidDifficulty(2)
				notSetRaidDifficulty = false;
			end
		else
			if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
				SetRaidDifficulty(3)
				notSetRaidDifficulty = false;
			else
				SetRaidDifficulty(1)
				notSetRaidDifficulty = false;
			end
		end
		
		if RIO_MasterLooter then
			SetLootMethod("master", UnitName("player"));
		end
		RIOMain_Browser.sendMassGuildInviteRaid();
	elseif IsRaidOfficer() then
		invitingRaid = true;
		invitingParty = false;
		local expectedRaidSize = numChecked + GetNumRaidMembers()
		if (RIO_AutoSet25man and (expectedRaidSize > 17)) then
			if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
				SetRaidDifficulty(4)
				notSetRaidDifficulty = false;
			else
				SetRaidDifficulty(2)
				notSetRaidDifficulty = false;
			end
		else
			if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
				SetRaidDifficulty(3)
				notSetRaidDifficulty = false;
			else
				SetRaidDifficulty(1)
				notSetRaidDifficulty = false;
			end
		end
		RIOMain_Browser.sendMassGuildInviteRaid()
	end
	
	RIOMain_Browser.updateListing();
end

function RIOMain_Browser.sendMassGuildInviteRaid()
	if IsRaidOfficer() then
		waitingOnRaidConversion = false;
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM",RIOMain_Browser.SystemFilter)
		for k,v in pairs(NeedToInvite) do
			if v == 1 then
				InviteUnit(k);
				TestInviteError[k] = 1;
				NeedToInvite[k] = 0;
				numToInvite = numToInvite - 1;
				NeedToInvite[k] = 0;
			end
		end
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM",RIOMain_Browser.SystemFilter)
		
		RIO_MainFrame:SetScript("OnUpdate", RIO_OnExtendedUpdate);
	end
end


function RIO_OnUpdate(self, elapsed)
  self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
  if (self.TimeSinceLastUpdate > RIO_UpdateInterval) then
  	if invitingParty then
		if partyCount > 0 then
			ConvertToRaid();
			invitingRaid = true;
			invitingParty = false;
			raidMode = true;
			waitingOnRaidConversion = true;
			RIOMain_Browser.sendMassGuildInviteRaid();
			if (RIO_AutoSet25man and (numChecked > 17)) then
				if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
					SetRaidDifficulty(4)
					notSetRaidDifficulty = false;
				else
					SetRaidDifficulty(2)
					notSetRaidDifficulty = false;
				end
			else
				if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
					SetRaidDifficulty(3)
					notSetRaidDifficulty = false;
				else
					SetRaidDifficulty(1)
					notSetRaidDifficulty = false;
				end
			end
			
			if RIO_MasterLooter then
				SetLootMethod("master", UnitName("player"));
			end
		else
			if partySpots > 0 then
				local loopIndex = 0;
				local haveNotFound = true
				for k,v in pairs(NeedToInvite) do
					if v == 1 then
						InviteUnit(k);
						TestInviteError[k] = 1;
						NeedToInvite[k] = 0;
						numToInvite = numToInvite - 1;
						if (loopIndex == (partySpots-1)) then
							break;
						end
						loopIndex = loopIndex + 1;
					end
				end
				partySpots = 0;
			end
		end
	end
	
	if waitingOnRaidConversion then
		RIOMain_Browser.sendMassGuildInviteRaid();
	end
	
	if numToInvite == 0 and invitingRaid then
		RIO_MainFrame:SetScript("OnUpdate", nil);
		invitingParty = false;
		invitingRaid = false;
	end
    self.TimeSinceLastUpdate = 0;
  end
end

function RIOMain_Browser.SystemFilter(chatFrame, event, message)
	return true;
end

function RIO_OnExtendedUpdate(self, elapsed)
	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
	if (self.TimeSinceLastUpdate > RIO_UpdateIntervalExtended) then
		RIO_MainFrame:SetScript("OnUpdate", nil);
		for k,v in pairs(NeedToInvite) do
			if v == 0 then
				if TestInviteError[k] and TestInviteError[k] == 0 then
					RejectList[k] = 1;
					PendingList[k] = 0;
					AcceptedList[k] = 0;
				end
			end
		end
		self.TimeSinceLastUpdate = 0;
	end
end

function RIOMain_Browser.saveCodeWords()
	codewordString = _G["RIO_CodeWordEditBox"]:GetText()
	RIO_CodeWordString = codewordString;
	RIOMain_Browser.updateCodeWords()
end

function RIOMain_Browser.updateCodeWords()
	local swapString = gsub(codewordString, "\n", "\186");
	RIO_CodeWords = { strsplit("\186", swapString) }
end

function RIOMain_Browser.selectTab(mahID)
 -- Handle tab changes
end

function RIOMain_Browser.toggleCodewordInvites()
	if codeTimerActive then
		codeTimerActive = false;
		_G["RIO_ToggleCodewordInvites"]:SetText("Start Codeword Invitations");
		_G["RIO_TabPage2"]:SetScript("OnUpdate", nil);
		
		if RIO_NotifyWhenDone then
			for ci=1, 5 do
				print("|cFFFF0000Raid Invite Organizer:|r Codeword Invites Haulted");
			end
		end
		RIO_MainFrame:UnregisterEvent("CHAT_MSG_WHISPER");
	else
		
		RIOMain_Browser.saveCodeWords();
		RIOMain_Browser.buildGuildList();
		if # RIO_CodeWords == 0 then
			print("|cFFFF0000Cannot Start Automatic Invites|r - You haven't entered any codewords.");
		else
			codeTimerActive = true;
			
				
			if RIO_MasterLooter then
				SetLootMethod("master", UnitName("player"));
			end
			
			RIO_SecondsListener:ClearFocus();
			RIO_MinutesListener:ClearFocus();
			RIO_CodeWordEditBox:ClearFocus();
			_G["RIO_ToggleCodewordInvites"]:SetText("End Codeword Invitations");
			totalTimeNum = RIO_MinutesListener:GetNumber()*60;
			totalTimeNum = totalTimeNum + RIO_SecondsListener:GetNumber();
			if RIO_SendGuildMsg then
				local theMsgFormat = RIO_InvText
				local theMsg = "";
				for ci=1, (# RIO_CodeWords - 1) do
					if (ci == 1) then
						theMsg = theMsg .. "\"" .. RIO_CodeWords[ci] .. "\"";
					else
						theMsg = theMsg .. ", " .. "\"" .. RIO_CodeWords[ci] .. "\"";
					end
				end
				if (# RIO_CodeWords) > 2 then
					theMsg = theMsg .. ", or \"" .. RIO_CodeWords[# RIO_CodeWords] .. "\"";
				elseif (# RIO_CodeWords) == 2 then
					theMsg = theMsg .. " or \"" .. RIO_CodeWords[2] .. "\"";
				else
					theMsg = theMsg ..  RIO_CodeWords[1];
				end
				
				theMsg = format(theMsgFormat, theMsg);
				SendChatMessage(theMsg ,"GUILD" ,nil ,nil);
			end
			RIO_MainFrame:RegisterEvent("CHAT_MSG_WHISPER")
			notSetRaidDifficulty = RIO_AutoSetDifficulty;
			needToToggleRaid = true;
			timerRunning = false;
			if (GetNumPartyMembers() == 0 and (not (UnitInRaid("player")))) then
				needToBeRaid = true;
				_G["RIO_TabPage2"]:SetScript("OnUpdate", RIO_CodewordTimer);
			end
			if totalTimeNum > 0 then
				timerRunning = true;
				if RIO_SecondsListener:GetNumber() > 59 then
					RIO_SecondsListener:SetNumber(RIO_SecondsListener:GetNumber() - 60);
					RIO_MinutesListener:SetNumber(RIO_MinutesListener:GetNumber() + 1);
				end
				_G["RIO_TabPage2"]:SetScript("OnUpdate", RIO_CodewordTimer);
			end
			
		end
	end
end

function RIO_CodewordTimer(self, elapsed)
	self.TimeSinceLastUpdate = self.TimeSinceLastUpdate + elapsed;
	if (self.TimeSinceLastUpdate > 1) then
		if timerRunning then
			totalTimeNum = totalTimeNum-1;
			if totalTimeNum <= 0 then
				RIO_SecondsListener:SetNumber(0);
				RIO_MinutesListener:SetNumber(0);
				RIOMain_Browser.toggleCodewordInvites();
			else
				local dividebysixty = totalTimeNum/60;
				local minutes = math.floor(dividebysixty);
				local seconds = totalTimeNum-(minutes*60);
				RIO_SecondsListener:SetNumber(seconds);
				RIO_MinutesListener:SetNumber(minutes);
			end
		end
		if needToBeRaid then
			if GetNumPartyMembers() > 0 then
				ConvertToRaid();
				if notSetRaidDifficulty and RIO_AutoDifficultySetting == 1 then
					SetRaidDifficulty(3)
					notSetRaidDifficulty = false;
				else
					SetRaidDifficulty(1)
					notSetRaidDifficulty = false;
				end
				needToBeRaid = false;
				if (not timerRunning) then
					_G["RIO_TabPage2"]:SetScript("OnUpdate", nil);
				end
			end
		end
	self.TimeSinceLastUpdate = 0;
	end
end

function RIOMain_Browser.checkFilters(msg)
	msg = string.upper(msg);
	local numCodeWords = # RIO_CodeWords;
	for ci=1, numCodeWords do
		if string.find(msg, string.upper(RIO_CodeWords[ci])) then
			return true;
		end
	end
	return false;
end

function RIOMain_Browser.loginCodewordStart()
	codeTimerActive = true;
	RIOMain_Browser.saveCodeWords();
	RIOMain_Browser.buildGuildList();
	if # RIO_CodeWords == 0 then
		print("|cFFFF0000Cannot Start Automatic Invites|r - You haven't entered any codewords.");
	else
		codeTimerActive = true;
		_G["RIO_ToggleCodewordInvites"]:SetText("End Codeword Invitations");
		totalTimeNum = 0;
		RIO_MainFrame:RegisterEvent("CHAT_MSG_WHISPER")
		notSetRaidDifficulty = RIO_AutoSetDifficulty;
		needToToggleRaid = true;
		timerRunning = false;
		if (GetNumPartyMembers() == 0 and (not (UnitInRaid("player")))) then
			needToBeRaid = true;
			_G["RIO_TabPage2"]:SetScript("OnUpdate", RIO_CodewordTimer);
		end
	end
end


function RIO_Mod_MinimapButton_Reposition()
	RIO_Mod_MinimapButton:SetPoint("TOPLEFT","Minimap","TOPLEFT",52-(80*cos(RIO_MinimapPos)),(80*sin(RIO_MinimapPos))-52)
end

-- Only while the button is dragged this is called every frame
function RIO_Mod_MinimapButton_DraggingFrame_OnUpdate()

	local xpos,ypos = GetCursorPosition()
	local xmin,ymin = Minimap:GetLeft(), Minimap:GetBottom()

	xpos = xmin-xpos/UIParent:GetScale()+70 -- get coordinates as differences from the center of the minimap
	ypos = ypos/UIParent:GetScale()-ymin-70

	RIO_MinimapPos = math.deg(math.atan2(ypos,xpos)) -- save the degrees we are relative to the minimap center
	RIO_Mod_MinimapButton_Reposition() -- move the button
end

-- Put your code that you want on a minimap button click here.  arg1="LeftButton", "RightButton", etc
function RIO_Mod_MinimapButton_OnClick()
	if arg1 == "LeftButton" then
		if RIO_MainFrame:IsVisible() then
			RIO_MainFrame:Hide();
		else
			RIO_MainFrame:Show();
		end
	end
end

function RIO_Mod_MinimapButton_OnEnter(self)
	if (self.dragging) then
		return
	end
	GameTooltip:SetOwner(self or UIParent, "ANCHOR_LEFT")
	GameTooltip:SetText("Raid Invite Organiser");
end

function RIOMain_Browser.setScale()
	if RIO_ScaleInputThing:GetNumber() == 0 then
		RIO_ScaleInputThing:SetNumber(1);
		RIO_MainFrameScale = 1;
	elseif RIO_ScaleInputThing:GetNumber() < .4 then
		RIO_ScaleInputThing:SetNumber(.4);
		RIO_MainFrameScale = .4;
	elseif RIO_ScaleInputThing:GetNumber() > 2 then
		RIO_MainFrameScale = 2;
		RIO_ScaleInputThing:SetNumber(2);
	else
		RIO_MainFrameScale = RIO_ScaleInputThing:GetNumber();
	end
	
	RIO_MainFrame:SetScale(RIO_MainFrameScale);
	
	RIO_MainFrame:Hide()
	RIO_MainFrame:Show()
end
