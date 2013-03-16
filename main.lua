#!/usr/bin/env lua5.1

local https = require "ssl.https"
local oauth = require "OAuth"
local ltn12 = require "ltn12"
local json = require "json"

local auth = require "auth"

local key = 'WM7KAW0YQdPnUqj9uYylQ'
local secret = 'fnFLHYO31jFu3hoO2AcmE5CKz0WiHb8fr8vWbMTDPM'

function readValues()
    local values = {}
    local f = io.open("values.txt", 'r')
    if not f then print "???" return nil end
    local n = 0
    for key, val in (f:read('*a')):gmatch("([%a-_]*):%s*([^\n]*)") do
        --print(string.format("%q %q", key, val))
        values[key] = val
        n = n + 1
    end
    --print(n)
    if n < 1 then
        return nil
    end
    return values
end

function writeValues(t)
    local f = io.open("values.txt", "w")
    for k, v in pairs(t) do
        f:write(tostring(k)..": "..tostring(v).."\n")
    end
    f:close()
end

local vals = readValues()
if not vals then
    print("Token not found")
    vals = auth.getValues(key, secret)
    if not vals then
        error "???"
    end
    writeValues(vals)
end

--print("Username: "..vals.screen_name)

local client = OAuth.new(key, secret, {
    RequestToken = "http://api.twitter.com/oauth/request_token", 
    AuthorizeUser = {"http://api.twitter.com/oauth/authorize", method = "GET"},
    AccessToken = "http://api.twitter.com/oauth/access_token"
}, {
    OAuthToken = vals.oauth_token,
    OAuthTokenSecret = vals.oauth_token_secret
})

local code, headers, status, body = client:PerformRequest('GET', 'https://api.twitter.com/1.1/statuses/home_timeline.json')
--print(body)
--print(code, status)
--print(unpack(headers))

function prettyPrint(k, t, d)
    local tabs = string.rep("\t", d)
    if type(t) == "table" then
        print(tabs..tostring(k).." = {")
        for k, v in pairs(t) do
            prettyPrint(k, v, d+1)
        end
        print(tabs.."}")
    else
        print(tabs..tostring(k).." = "..tostring(t))
    end
end

local tab = json.decode(body)

--prettyPrint("json.decode(body)", tab, 0)

function tag(name, args, children)
    local t = {}
    for k, v in pairs(args) do
        t[#t + 1] = string.format("%s=%q", tostring(k), tostring(v))
    end
    if not children then
        return string.format("<%s %s />", name, table.concat(t, " "))
    else
        if type(children) ~= "string" then
            children = table.concat(children, "\n")
        end
        --[[if type(children) ~= "string" then
            children = "\t"..table.concat(children, "\t\n")
        else
            children = "\t"..children:gsub("\n", "\t\n")
        end]] --TODO: working tabulator
        local t_s = table.concat(t, " ")
        return string.format("<%s%s>\n%s\n</%s>", name, t_s == "" and "" or (" "..t_s), children, name)
    end
end

local children = {}

children[1] = tag('title', {}, "Twitter Home Timeline")
children[2] = tag('link', {href="https://twitter.com"})

for k, v in pairs(tab) do
    children[#children+1] = tag('entry', {}, {
        tag('summary', {},
            v.text
        ),
        tag('author', {},
            tag('name', {},
                v.user.name
            )
        )
    })
end

local xml = '<?xml version="1.0" encoding="utf-8"?>' .. 
            tag('feed', {xmlns='http://www.w3.org/2005/Atom'}, children)

print(xml)

