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

local StudioRP = {}

function StudioRP.new(plugin: Plugin)
	local httpClient = HttpClient.new(URL)
	local self: self = setmetatable({
		["HttpClient"] = httpClient,
		["Plugin"] = plugin
	}, {__index = StudioRP})

	local mainActivity = Activity.new(DateTime.now())
		:SetLargeImage("studio_logo")
		:SetDetails(`Workspace: {gameName}`)
	local playtestActivity

	self._heartbeat = coroutine.create(function()
		local activity = self.Activity or mainActivity

		while true do
			if RunService:IsRunning() then
				playtestActivity = Activity.new(DateTime.now())
				playtestActivity:SetState("Testing")
				--:SetSmallImage("playtest_icon")
			elseif StudioService.ActiveScript then
				activity:SetState(`Editing {StudioService.ActiveScript.Name}`)
				--:SetSmallImage("") --TODO: Get script type and corresponding image key
			else
				activity:SetState("Developing")
			end
			if not RunService:IsRunning() then
				playtestActivity = nil
			end

			local activityToSet = playtestActivity or activity

			self:SetActivity(activityToSet)

			task.wait(1)
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

function StudioRP.SetActivity(self: self, activity: Activity.self): (boolean, string?)
	self.Activity = activity
	return pcall(self.HttpClient.Post, self.HttpClient, activity)
end

type self = typeof(
	setmetatable({} :: {
		["Activity"]: Activity.self?,
		["HttpClient"]: HttpClient.self,
		["Plugin"]: Plugin
	}, {__index = StudioRP})
)

return StudioRP
