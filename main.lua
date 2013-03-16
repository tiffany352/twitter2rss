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
    if not args then args = {} end
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
        return string.format("<%s%s>%s</%s>", name, t_s == "" and "" or (" "..t_s), children, name)
    end
end

function convertDate(s)
    -- from Sat Mar 16 11:45:26 +0000 2013
    -- to 2013-03-16T11:45:26Z
    local args
    if s then
        local _, _, month_str, day, hour, minute, second, year = s:find("%w+ (%w+) (%d+) (%d+):(%d+):(%d+) %+%d+ (%d+)")
        local month = ({Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6, Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12})[month_str]
        --print(year, month, day, hour, minute, second)
        args = {year=year, month=month, day=day, hour=hour, minute=minute, second=second}
    end
    return os.date("%Y-%m-%dT%H-%M-%SZ", os.time(args))
end

function escapeHtml(...)
    s = table.concat{...}
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    --print(s)
    return s
end

function parseEntities(tweet, entities)
    local ops = {}
    local media = {}
    if entities.urls then
        for k, v in pairs(entities.urls) do
            ops[#ops+1] = {
                indices=v.indices,
                replacement=tag('a', {href=v.expanded_url, title=v.display_url}, v.display_url)
            }
        end
    end
    if entities.user_mentions then
        for k, v in pairs(entities.user_mentions) do
            ops[#ops+1] = {
                indices=v.indices,
                replacement=tag('a', {href="https://twitter.com/"..v.screen_name, title=v.name}, "@"..v.screen_name)
            }
        end
    end
    if entities.hashtags then
        for k,v in pairs(entities.hashtags) do
            ops[#ops+1] = {
                indices=v.indices,
                replacement=tag('a', {href="https://twitter.com/search?q="..v.text}, "#"..v.text)
            }
        end
    end
    if entities.media then
        for k,v in pairs(entities.media) do
            ops[#ops+1] = {
                indices=v.indices,
                replacement=tag('a', {href=v.exanded_url}, v.display_url)
            }
            media[#media+1] = v.media_url
        end
    end
    table.sort(ops, function(a,b) return a.indices[1] < b.indices[1] end)
    local offset = 0
    for i=1, #ops do
        local v = ops[i]
        tweet = tweet:sub(1, v.indices[1] + offset) .. v.replacement .. tweet:sub(v.indices[2] + offset + 1, -1)
        offset = offset + (#v.replacement - (v.indices[2]-v.indices[1]))
    end
    return tweet, media
end

local children = {}

children[1] = tag('title', {}, "Twitter Home Timeline")
children[2] = tag('link', {href="https://twitter.com"})
children[3] = tag('updated', {}, convertDate())

for k, v in pairs(tab) do
    local tweet, media = parseEntities(v.text, v.entities)
    children[#children+1] = tag('entry', {}, {
        tag('title', {},
            v.text
        ),
        tag('content', {type="html"}, {escapeHtml(
            tag('div', {}, {
                tag('a', {href="https://twitter.com/"..v.user.screen_name}, {
                    tag('img', {style='float:left', src=v.user.profile_image_url}),
                    v.user.name, 
                    tag('br'),
                    "@"..v.user.screen_name,
                }),
                v.user.protected and " - private" or "",
            }),
            tag('hr'),
            tweet,
            tag('br'),
            v.source
        )}),
        tag('author', {},
            tag('name', {},
                v.user.name .. " @" .. v.user.screen_name
            ),
            tag('link', {href="https://twitter.com/"..v.user.screen_name})
        ),
        tag('link', {href="https://twitter.com/"..v.user.screen_name.."/statuses/"..v.id_str}),
        tag('published', {},
            convertDate(v.created_at)
        ),
        tag('id', {},
            v.id_str
        )
    })
end

local xml = '<?xml version="1.0" encoding="utf-8"?>' .. 
            tag('feed', {xmlns='http://www.w3.org/2005/Atom'}, children)

print(xml)

