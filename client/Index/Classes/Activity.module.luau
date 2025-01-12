local Activity = {}

function Activity.new(now: DateTime)
	local self = setmetatable({
		["startTimestamp"] = now.UnixTimestampMillis
	}, {__index = Activity})

	return self
end

function Activity.SetDetails(self: self, details: string)
	self.details = details

	return self
end

function Activity.SetLargeImage(self: self, key: string)
	self.largeImageKey = key

	return self
end

function Activity.SetState(self: self, state: string)
	self.state = state

	return self
end

function Activity.SetSmallImage(self: self, key: string)
	self.smallImageKey = key

	return self
end

export type self = typeof(
	setmetatable({} :: {
		startTimestamp: number
	}, {__index = Activity})
)

return Activity
