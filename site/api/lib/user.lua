--[[
 Licensed to the Apache Software Foundation (ASF) under one or more
 contributor license agreements.  See the NOTICE file distributed with
 this work for additional information regarding copyright ownership.
 The ASF licenses this file to You under the Apache License, Version 2.0
 (the "License"); you may not use this file except in compliance with
 the License.  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
]]--
local JSON = require 'cjson'
local elastic = require 'lib/elastic'

-- Get user data from DB
function getUser(r, override)
    local ocookie = r:getcookie("ponymail")
    local usr = {}
    if override or (ocookie and #ocookie > 43) then
        local cookie, cid = r:unescape(ocookie or ""):match("([a-f0-9]+)==(.+)")
        if override or (cookie and #cookie >= 40 and cid) then
            local js = elastic.get('account', r:sha1(override or cid))
            if js and js.credentials and (override or (cookie == js.internal.cookie)) then
                login = {
                    credentials = {
                        email = js.credentials.email,
                        fullname = js.credentials.fullname,
                        uid = js.credentials.uid
                    },                    
                    cid = cid,
                    internal = {
                        cookie = cookie,
                        admin = js.internal.admin
                    },
                    preferences = js.preferences,
                }
                return login
            end
        end
    end
    return nil
end

-- Update or set up a new user
function updateUser(r, cid, data)
    local cookie = r:sha1(r.useragent_ip .. ':' .. (math.random(1,9999999)*os.time()) .. r:clock())
    
    -- Does this account exists? If so, grab the prefs first
    local prefs = nil
    local oaccount = getUser(r, cid)
    if oaccount and oaccount.preferences then
        prefs = oaccount.preferences
    end
    elastic.index(r, r:sha1(cid), 'account', JSON.encode{
        credentials = {
            uid = data.uid,
            email = data.email,
            fullname = data.fullname,
        },
        internal = {
            admin = data.admin,
            cookie = cookie
        },
        cid = cid,
        preferences = prefs
    })
    r:setcookie("ponymail",cookie .. "==" .. (cid))
end


-- Log out a user
function logoutUser(r, usr)
    if usr and usr.cid then
        local js = elastic.get('account', r:sha1(usr.cid))
        js.internal.cookie = 'nil'
        elastic.index(r, r:sha1(usr.cid), 'account', JSON.encode(js))
    end
    r:setcookie("ponymail", "----")
end


-- Save preferences
function savePreferences(r, usr)
    if usr and usr.cid then
        local js = elastic.get('account', r:sha1(usr.cid))
        js.preferences = usr.preferences
        elastic.index(r, r:sha1(usr.cid), 'account', JSON.encode(js))
    end
end

return {
    get = getUser,
    logout = logoutUser,
    save = savePreferences,
    update = updateUser
}