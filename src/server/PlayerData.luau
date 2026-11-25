--!strict
--[[
	PlayerData: loads and saves a small table of player stats.

	What it takes care of:
	- every DataStore call is wrapped in pcall and retried with a growing pause
	- if loading fails, the player is kicked and nothing is ever saved for them,
	  so a failed load can never overwrite real progress with zeros
	- saved data is checked against the template, so new fields get defaults
	  and broken values are dropped
	- saves on leave, on a timer, and when the server shuts down

	What it does not do: session locking (one player on two servers at once).
	For a large live game use a library built for that, such as ProfileStore.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_SECONDS = 120
local MAX_ATTEMPTS = 3

export type Data = {
	coins: number,
	wins: number,
}

local TEMPLATE: Data = {
	coins = 0,
	wins = 0,
}

local store = DataStoreService:GetDataStore(STORE_NAME)
local sessions: { [Player]: Data } = {}
local started = false

local PlayerData = {}

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- Runs `action` up to MAX_ATTEMPTS times, waiting 2, 4... seconds between tries.
local function attempt(action: () -> any): (boolean, any)
	local lastError: any = nil
	for try = 1, MAX_ATTEMPTS do
		local ok, result = pcall(action)
		if ok then
			return true, result
		end
		lastError = result
		if try < MAX_ATTEMPTS then
			task.wait(2 ^ try)
		end
	end
	return false, lastError
end

-- Builds clean data: template defaults, plus saved values of the right type.
local function reconcile(saved: any): Data
	local data: { [string]: any } = table.clone(TEMPLATE) :: any
	if type(saved) == "table" then
		for key, default in pairs(TEMPLATE :: { [string]: any }) do
			if type(saved[key]) == type(default) then
				data[key] = saved[key]
			end
		end
	end
	return data :: any
end

local function load(player: Player)
	local ok, result = attempt(function()
		return store:GetAsync(keyFor(player))
	end)
	if not ok then
		warn(`[PlayerData] load failed for {player.Name}: {result}`)
		player:Kick("Could not load your data. Please rejoin in a minute.")
		return
	end
	if player.Parent == nil then
		return -- the player left while the data was loading
	end
	sessions[player] = reconcile(result)
end

local function save(player: Player): boolean
	local data = sessions[player]
	if not data then
		return true -- never loaded, so there is nothing safe to write
	end
	local snapshot = table.clone(data)
	local ok, err = attempt(function()
		store:SetAsync(keyFor(player), snapshot, { player.UserId })
		return nil
	end)
	if not ok then
		warn(`[PlayerData] save failed for {player.Name}: {err}`)
	end
	return ok
end

-- Returns the live data table, or nil while it is still loading.
function PlayerData.get(player: Player): Data?
	return sessions[player]
end

-- Adds coins on the server. Returns false if the data is not loaded yet.
function PlayerData.addCoins(player: Player, amount: number): boolean
	local data = sessions[player]
	if not data or amount ~= amount or amount <= 0 then
		return false
	end
	data.coins += math.floor(amount)
	return true
end

-- Call once from a server Script.
function PlayerData.start()
	if started then
		return
	end
	started = true

	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		sessions[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in pairs(sessions) do
				task.spawn(save, player)
			end
		end
	end)

	-- On shutdown, save everyone at the same time and wait until all are done.
	game:BindToClose(function()
		local pending = 0
		for player in pairs(sessions) do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

return PlayerData
