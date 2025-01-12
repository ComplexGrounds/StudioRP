local HttpService = game:GetService("HttpService")

local HttpClient = {}

function HttpClient.new(url: string)
	if not url:lower():match("http[s]*://[a-zA-Z]+:%d+") then
		error("Pattern of passed URL is invalid! Example valid URL: \"http://localhost:1234/\"")
	end

	local success, err = pcall(HttpService.PostAsync, HttpService, "https://roblox.com/", "")
	if not success and err:match("Http requests can only be executed by game server") then
		error(err)
	end

	local self: self = setmetatable({
		["URL"] = url
	}, {__index = HttpClient})

	return self
end

function HttpClient.Cleanup(self: self): ()
	self.URL = nil
	setmetatable(self, nil)
end

function HttpClient.CloseConnection(self: self): ()
	pcall(HttpService.PostAsync, HttpService, self.URL, HttpService:JSONEncode({
		["requestType"] = "CLOSE"
	}), Enum.HttpContentType.ApplicationJson)

	self:Cleanup()
end

function HttpClient.Post(self: self, data: {any}): string
	if self._lastState == data.state then
		error("Repeated")
	end

	local response = HttpService:PostAsync(self.URL, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)

	if response then
		self._lastState = data.state
	end

	return response
end

export type self = typeof(
	setmetatable({} :: {["URL"]: string}, {__index = HttpClient})
)

return HttpClient
