--!strict
local Connection = {}

local HttpService = game:GetService("HttpService")

local function get(port: number, path: string): string
	return HttpService:GetAsync(`http://127.0.0.1:{port}{path}`)
end

local function post(port: number, path: string, data: string): string
	return HttpService:RequestAsync({
		Url = `http://127.0.0.1:{port}{path}`,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["X-Folk-Client"] = "studio-plugin",
		},
		Body = data,
	}).Body
end

local function checkConnectionStatus(self: Connection)
	local connected, data = pcall(get, self._port, "/v1/events")
	if not connected then
		connected, data = pcall(get, self._port, "/v1/health")
	end
	if not connected then
		if self.onDisconnect then
			self.onDisconnect()
		end
		self:Destroy()
		return
	end

	if self.onDataRecieved then
		self.onDataRecieved(data :: string)
	end
	self._thread = task.delay(0.45, checkConnectionStatus, self)
end

local function Send(self: Connection, path: string, JSON: string): (boolean, string)
	local success, response = pcall(post, self._port, path, JSON)
	return success :: boolean, response :: string
end

local function Hello(self: Connection, payload: string): (boolean, string)
	local success, response = pcall(post, self._port, "/v1/studio/hello", payload)
	return success :: boolean, response :: string
end

local function Destroy(self: Connection)
	if self._thread then
		pcall(function()
			task.cancel(self._thread)
		end)
	end
	table.clear(self :: any)
end

export type Connection = {
	_port: number,
	_thread: thread,
	onDisconnect: () -> ()?,
	onDataRecieved: (data: string) -> ()?,
	Send: typeof(Send),
	Hello: typeof(Hello),
	Destroy: typeof(Destroy),
}

function Connection.probe(port: number): (boolean, string?)
	-- Only accept a real Folk host. Any other local service (e.g. something on 8080) must not match.
	local ok, data = pcall(get, port, "/v1/health")
	if not ok then
		return false, nil
	end
	local decodedOk, decoded = pcall(HttpService.JSONDecode, HttpService, data)
	if decodedOk and typeof(decoded) == "table" then
		local health = decoded :: any
		if health.ok == true and typeof(health.name) == "string" and string.find(health.name, "Reuploader", 1, true) then
			return true, data
		end
	end
	return false, nil
end

function Connection.scan(preferred: number): (number?, string?)
	local ports = { preferred, 38073 }
	for extra = 38070, 38090 do
		table.insert(ports, extra)
	end

	local seen = {}
	for _, port in ports do
		if seen[port] then
			continue
		end
		seen[port] = true
		local ok, data = Connection.probe(port)
		if ok then
			return port, data
		end
	end
	return nil, nil
end

function Connection.new(port: number): (Connection?, string?)
	local connected, data = Connection.probe(port)
	if not connected then
		return nil, nil
	end

	local self: Connection = {
		_port = port,
		Send = Send,
		Hello = Hello,
		Destroy = Destroy,
	} :: Connection
	self._thread = task.delay(0.45, checkConnectionStatus, self)

	return self, data
end

return Connection
