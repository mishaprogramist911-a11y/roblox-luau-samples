--!strict
--[[
	CoinPickup: a server-checked coin pickup.

	Any BasePart tagged "Coin" is a coin. The client only says
	"I touched this coin"; the server decides if that is true:
	- the request rate is limited per player
	- the argument must really be a tagged coin part
	- the character must be alive and close enough
	- a coin can be taken once until it respawns

	The client never sends an amount, so it cannot ask for extra coins.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerData = require(script.Parent.PlayerData)
local RateLimiter = require(script.Parent.RateLimiter)

local COIN_TAG = "Coin"
local COIN_VALUE = 1
local MAX_DISTANCE = 12 -- studs; a little slack for lag
local RESPAWN_SECONDS = 10

local remote = Instance.new("RemoteEvent")
remote.Name = "CollectCoin"
remote.Parent = ReplicatedStorage

local limiter = RateLimiter.new(5, 5)
local taken: { [BasePart]: boolean } = {}

local function rootOfLivingCharacter(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root
end

local function hideUntilRespawn(coin: BasePart)
	local transparency = coin.Transparency
	taken[coin] = true
	coin.Transparency = 1
	coin.CanTouch = false
	task.delay(RESPAWN_SECONDS, function()
		taken[coin] = nil
		if coin.Parent then
			coin.Transparency = transparency
			coin.CanTouch = true
		end
	end)
end

remote.OnServerEvent:Connect(function(player: Player, target: any)
	if not limiter:allow(player) then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("BasePart") then
		return
	end
	local coin = target :: BasePart
	if not CollectionService:HasTag(coin, COIN_TAG) or taken[coin] then
		return
	end
	local root = rootOfLivingCharacter(player)
	if not root or (root.Position - coin.Position).Magnitude > MAX_DISTANCE then
		return
	end
	if PlayerData.addCoins(player, COIN_VALUE) then
		hideUntilRespawn(coin)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	limiter:forget(player)
end)

PlayerData.start()
