-- Offline host for the real plugin modules and Zeron design system.
require("@ds/tokens").setup()
local settings = ui.persist("settings", {safe=true, floating_autoplay=false, floating_interval=10, metadata=true, aspect=true, hide_nsfw=true, blur_nsfw=true})
local stored = ui.persist("stored", {})
local show = ui.state("show_panel", false)
local requests = ui.state("requests", 0)
local response = ui.state("response", "ok")
local listener = function() end
local notice = ui.state("notice", "")
local target = {open_tab=function() show:set(true) end}
local zeron = {
 settings=function() return settings:get() end,
 setting=function(key) return {get=function() return settings:get()[key] end,peek=function() return settings:peek()[key] end} end,
 store=function(key,default) return {peek=function() return stored:peek()[key] or default end,set=function(_,v) stored:set_key(key,v) end} end,
 on_setting=function(fn) listener=fn end,
 window=function() return {shown=true,active=true} end,
 context=function() return target end,
 toast=function(v) notice:set(v) end,
 open_url=function(v) notice:set(v) end,
}
local function row(id,rating)
 return {id=id,url=`https://cdn.nekosapi.com/{id}.webp`,rating=rating,tags={"sky"},artist_name="Fixture artist"}
end
local function request(url)
 requests:set(requests:peek()+1)
 ui.sleep(10):await()
 if response:peek()=="limited" then return {ok=false,status=429,headers={["retry-after"]="8"}} end
 if response:peek()=="empty" then return {ok=true,status=200,json={}} end
 return {ok=true,status=200,json={row(1,"safe"),row(2,"safe"),row(3,"suggestive"),row(4,"explicit")}}
end
local model=require("./slideshow")(zeron,request)
local exporter={busy=ui.state("save_busy",false),save=function() end}
local Controls=require("./player_panel")(zeron,model,exporter,function() notice:set("settings") end)
local Image=require("./image_panel")(zeron,model)
local function setting(key,value) settings:set_key(key,value); listener(key,value) end
ui.command {id="loaded",title="loaded",run=function() local image=model.current(); if image then model.loaded(image.url) end end}
ui.command {id="fast",title="fast",run=function() model.interval:set(1); model.changed() end}
ui.command {id="hide",title="hide",run=function() show:set(false) end}
ui.command {id="nsfw",title="nsfw",run=function() setting("safe",false); setting("enable_nsfw",true); setting("suggestive",true); setting("explicit",true) end}
ui.command {id="nsfw-off",title="nsfw-off",run=function() setting("enable_nsfw",false) end}
ui.command {id="defaults",title="defaults",run=function() setting("floating_autoplay",false); setting("floating_interval",20) end}
ui.command {id="limited",title="limited",run=function() response:set("limited"); model.command("refresh") end}
ui.command {id="empty",title="empty",run=function() response:set("empty"); model.command("refresh") end}
return ui.column {w_full=true,h_full=true,
 ui.text {function() return `requests={requests:get()}; index={model.state.index:get()}; count={model.state.images:len()}; playing={tostring(model.autoplay:get())}; seconds={model.interval:get()}` end},
 ui.text {notice},
 ui.row {w_full=true,grow=1,min_h=0,
  ui.div {grow=1,min_w=0,h_full=true,Controls(target)},
  ui.show(show,ui.div {w=320,h_full=true,Image {}}),
 },
}
