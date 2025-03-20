local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local StudioService = game:GetService("StudioService")

local classes = script.Parent.Classes

local Activity = require(classes.Activity)
local HttpClient = require(classes.HttpClient)

local URL = "http://localhost:7000/"

local gameName
do
	local success, name = pcall(function()
		return MarketplaceService:GetProductInfo(game.PlaceId).Name
	end)

	if success then
		gameName = name
	else
		gameName = game.Name
	end
end

local placeIcon = nil
if game.PlaceId ~= 0 then
	local success, response = pcall(function()
		-- TODO: Expand the HttpClient to cover Roblox GET web requests.
		-- Additionally, remove the hardcoding on this PATH once HttpClient is expanded.
		local url = `https://thumbnails.roproxy.com/v1/places/gameicons?placeIds={game.PlaceId}&returnPolicy=PlaceHolder&size=420x420&format=Webp&isCircular=false`
		return HttpService:JSONDecode(HttpService:GetAsync(url))
	end)

	if success and response and response.data and response.data[1] then
		placeIcon = response.data[1].imageUrl
	else
		warn("[StudioRP] Could not retrieve Place Icon! " .. tostring(response))
	end
end

local StudioRP = {}

function StudioRP.new(plugin: Plugin)
	local httpClient = HttpClient.new(URL)
	local self: self = setmetatable({
		["HttpClient"] = httpClient,
		["Plugin"] = plugin
	}, {__index = StudioRP})

	local mainActivity = Activity.new(DateTime.now())
		:SetLargeImage(placeIcon or "studio_logo")
		:SetDetails(`Workspace: {gameName}`)
		:SetSmallImage(placeIcon and "bordered_studio_logo")
	local playtestActivity

	self._heartbeat = coroutine.create(function()
		local activity = self.Activity or mainActivity

		local heartbeatTime = 1
		local heartbeatsSinceLastTimeChange = 0 -- needs a more concise name

		while true do
			task.wait(heartbeatTime)

			if RunService:IsRunning() then
				playtestActivity = Activity.new(DateTime.now())
					:SetLargeImage(placeIcon or "studio_logo")
					:SetState("Testing")
					:SetDetails(`Workspace: {gameName}`)
					:SetSmallImage(placeIcon and "bordered_studio_logo")

				plugin:SetSetting("LastPlaytestTime", math.round(tick()))
			elseif StudioService.ActiveScript then
				local activeScript: Script = StudioService.ActiveScript

				local state = "Editing %s (%d line"
				local _, lineCount = activeScript.Source:gsub("\n", "")

				if lineCount ~= 1 then
					state ..= "s"
				end
				state ..= ")"

				state = string.format(state, activeScript.Name, lineCount)

				activity:SetState(state)
				--:SetSmallImage("") --TODO: Get script type and corresponding image key
			else
				activity:SetState("Developing")
			end

			local wasPlaytesting
			do
				local lastPlaytestTime = plugin:GetSetting("LastPlaytestTime")

				if not RunService:IsRunning() then
					--TODO: This looks ugly.
					--ensure playtesting has ended
					-- before attempting to change activity
					if (tick() - (tonumber(lastPlaytestTime) or math.huge)) > (heartbeatTime * 2) then
						plugin:SetSetting("LastPlaytestTime", nil)
						wasPlaytesting = true
					elseif lastPlaytestTime then
						continue
					end

					playtestActivity = nil
				end
			end
			local activityToSet = playtestActivity or activity

			local startTime = tick()
			local success, message = self:SetActivity(activityToSet, wasPlaytesting)

			local deltaTime = tick() - startTime

			--plugin.Log(Enum.AnalyticsLogLevel.Debug, `Success: %s{message and '\nMessage: %s'}\nDelta Time: %.0f`, success, message, deltaTime)

			heartbeatsSinceLastTimeChange += 1
			if
				success
				and deltaTime > 2
				and heartbeatsSinceLastTimeChange > (75 / deltaTime)
			then
				heartbeatTime += 1
				heartbeatsSinceLastTimeChange = 0
			end

		end
	end)

	coroutine.resume(self._heartbeat)

	return self
end

function StudioRP.Cleanup(self: self)
	coroutine.close(self._heartbeat)
	self._heartbeat = nil
	self.HttpClient:CloseConnection()
	self.HttpClient = nil
end

function StudioRP.SetActivity(
	self: self,
	activity: Activity.self,
	wasPlaytesting: boolean
): (boolean, string?)
	self.Activity = activity
	return pcall(
		self.HttpClient.Post,
		self.HttpClient,
		activity,
		wasPlaytesting
	)
end

type self = typeof(
	setmetatable({} :: {
		["Activity"]: Activity.self?,
		["HttpClient"]: HttpClient.self,
		["Plugin"]: Plugin
	}, {__index = StudioRP})
)

return StudioRP
