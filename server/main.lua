--SERVER

doGen=true

bitser=require'lib.bitser'
sock=require'lib.sock'
--bump=require'lib.bump'

pld={}
hand={}
world={obj={},version=1}
--phy={o={}}
ip,port='*',1244 -- *-auto
local rand=love.math.random

local function ivr(x)
  x=x or 1
  world.version=world.version+x
end

function generateShit(obj,rx,ry,rw,rh,d)
  for i=1,d do
    local n=#obj+1
    local tbs=40
    local ths=160
    local off=(ths*0.5)-(tbs*0.5)
    local gx,gy = rand(0,rw)+rx , rand(0,rh)+ry
    local dropn=rand(1,3)
    obj[n] = { texture='tree_b' , x=gx+off , y=gy+off , w=tbs , h=tbs , linkTo=n+1, col=true , hp=100 , l='wood=3' }
    obj[n+1] = { texture='tree_t' , x=gx , y=gy , w=ths, h=ths , onTouch="love.graphics.setColor(0.5,0.5,0.5,0.5)" , onTop=true, nodel=true }
  end
end

function deleteWlinks(n)
  local obj=world.obj[n]
  if obj.linkTo then
    deleteWlinks(obj.linkTo)
  end
  table.remove(world.obj,n)
end

function love.load(arg)
  --phy.w=bump.newWorld(128)
  love.window.setMode(350,150)
  love.window.setTitle('SURV Server')
  love.window.setVSync(0)
  server = sock.newServer(ip,port)
  server:setSerialization(bitser.dumps, bitser.loads)
  server:on("me", function(data,client)
    local ind=#pld+1
    for i,v in ipairs(pld) do
      if data.name==v.name then
        ind=i
        break
      end
    end
    pld[ind]=data
    hand[ind]=client
  end)
  server:on("sendwr", function(data,client) 
    server:sendToAll("worldData",world.obj) 
  end)
  server:on("worldDataO", function(data) 
    if(data.version>world.version)then 
      world=data 
    end 
  end)
  server:on("connected", function(data,handr) --WIP
    for i,v in ipairs(pld) do
      if v.name==data then
        handr:disconnectNow()
        return
      end
    end
  end)
  server:on("set",function(data,p)
    if data then
      if not(type(data)=='number') then
        world.obj[data.i]=data.v
      else 
        deleteWlinks(data)
        --table.remove(world.obj,data)
      end
      world.version=world.version+2
    end
    server:sendToAll('setFin','setFin')
  end)
  server:enableCompression()
  
  if doGen then
    generateShit(world.obj,-3000,-3000,6000,6000,200) 
  end
end

function love.update(dt)
  udt=dt
  spd=dt/(1/60)
  server:update()
  server:sendToAll("players",pld)
  server:sendToAll("worldVersion",world.version)
  
  --it=0
  ---for i,v in ipairs(phy.o) do
    --phy.w:remove(v)
    --it=it+1
  --end
  --phy.o={}
  
  --local function addobj(x,y,w,h)
    --local id=#phy.o+1
    --phy.o[id]={}
    --phy.w:add(phy.o[id],x,y,w,h)
    --return phy.o[id]
  --end
  
  for i,v in ipairs(hand) do
    --local v2=pld[i]
    local state=v:getState()
    if state=="disconnected" then
      table.remove(hand,i)
      table.remove(pld,i)
    end
  end
  --for i,v in ipairs(world.obj) do
    --if v.col then
     -- addobj(v.x,v.y,v.w,v.h)
    --end
  --end
end

function love.draw()
  if not world.obj then world.obj={} world.version=world.version+1 end
  local nni=''
  for i,v in ipairs(pld) do
    nni=nni..v.name..'\n'
  end
  pcall(love.graphics.print,('server running! '..love.timer.getFPS()..' TPS/RAM '..math.floor(collectgarbage('count'))..'kb\nworld version:'..world.version..', '..#world.obj..' objects\n'..#pld..' player(s) connected:\n'..nni))
end

function love.errorhandler(msg)
  local Now = os.date('*t')
  love.window.showMessageBox('Server crashed!','LUA CRASH (time: '..Now.hour..':'..Now.min..')\nERROR:\n'..msg)
  love.event.quit()
end

function love.quit()
  server:destroy()
end

function baseDir()
  if love.filesystem.isFused() then
    return love.filesystem.getSourceBaseDirectory()
  else
    return love.filesystem.getSource()
  end
end

function love.keypressed(k)
  if k=='k' then
    local dir=baseDir()
    local file = io.open(dir.."/worldSave.lua", "w") 
    local t='return {'
    for i,v in ipairs(world.obj) do
      t=t..'{texture="'..v.texture..'",x='..v.x..',y='..v.y..',w='..v.w..',h='..v.h..'},\n'
    end
    t=t..'}'
    file:write(t)
    file:close()
    t=nil
  end
  if k=='l' then
    world.obj=require'worldSave'
    package.loaded.worldSave=nil
    world.version=world.version+2
  end
  --if k=='g' then 
    --generateShit(world.obj,-1500,-1500,3000,3000,200) 
    --ivr(2)
  --end
  if k=='v' then 
    if love.window.getVSync()==1 then
      love.window.setVSync(0) 
    else 
      love.window.setVSync(1)
    end
  end
end
