do
	if plugin:GetAttribute("Running") then
		return
	end

	local HttpService = game:GetService("HttpService")
	local success, httpError = pcall(
		HttpService.PostAsync,
		HttpService,
		"https://google.com/",
		"")
	if not success
		and httpError:match("Http requests can only be executed by game server")
	then
		return
	end
end

plugin:SetAttribute("Running", true)

local StudioRP = require(script.StudioRP)

local studioRP = StudioRP.new(plugin)

plugin.Unloading:Once(function()
	studioRP:Cleanup()
end)
