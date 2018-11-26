BanLister = BanLister or {}

BanLister.API = "" -- Provided BanLister Community Key
BanLister.MaxBans = 15 -- If the user has equal to or more recorded bans then this value, then the user will be kicked from the server.
BanLister.RangeBans = "month" -- "total" - "month" -- MaxBans Time period.
BanLister.KickHim = false -- if false, instead of kicking users for MaxBans a message will be sent to staff. If true a message won't be sent and the user will be kicked.
BanLister.KickReason = "Sorry %s but this server is protected by Ban Lister ensuring a safe community" -- %s = player name
BanLister.AdminMessage = "%s has %d bans in the past month recorded" -- %s = player name, %d 
BanLister.Debug = true -- turn to true to see debug info in console on player join
BanLister.allowedAdmins = { -- alert other ranks that may not be classed as Admin with CAMI admin mods.
	["moderator"] = true,
	["mod"] = true
}
--DO NOT MODIFY PAST THIS POINT--

function BanLister:BanHandler(steamid64, reason, length)
	HTTP({
		failed = function(e)
			print("[BanLister] API FAILED WITH STATUS: "..e)
		end,
		success = function(code, body, headers)
			print(code)
			print(body)
		end,
		method = "GET",
		url = "https://api.banlister.com/insert.php",
		parameters = {
			steamid = tostring(steamid64),
			reason = tostring(reason),
			length = tostring(length),
			key = BanLister.API,
			game_id = "4000" -- gmod id
		},
		type = "application/json"
	})
end

hook.Add("PlayerInitialSpawn", "BanLister.CheckForBans", function(ply)
	local steamid64 = ply:SteamID64()

	local s = BanLister.RangeBans == "month" and "retrieve-month" or "retrieve"
	local str = string.format("https://api.banlister.com/%s.php?i=1&api_key=%s&steamid=%s", s, BanLister.API, steamid64)
	print(str)
	http.Fetch(
		str,
		function(body, size, h, code)
			print(body)
			local data = util.JSONToTable(body)

			local count = istable(data) and #data or 0 -- use the length operator when its numerically indexed (i believe in this case this is). table.Count is good for sequentially

			if BanLister.Debug then
				if istable(data) then PrintTable(data) end
				print("Bans count: "..count)
			end

			if count <= BanLister.MaxBans then return end

			local name = ply.SteamName and ply:SteamName() or ply:Name()
			if BanLister.KickHim then
				ply:Kick(string.format(BanLister.KickReason, name))
			else
				for k,v in pairs(player.GetAll()) do
					if not v:IsAdmin() or not BanLister.allowedAdmins[v:GetUserGroup()] then continue end

					v:ChatAddText(Color(220, 200, 0), "[BanLister] ", color_white, string.format(BanLister.AdminMessage, name, count))
				end
			end
		end,
		function(e)
			print("[BanLister] API FAILED WITH STATUS: "..e)
		end
	)
end)

hook.Add("serverguard.PlayerBanned", "BanLister.ServerguardHandler", function(ply, length, reason)
	BanLister:BanHandler(ply:SteamID64(), reason, length)
end)

if ulx then
	hook.Add(ULib.HOOK_USER_BANNED, "BanLister.ULXHandler", function(steamid, t)
		local steamid64 = util.SteamIDTo64(steamid)
		local reason = t.reason or ""
		local length = t.time != 0 and math.floor((t.unban - t.time)/60) or 0

		BanLister:BanHandler(steamid64, reason, length)
	end)
end

hook.Add("FAdmin_StoreBan", "BanLister.FAdminHandler", function(steamid, _, length, reason)
	local steamid64 = util.SteamIDTo64(steamid)

	BanLister:BanHandler(steamid64, reason, length)
end)
