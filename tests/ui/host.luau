-- Offline host for the real plugin modules and Zeron design system.
require("@ds/tokens").setup()
local settings = ui.persist("settings", {safe=true, mode="single", floating_autoplay=false, floating_interval=10, metadata=true, aspect=true, hide_nsfw=true, blur_nsfw=true})
local stored = ui.persist("stored", {})
local show_gallery = ui.state("show_gallery", false)
local requests = ui.state("requests", 0)
local response = ui.state("response", "ok")
local last_url = ui.state("last_url", "")
local listener = function() end
local notice = ui.state("notice", "")
local zeron = {
 settings=function() return settings:get() end,
 setting=function(key) return {get=function() return settings:get()[key] end,peek=function() return settings:peek()[key] end} end,
 store=function(key,default) return {peek=function() return stored:peek()[key] or default end,set=function(_,v) stored:set_key(key,v) end} end,
 on_setting=function(fn) listener=fn end,
 window=function() return {shown=true,active=true} end,
 toast=function(v) notice:set(v) end,
 open_url=function(v) notice:set(v) end,
}
local function row(id,rating)
 return {id=id,url=`https://cdn.nekosapi.com/{id}.webp`,rating=rating,tags={"sky"},artist_name="Fixture artist"}
end
local function request(url)
 requests:set(requests:peek()+1)
 last_url:set(url)
 ui.sleep(10):await()
 if response:peek()=="timeout" then ui.sleep(30000):await() end
 if response:peek()=="limited" then return {ok=false,status=429,headers={["retry-after"]="8"}} end
 if response:peek()=="empty" then return {ok=true,status=200,json={}} end
 local base = if response:peek()=="duplicate" then 0 else (requests:peek()-1)*10
 local records={row(base+1,"safe"),row(base+2,"safe"),row(base+3,"suggestive"),row(base+4,"borderline"),row(base+5,"explicit")}
 return {ok=true,status=200,json=records}
end
local model=require("./slideshow")(zeron,request)
local exporter={busy=ui.state("save_busy",false),save=function(image,format) notice:set("export="..format) end}
local Controls=require("./player_panel")(zeron,model,exporter,function() notice:set("settings") end)
local Gallery=require("./gallery")(zeron,function() notice:set("settings") end,model,exporter)
local PictureInPicture=require("./image_pip")(zeron,model,function() notice:set("settings") end)
local previous=settings:peek()
ui.effect(function() local now=settings:get(); for key,value in now do if previous[key]~=value then listener(key,value) end end; previous=now end)
local function setting(key,value) settings:set_key(key,value) end
ui.command {id="loaded",title="loaded",run=function() local image=model.current(); if image then model.loaded(image.url) end end}
ui.command {id="fast",title="fast",run=function() model.interval:set(1); model.changed() end}
ui.command {id="aspect-off",title="aspect-off",run=function() setting("aspect",false) end}
ui.command {id="gallery",title="gallery",run=function() show_gallery:set(true) end}
ui.command {id="nsfw",title="nsfw",run=function() setting("safe",false); setting("enable_nsfw",true); setting("suggestive",true); setting("explicit",true) end}
ui.command {id="nsfw-off",title="nsfw-off",run=function() setting("enable_nsfw",false) end}
ui.command {id="defaults",title="defaults",run=function() setting("floating_autoplay",false); setting("floating_interval",20) end}
ui.command {id="limited",title="limited",run=function() response:set("limited"); model.command("refresh") end}
ui.command {id="duplicate",title="duplicate",run=function() response:set("duplicate"); model.state.load(true) end}
ui.command {id="pause",title="pause",run=function() model.autoplay:set(false) end}
ui.command {id="timeout",title="timeout",run=function() response:set("timeout"); model.command("refresh") end}
ui.command {id="empty",title="empty",run=function() response:set("empty"); model.command("refresh") end}
return ui.column {w_full=true,h_full=true,
 ui.text {function() return `requests={requests:get()}; index={model.state.index:get()}; count={model.state.images:len()}; playing={tostring(model.autoplay:get())}; seconds={model.interval:get()}; selected={if model.current() then model.current().id else "none"}` end},
 ui.text {notice},
 ui.text {last_url},
 ui.button {id="outside-pip", "Keep working", on_click=function() notice:set("working") end},
 ui.row {w_full=true,grow=1,min_h=0,
  ui.div {grow=1,min_w=0,h_full=true,Controls()},
  ui.show(show_gallery,ui.div {w=520,h_full=true,Gallery {}}),
 },
 PictureInPicture(),
}
