--!strict
--[[

	SecureWebhook.luau; Optimized lightweight proxied webhook use for studio.
	
	Extremely easy to change the proxy and customize the module.
	Default proxy url: https://webhook.lewisakura.moe/ 
		
	Rescripted the old version because the old version was a bit messy.
		
	v1.1.0 @LocalOneX
		
]]

export type webhook_body_schema = {
	content: string?,
	embeds: { 
		{ 
			title: string?, 
			description: string?, 
			url: string?, 
			color: number?, 
			fields: { { name: string, value: string, inline: boolean? } }?, 
			footer: { text: string, icon_url: string? }?, 
			thumbnail: { url: string }?, 
			image: { url: string }?, 
			author: { name: string, url: string?, icon_url: string? }? 
		} 
	}?,
	username: string?,
	avatar_url: string?,
	tts: boolean?
} 

local HttpService = game:GetService("HttpService")

--- Config
local DEBUG_ENABLED = false
local WEBHOOK_PROXY_URL = "webhook.lewisakura.moe"
local WEBHOOKS_API_URL = "https://discord.com/api/webhooks/"
local TEST_URL = WEBHOOKS_API_URL.."ID/TOKEN" 
local SUB_DOMAINS = {"ptb", "canary"}

local module = {}

--- Internal
 
-- I am addicted to this type of asserting LOL
local function _assertType(class: string)
	assert(typeof(class) == "string", `argument #1 expected type string, got {typeof(class)} instead`) 
	return function(input: any)
		assert(typeof(input) == typeof(class), `(expected type {class} got {typeof(input)} instead)`)
		return input
	end
end  
local function _optionalAssert(assertFn: (input: any) -> any)
	assert(typeof(assertFn) == "function", `argument #1 expected type function, got {typeof(assertFn)} instead`) 
	return function(input: any)
		if input == nil then
			return
		end
		return assertFn(input)
	end
end 
local function _assertTable(tbl: {[string]: (input: any) -> any})
	assert(typeof(tbl) == "table", `argument #1 expected type table, got {typeof(tbl)} instead`)
	for k, v in pairs(tbl) do
		if typeof(k) ~= "string" then
			error("string", 3)
		end
		if typeof(v) ~= "function" then
			error("table", 3)
		end
	end
	return function(input: any)
		assert(typeof(input) == "table", `(expected type table got {typeof(input)} instead)`)
		for k, assertFn in pairs(tbl) do
			assertFn(input[k])
		end
	end
end 
local function _assertSpecialArray(assertFn: (input: any) -> any)
	assert(typeof(assertFn) == "function", `argument #1 expected type function, got {typeof(assertFn)} instead`) 
	return function(input: any)
		assert(typeof(input) == "table", `(expected type table got {typeof(input)} instead)`)
		for i, v in ipairs(input) do
			assertFn(v)
		end
	end
end
local _assertString = _assertType("string")
local _assertBoolean = _assertType("boolean")
local _internalBodyAssert = _assertTable({
	content = _assertString,
	embeds = _optionalAssert(_assertSpecialArray(_assertTable({
		title = _optionalAssert(_assertString),
		description = _optionalAssert(_assertString),
		url = _optionalAssert(_assertString),
		color = _optionalAssert(_assertType("number")),
		fields = _optionalAssert(_assertSpecialArray(_assertTable({
			name = _assertString,
			value = _assertString,
			inline = _optionalAssert(_assertBoolean),
		}))),
		footer = _optionalAssert(_assertTable({
			text = _assertString, 
			icon_url = _optionalAssert(_assertString),
		})),
		thumbnail = _optionalAssert(_assertTable({url = _assertString})),
		image = _optionalAssert(_assertTable({url = _assertString})),
		author = _optionalAssert(_assertTable({
			name = _assertString, 
			url = _optionalAssert(_assertString), 
			icon_url = _optionalAssert(_assertString),
		})),
	}))),
	username = _optionalAssert(_assertString),
	avatar_url = _optionalAssert(_assertString),
	tts = _optionalAssert(_assertBoolean) 
})

--[[
	Fetch a webhooks token & server id details from the url. 
]]
local function _details(url: string)
	_assertString(url)
	
	if DEBUG_ENABLED then
		warn('webhook_url',url)
	end
	
	if url:find("http://") then
		url = url:gsub("http://", "https://")
	end 
	
	if DEBUG_ENABLED then
		warn('webhook_url2',url)
	end
	
	for _, domain in ipairs(SUB_DOMAINS) do
		domain ..= ".discord"
		if url:find(domain) then
			url = url:gsub(domain, "")
			break
		end
	end
	
	if DEBUG_ENABLED then
		warn('webhook_url3',url)
	end
	
	assert(url:find(WEBHOOKS_API_URL), "Invalid url")
	url = url:gsub(WEBHOOKS_API_URL, "")
	
	local SERVER_ID, WEBHOOK_TOKEN = table.unpack(url:split("/"))
	_assertString(SERVER_ID)
	_assertString(WEBHOOK_TOKEN)
	
	if DEBUG_ENABLED then
		warn(SERVER_ID, WEBHOOK_TOKEN)
	end
	return SERVER_ID, WEBHOOK_TOKEN
end

--[[
	Get the webhooks proxy url.
]]
local function _proxy(url: string, queue: boolean?)
	_assertString(url)
	_optionalAssert(_assertBoolean)(queue) 
	
	if url:find(WEBHOOK_PROXY_URL) then
		return url
	end
	
	local SERVER_ID, WEBHOOK_TOKEN = _details(url)
	local PROXY_URL = `https://{WEBHOOK_PROXY_URL}/api/webhooks/{SERVER_ID}/{WEBHOOK_TOKEN}{queue and "/queue" or ""}`
	
	if DEBUG_ENABLED then
		warn('proxy',PROXY_URL)
	end
	return PROXY_URL
end

--[[
	Post the webhook through the proxy api.
]]
local function _post(url: string, body: webhook_body_schema, queue: boolean?)
	_assertString(url)
	_internalBodyAssert(body)
	_optionalAssert(_assertBoolean)(queue)
	
	local success, encodedBody = pcall(HttpService.JSONEncode, HttpService, body)
	if not success then
		error(encodedBody, 3)
	end
	 
	local success, response = pcall(HttpService.RequestAsync, HttpService, {
		Url = _proxy(url, queue),
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json"
		},
		Body = encodedBody
	})
	
	if not success then
		error(response, 3)
	end 
	
	if DEBUG_ENABLED then
		warn(success, response)
	end
end

--- External

--[[
	Post the webhook through the proxy api.
]]
function module:Post(url: string, body: webhook_body_schema, queue: boolean?)
	return _post(url, body, queue)
end

--[[
	Post a string to the webhook.
]]
function module:PostContent(url: string, content: string, queue: boolean?)
	_assertString(content)
	
	local body = {content = content}
	return _post(url, body, queue)
end

setmetatable(module, {
	__newindex = function(self, k, v)
		error(`{k} is not a valid member of {tostring(module)}`, 3)
	end,
})
return module
