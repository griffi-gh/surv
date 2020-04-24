--CLIENT

bitser=require'lib.bitser'
sock=require'lib.sock'
Camera=require'lib.camera'
rand=love.math.random
ni=love.graphics.newImage
local rng='player'..rand(1000,9999) 

IP='localhost'
NICKNAME=rng --player1583

local function sett()
  world={obj={},version=0}
  me={name=NICKNAME,x=rand(64)-32,y=rand(64)-32,texture='player'}
  meRef=nil
  pl_speed=3
  players={}
  serverWver=world.version+1
end
sett()

textures={
  player=ni('player.png'),
  box=ni('box.jpg'),
  tree_t=ni('tree_top.png'),
  tree_b=ni('tree_bottom.png')
}
delta=0

function aabb(x1,y1,w1,h1,x2,y2,w2,h2,ext)
  local vcol,hcol
  if x1+w1>x2 and x1<x2+w2 then hcol=true end
  if y1+h1>y2 and y1<y2+h2 then vcol=true end
  if ext then
    return hcol,vcol
  else
    return (hcol and vcol)
  end
end

function connect(ip,port)
  port=port or 1244
  client = sock.newClient(ip,port)
  client:setSerialization(bitser.dumps, bitser.loads)
  client:on("players", function(data)
    players = data
  end)
  client:on("worldVersion", function(data)
    serverWver=data
  end)
  client:on("worldData", function(data)
    world.obj=data
    world.version=serverWver
    worldWait=false
  end)
  client:on("syncPos", function(data)
    tosyncpos=true
  end)
  client:on("setFin", function()
    setWait=false
  end)
  client:enableCompression()
  client:connect()
end

function love.load(arg)
  love.window.setVSync(0)
  connect(IP)
  camera=Camera()
  camera:setFollowLerp(0.2)
  camera:setFollowStyle('LOCKON')
end

function tmaxside(img)
  return math.max(img:getHeight(),img:getWidth())+1
end

function isOnScreen(x,y,r)
  r=r or 100
  local wx,wy=camera:toCameraCoords(x,y)
  local w,h=love.graphics.getWidth(),love.graphics.getHeight()
  return (wx<w) and (wx>-r) and (wy<h) and (wy>-r)
end

function love.draw()
  local g=love.graphics 
  g.reset()
  g.setBackgroundColor(0.2,0.25,0.2)
  w,h=g.getWidth(),g.getHeight()
  local function drawIfOnScreen(v,r)
      local sx,sy=1,1
      if not r then
        if v.w and v.h then
          r=math.max(v.w,v.h)+1
        else
          r=tmaxside(textures[v.texture])+1
        end
      end
      if isOnScreen(v.x,v.y,r) then
        g.draw(textures[v.texture],v.x,v.y)
      end
  end
    
  if connected then
    camera:attach()
    camera:follow(me.x-8*camera.scale,me.y-8*camera.scale)
    
    if players and #players>0 then
      for i,v in ipairs(players) do
        if v.name==me.name then
          if tosyncpos then
            tosyncpos=false
            me.x=v.x
            me.y=v.y
          end
          meRef=v
          drawIfOnScreen(me,100)
        else 
          drawIfOnScreen(v,100)
        end
      end
    end
    
    col=false
    local function objd(v)
      g.setColor(1,1,1)
      if aabb(me.x,me.y,32,32,v.x,v.y,v.w,v.h) then
        if v.onTouch then 
          pcall(loadstring(v.onTouch)) 
        end
        if v.col then
          me.x,me.y=prx,pry
          col=true
        end
      end
      drawIfOnScreen(v)
    end
    
    local queue={}
    if world.obj and #world.obj>0 then
      for i,v in ipairs(world.obj) do
        if not v.onTop then
          objd(v)
        else
          queue[#queue+1]=v
        end
      end
    end
    for i,v in ipairs(queue) do
      objd(v)
    end
    camera:detach()
    g.setColor(1,1,1)
    for i,v in ipairs(players) do
      local t=''
      if v.name==me.name then t=' (YOU)' end
      g.print(v.name..t,0,h-i*15)
    end
  elseif client:getState() == "connecting" then
    g.print('connecting...',10,10)
  elseif client:getState() == "disconnected" then
    client:connect() 
  end
  camera:draw()
  g.print(love.timer.getFPS())
end

local function clu() client:update() end

function love.update(dt)
  
  delta=delta+dt
  
  camera:update(dt)
  connected=client:getState() == "connected"
  udt=dt
  spd=dt/(1/60)
  --------------------------------------------
  if connected then
    prx,pry=me.x,me.y
    local ikd=love.keyboard.isDown
    local u,d,l,r=ikd'up' or ikd'w',ikd'down' or ikd's',ikd'left' or ikd'a',ikd'right' or ikd'd'
    local cx,cy=0,0
    local slow=1
    if (u and l) or (r and u) or (d and r) or (d and l) then slow=2/3 end
    if u then cy=-spd*pl_speed*slow  end
    if d then cy=spd*pl_speed*slow   end
    if l then cx=-spd*pl_speed*slow  end
    if r then cx=spd*pl_speed*slow   end
    me.x,me.y=me.x+cx,me.y+cy
  end
  --------------------------------------------
  local tries=0
  while not pcall(clu) do 
    tries=tries+1 
    if tries>50 then error'unable to update!' end
  end
  --------------------------------------------
  if connected then
    if not con then
      client:send('connected',me.name)
      con=true
    else
      if delta>0.006 then
        delta=0
        client:send("me",me)
      end
      if serverWver>world.version then
        if not worldWait then
          client:send("sendwr","")
          worldWait=true
        end
      elseif serverWver<world.version then
        client:send("worldDataO",world)
      end
    end
  else 
    con=false 
    ---world.obj={}
    ---world.version=0
    sett()
  end
  --------------------------------------------
  if love.keyboard.isDown'u' then world.version=0 end --update world
  if love.keyboard.isDown'z' then
    camera.scale=math.max(camera.scale-0.03*spd,0.3) 
  else 
    camera.scale=math.min(camera.scale+0.15*spd,1)
  end --zoom out
end

function setBlock(d,n,force)
  if not (setWait or worldWait) then
    local n=(n or #world.obj+1)
    local sd
    if d==nil then 
      if not(world.obj[n].nodel) or force then
        sd=n
        table.remove(world.obj,n)
      end
    else
      sd={i=n,v=d}
      world.obj[n]=d
    end
    client:send('set',sd)
    setWait=true
  end
end

function love.mousepressed(x,y,b)
  local wx,wy=camera:toWorldCoords(x,y)
  if connected and b==1 then
    setBlock({x=wx-16,y=wy-16,w=32,h=32,texture='box',col=true})
  elseif b==2 then
    local cx,cy=camera:toWorldCoords(love.mouse.getX(),love.mouse.getY())
    for i,v in ipairs(world.obj) do
      if aabb(v.x,v.y,v.w,v.h,cx,cy,1,1) then
        setBlock(nil,i)
        break
      end
    end
  end
end

function love.keypressed(k)
  if k=='l' then 
    if not worldWait or setWait then 
      client:disconnectNow() 
      connected=false
      sett()
    end 
  end
end

function love.quit()
  client:disconnectNow()
  return false
end