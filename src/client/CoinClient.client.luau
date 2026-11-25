--!strict
-- Tells the server when the local character touches a coin.
-- All checks and the reward itself happen on the server (see CoinPickup).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local COIN_TAG = "Coin"
local RESEND_SECONDS = 0.5

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("CollectCoin") :: RemoteEvent
local lastSent: { [Instance]: number } = {}

local function watch(coin: Instance)
	if not coin:IsA("BasePart") then
		return
	end
	coin.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) then
			return
		end
		local now = os.clock()
		if now - (lastSent[coin] or 0) < RESEND_SECONDS then
			return
		end
		lastSent[coin] = now
		remote:FireServer(coin)
	end)
end

CollectionService:GetInstanceAddedSignal(COIN_TAG):Connect(watch)
CollectionService:GetInstanceRemovedSignal(COIN_TAG):Connect(function(coin)
	lastSent[coin] = nil
end)
for _, coin in CollectionService:GetTagged(COIN_TAG) do
	watch(coin)
end
