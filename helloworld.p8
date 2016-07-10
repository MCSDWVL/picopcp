pico-8 cartridge // http://www.pico-8.com
version 7
__lua__
-- fall from grace
-- a pizza cat production
-- by barbie, matt, laurel and kevin

actors={}

-- player constants.
player_acceleration = .3
player_max_speed = 3
pl = nil
pl_control = true
score = 0

-- other tuning parameters... these might need to split to be per level?
frames_til_next_enemy = 30
t = 0

-- helper to normalize a vector2
function normalize(x,y,scale)
  local magnitude = sqrt(x*x+y*y)
  if not scale then
    scale = 1
  end
  return {x=scale*x/magnitude,y=scale*y/magnitude}
end

function normalized_to_player_vector(a, scale)
  local to_pl_x = pl.x - a.x
  local to_pl_y = pl.y - a.y
  return normalize(to_pl_x, to_pl_y, scale)
end

-- sfx map
sounds = {
  dragon_fire = 6,
  thunk = 12,
  cupid_arrow = 7,
  laser = 8,
  big_laser = 9,
  mermaid_thunder = 10,
  shark_bite = 13,
  pickup = 16,
}

songs = {
  fur_elise = 0,
  star_wars = 1,
  creepy = 11,
  twinkle = 14,
  intro = 6,
  hell = 23,
  ocean = 20,
  game_over = 33,
  heaven = 24,
  sky = 25,
  ascent = 5,
}

-- table with settings for a given actor
actor_prefabs = {
  player = {
    spr_w=1,
    spr_h=1,
    frames={0,1},
    damping=.9,
    dx=0,
    dy=0,
    frametime=5,
    w=5,
    health=7,
    h=8
  },

  -- default values
  default_prefab = {
    spr_w=1,
    spr_h=1,
    frames={},
    damping=1,
    w=5,
    h=5,
    dx=0,
    dy=-1,
    frametime=1,
  },

  debug_prefab = {
    spr_w=2,
    spr_h=1,
    frames={10},
    w=16,
    dy=0,
  },

  -- enemies - heaven
  rainbow = {
    spr_w=2,
    spr_h=1,
    frames={10},
    w=16,
    is_innocent = true,
    purity = 250,
    init = function(a)
      -- create a cloud infront and slightly down
      create_actor(a.x, a.y+5, actor_prefabs.large_cloud)
    end,
  },
  cherub = {
    spr_w=2,
    spr_h=2,
    w=16,
    h=16,
    frames={20},
    dy=-2,
    frametime=5,
    init = function(a)
      local arrow = create_actor(a.x, a.y, actor_prefabs.arrow)
      arrow.owner = a

      if(a.x < pl.x) then
      	a.facing_right=true
      end
    end,
  },

  -- enemies - space
  small_meteor = {
    frames={89},
  },
  medium_meteor = {
    frames={86},
  },
  big_meteor = {
    spr_w=2,
    spr_h=2,
    frames={71},
    w=16,
    h=16,
  },
  small_alien = {
    frames={73,74},
    frametime=10,
    init = function(a)
      -- randomize horizontal movement
      a.dx = 2 - rnd(4)
    end,
    update = function(a)
      -- fire lasers randomly?
      local laser_chance = 0.01
      local roll = rnd(1)
      if roll <= laser_chance then
        create_actor(a.x,a.y,actor_prefabs.laser)
      end
    end
  },
  star = {
    frames={70},
    is_innocent=true,
    purity=100,
  },
  shooting_star = {
    frames={9},
    is_innocent=true,
    purity=1000,
    init = function(a)
      -- start off the top of the screen
      a.y = -5

      -- movement down and sideways
      a.dy = 3
      a.dx = 4-rnd(8)
    end,
  },

  -- enemies - sky
  bird = {
   frames={7,8},
   damping=1,
   dx=0,
   dy=-2,
   is_innocent=true,
   purity = 100,
 },
 butterfly = {
   frames = {68,69},
   is_innocent=true,
   purity = 500,
   update = function(a)
     butterfly_speed = 2
     local player_distance_sq = ((pl.x-a.x) * (pl.x-a.x) + (pl.y-a.y)*(pl.y-a.y))
     if player_distance_sq < 500 then
       local toward_player = normalized_to_player_vector(a, butterfly_speed)

       a.dx = -toward_player.x
       a.dy = -1
     else
       a.dx = 1-rnd(2)
       a.dy = -.5
     end
   end,
 },
 dragon = {
   frames = {80,82},
   spr_w=2,
   spr_h=2,
   w=16,
   h=16,
   damping=.89,
   frametime = 5,
   frames_since_moved = 0,
   init = function(a)
     if(a.x < pl.x) then
       a.facing_right=true
     end
   end,
   update = function(a)
     -- fire lasers randomly?
     local laser_chance = 0.01
     local roll = rnd(1)
     if roll <= laser_chance then
       create_actor(a.x,a.y,actor_prefabs.dragon_fire)
     end

     a.frames_since_moved += 1
     if a.frames_since_moved >= 65 then
       a.frames_since_moved = 0
       -- jump towards the player
       local jelly_speed = 3
       local target_vec = normalized_to_player_vector(a,jelly_speed)
       a.dx = target_vec.x
       a.dy = target_vec.y
     end

     -- keep moving up
     if(a.dy > -1) then
       a.dy -= 0.1
     end

     -- face the direction you're moving
     a.facing_right = a.dx > 0
   end,
 },
 helicopter = {
   frames = {76,78},
   spr_w=2,
   spr_h=2,
   w=16,
   h=12,
   t = 0,
   init = function(a)
     if(a.x < pl.x) then
       a.facing_right=true
     end
   end,
   update = function(a)
     a.t += 1
     a.dx = sin(a.t/50)
     -- fire lasers randomly?
     local laser_chance = 0.01
     local roll = rnd(1)
     if roll <= laser_chance then
       local dx = -1
       if a.facing_right then
         dx = -dx
       end

       for i=1,3 do
         local bullet = create_actor(a.x,a.y,actor_prefabs.bullet)
         bullet.dx = dx
         bullet.dy = -1 + (i-1)
       end
     end
   end,
 },
 small_cloud = {
   frames = {100},
   nocollide = true,
 },
 medium_cloud = {
   frames = {100},
   nocollide = true,
 },
 large_cloud = {
   frames = {102},
   nocollide = true,
   spr_w=2,
   spr_h=1,
 },
 dragon_fire = {
   frames = {85,90},
   nowrap = true,
   init = function(a)
     -- aim towards the player with normalized speed
     a.dx = pl.x - a.x
     a.dy = pl.y - a.y

     -- normalized speed
     local desired_speed = 2
     local target_vec = normalized_to_player_vector(a,desired_speed)
     a.dx = target_vec.x
     a.dy = target_vec.y
     sfx(sounds.dragon_fire)
   end,
 },

 -- enemies - ocean
 jellyfish = {
   frames={64,65},
   damping=.89,
   frames_since_moved = 0,
   update = function(a)
     a.frames_since_moved += 1
     if a.frames_since_moved >= 65 then
       a.frames_since_moved = 0
       -- jump towards the player
       local jelly_speed = 3
       local target_vec = normalized_to_player_vector(a,jelly_speed)
       a.dx = target_vec.x
       a.dy = target_vec.y
     end

     -- keep moving up
     if(a.dy > -1) then
       a.dy -= 0.1
     end
   end,
 },
 mermaid = {
   spr_w=2,
   spr_h=2,
   w=16,
   h=16,
   frames={22,24},
   frametime=2,
   init = function(a)
     if(a.x < pl.x) then
       a.facing_right=true
     end
   end,
 },
 fish = {
    frames={75},
    dy=-2,
    is_innocent=true,
    purity = 100,
    swap_color = 9,
    init = function(a)
      a.swap_color = flr(rnd(15))
    end,
    draw = function(a)
      pal(9, a.swap_color)
      spr(a.frames[1+a.frame_idx], a.x, a.y, a.spr_w, a.spr_h, a.facing_right)
      pal()
    end
 },
 seaweed = {
    spr_w=2,
    spr_h=1,
    dy=-2,
    frametime=3,
    nocollide=true,
    init = function(a)
      -- pick between the two seaweed sprites
      if rnd(1) < .5 then
        a.frames = {104,106}
      else
        a.frames = {120,122}
      end

      -- pick randomly between left and right side of the screen
      if rnd(1) < .5 then
        a.x = 0
        a.facing_right = false -- seaweed sprite is backwards
      else
        a.x = 127 - 15
        a.facing_right = true -- seaweed sprite is backwards
      end
    end
 },
 shark = {
   frames={66,67},
   damping=0,
   frametime=3,
   hit_sound=sounds.shark_bite,
   update = function(a)
     -- move towards the player directly
     shark_speed = 1
     local target_vec = normalized_to_player_vector(a,shark_speed)
     a.dx = target_vec.x
     a.dy = target_vec.y

     -- if above the player, act as if the current is too strong to go down
     if a.y < pl.y then
       -- slowly drift upwards
       a.dy = -0.3
     end

     -- change facing?
     a.facing_right = a.x < pl.x
   end,
 },

 -- special actors
  arrow = {
    frames={52},
    dx=0,
    dy=0,
    w=8,
    h=3,
    nowrap = true,
    update=function(a)
      if (not a.fired and a.y <= pl.y and (pl.x > a.x == a.owner.facing_right)) then
        -- fire!
        sfx(sounds.cupid_arrow)
        a.fired = true
        if (pl.x < a.x) then
          a.dx = -1
        else
          a.dx = 1
        end
      elseif (not a.fired) then
        -- stick to the cherub
        a.x = a.owner.x
        a.y = a.owner.y+6
        a.facing_right = a.owner.facing_right
      end
    end
  },
  bullet = {
    nowrap = true,
    color=13,
    draw = function(a)
      local exagerate_length = 3
      line(a.x, a.y, a.x+exagerate_length*a.dx, a.y+exagerate_length*a.dy, color)
    end,
  },
  laser = {
    nowrap = true,
    color=8,
    init = function(a)
      -- aim towards the player with normalized speed
      a.dx = pl.x - a.x
      a.dy = pl.y - a.y

      -- normalized speed
      local desired_speed = 2
      local magnitude = sqrt(a.dx*a.dx + a.dy*a.dy)
      a.dx /= magnitude / desired_speed
      a.dy /= magnitude / desired_speed
      sfx(sounds.laser)
    end,
    draw = function(a)
      local exagerate_length = 3
      line(a.x, a.y, a.x+exagerate_length*a.dx, a.y+exagerate_length*a.dy, a.color)
    end,
    w = 1,
    h = 1,
  },
  demon = {
   frames={216,217},
   frametime=10,
   dx=0,
   dy=0,
   nocollide=true,
   update=function(self)
   end,
  },
  relic = {
   frames={6},
   dx=0,
   dy=0,
   nocollide=true,
   --update=function(self)
   -- if t%10 == 0 then
   --		if self.up then
   --			self.y -= 1
   --			self.up = false
   --		else
   --			self.y += 1
   --			self.up = true
   -- 	end
   -- end
   --end
  }
}

-- level stuff
level_current_frame = 0
level_time_frames = 1000
levels = {
  heaven = {
   song = songs.heaven,
   draw_bg=function(self)
    foreach(self.tiles,self.draw_tile)
   end,
   draw_tile=function(tile)
   	spr(tile.sprite,tile.x,tile.y)
   end,
   init = function(self)
    local tileset={}
    local shift_times={
     0,0,1,2,4,8,16,0,0,16,8,4,2,1,0,0
    }
    for x=16,32 do
     add(tileset, mget(x,0))
    end
    self.tiles = {}
    for j=0,15 do
     for k=0,16 do
      add(self.tiles, {
       sprite=tileset[j+1],
       x=j*8,
       y=k*8,
       v=shift_times[j+1]
      })
     end
    end

    pl.frames = {0,1}
   end,
   update = function(self)
    foreach(self.tiles, self.update_tile)
   end,
   update_tile = function(tile)
   	if tile.y<-8 then
   	 tile.y=127
   	end
   	if t%tile.v==0 then
   	 tile.y -= 1
   	end
   end,
   spawns = {
     actor_prefabs.cherub,
     actor_prefabs.rainbow,
   }
  },
  space = {
    spawns = {
      actor_prefabs.small_alien,
      actor_prefabs.small_meteor,
      actor_prefabs.medium_meteor,
      actor_prefabs.big_meteor,
      actor_prefabs.shooting_star,
      actor_prefabs.star,
    },

    song = songs.star_wars,

    init = function(self)
     pl.swimming = true
     pl.frames = {4,5}
     self.stars={}
    	while #self.stars < 50 do
    		add(self.stars, {
    			x=flr(rnd(127)),
    			y=flr(rnd(127)),
    			c=7,
    			v=rnd(2)
    			}
    		)
    	end
    	for x=1,15 do
    	 self.stars[x].twinkle=true
    	 self.stars[x].twinkle_rate=10-flr(rnd(5))
    	end
    end,
    update = function(self)
    	foreach(self.stars,self.update_star)
    end,
    draw_bg = function(self)
    	rectfill(0,0,127,127,0)
    	foreach(self.stars, self.draw_star)
    end,
    draw_star = function(star)
    	pset(star.x,star.y,star.c)
    end,
    update_star = function(star)
    	if star.twinkle then
    	 if t%star.twinkle_rate==0 then
    	 	star.c=7-flr(rnd(3))
    	 end
    	end
     star.y-=star.v
     if star.y < 0 then
     	star.y=128
     	star.x=flr(rnd(127))
     end
    end
  },
  sky = {
    song = songs.sky,
    spawns = {
      actor_prefabs.bird,
      actor_prefabs.dragon,
      actor_prefabs.helicopter,
      actor_prefabs.small_cloud,
      actor_prefabs.medium_cloud,
      actor_prefabs.large_cloud,
      actor_prefabs.butterfly,
    },
    init = function() end,
    draw_bg = function(self)
      rectfill(0,0,127,127,12)
    end,
    update = function() end,
  },
  ocean = {
    song = songs.ocean,
    spawns = {
      actor_prefabs.jellyfish,
      actor_prefabs.shark,
      actor_prefabs.fish,
      actor_prefabs.mermaid,
      actor_prefabs.seaweed,
    },
    init = function(self)
      pl.swimming = true
      pl.frames = {4,5}
      self.bubbles={}
      -- bubbles
      while #self.bubbles < 10 do
        add(self.bubbles, {
          x=flr(rnd(127)),
          y=flr(rnd(127)),
          v=.25+rnd(1),
          t=0,
          offset=rnd(3),
          radius=rnd(3),
        })
      end
    end,
    update = function(self)
      foreach(self.bubbles,self.update_bubble)
    end,
    draw_bg = function(self)
      rectfill(0,0,127,127,1)
      foreach(self.bubbles, self.draw_bubble)
    end,
    draw_bubble = function(bubble)
      circfill(bubble.x + sin(bubble.t/50)*bubble.offset, bubble.y, bubble.radius, 13)
    end,
    update_bubble = function(bubble)
      bubble.y-=bubble.v
      bubble.t += 1
      if bubble.y < 0 then
        bubble.y=128
        bubble.x=flr(rnd(127))
      end
    end,
  },
  hell = {
   song = songs.hell,
   init = function(self)
    pl.frames={216,217}
    self.demons = {}
    pl_control = false
    pl.x=58
    pl.y=-10
    pl.dy=2

    for j=0,15 do
    	if (j < 5 or j >10) then
    	create_actor(j*8,14*8,
    	actor_prefabs.demon)
    	end
    end
   end,
   update = function(self)
    level_current_frame = 0
   	if pl.y <112 then
  			pl.dy=2
  		else
  			self.landed = true
  			pl.dy=0
  			if self.relic == nil then
  			 self.relic = create_actor(58,100,actor_prefabs.relic)
  			end
  		end
   end,
   draw_bg = function(self)
    map(0,0,0,0,16,16)
    if self.landed then
     	rectfill(30, 40, 97, 80, 2)
     	print("congratulations!", 33, 45, 7)
     	print("the world", 47, 55, 10)
     	print("is doomed", 47, 65)
    end
   end,
   spawns = {}
 },
 -- debug = {
 --   init = function(self)
 --     self.a = create_actor(64, 64, actor_prefabs.debug_prefab)
 --   end,
 --   song = 5,
 --   draw_bg = function(self)
 --     cls()
 --     color(7)
 --     print(self.a.x + self.a.w, 5, 20)
 --     print(pl.x, 5, 30)
 --     print(self.a.x, 30, 20)
 --     print(self.a.w, 50, 20)
 --   end,
 --   update = function() end,
 --   spawns = {},
 -- },
}
ordered_levels = {
  levels.heaven,
  levels.space,
  levels.sky,
  levels.ocean,
  levels.hell
}
current_level_idx = 1
current_level = ordered_levels[current_level_idx]

-- create a shallow copy of a prefab
function clone(prefab)
  local copy = {}
  for k,v in pairs(prefab) do
    copy[k] = v
  end
  return copy
end

function default_values(a)
  for k,v in pairs(actor_prefabs.default_prefab) do
    if (a[k] == nil) then
      a[k] = v
    end
  end
end

-- create an actor from a prefab
function create_actor(x, y, prefab)
  a = clone(prefab)
  default_values(a)

  -- some fields are not initialized from the prefab
  a.x = x
  a.y = y
  a.frame_idx = 0
  a.updates_this_frame = 0
  a.facing_right = false

  -- add to the list of actors and return a reference to it.
  add(actors,a)

  -- some prefabs have a custom initializer
  if (a.init) then
    a.init(a)
  end

  return a
end

-- draw an actor
function draw_actor(a)
  if (a.draw ~= nil) then
    a.draw(a)
  elseif (#a.frames >= 0) then
    spr(a.frames[1+a.frame_idx], a.x, a.y, a.spr_w, a.spr_h, a.facing_right)
  else
    circfill(a.x,a.y,3,spr)
  end
end

function collide()
 for a in all(actors) do
  if (a ~= pl) and not a.nocollide then
    if ((pl.x + pl.w > a.x) and
        (a.x+a.w > pl.x) and
        (pl.y+pl.h > a.y) and
        (a.y+a.h > pl.y))
  	then
      -- return the actor we collide with so we can decide what to do with it.
    return a
   end
  end
 end
  -- didn't collide with anything
 return nil
end

-- update the players movement force
colliding = nil
function update_player(a)
  accel={dx=0,dy=0}
  if pl_control then
  	if (btn(0)) then
    accel.dx-=1
    a.facing_right=false
  	end
  	if (btn(1)) then
    accel.dx+=1
    a.facing_right=true
  	end
  	if (btn(2)) then accel.dy-=1 end
  	if (btn(3)) then accel.dy+=1 end

	  if pl.swimming then
    if btn(2) or btn(3) then
      pl.frames = {4,5}
    elseif btn(0) or btn(1) then
      pl.frames = {2,3}
    end
 	 end
  end


  -- normalize the acceleration to the intended move speed
  accel_mag = sqrt(accel.dx*accel.dx + accel.dy*accel.dy)
  if (accel_mag > 0) then
    accel.dx /= accel_mag
    accel.dy /= accel_mag
    accel.dx *= player_acceleration
    accel.dy *= player_acceleration
  end

  -- add the acceleration to the player speed
  a.dx += accel.dx
  a.dy += accel.dy

  -- if player speed is too great normalize it to the intended max
  speed_mag = sqrt(a.dx*a.dx+a.dy*a.dy)
  if (speed_mag > player_max_speed) then
    a.dx /= speed_mag / player_max_speed
    a.dy /= speed_mag / player_max_speed
  end

  -- check for collision with obstacles/powerups?
  local wascolliding = colliding
  colliding = collide()
  if (colliding and (colliding ~= wascolliding)) then
    if (colliding.is_innocent) then
      score += colliding.purity
      sfx(sounds.pickup)
      del(actors, colliding)
    else
      take_damage(colliding)
    end
  end
end

-- update the position of an actor based on their dx/dy
function apply_movement(a)
  a.x += a.dx
  a.y += a.dy

  -- damping
  a.dx *= a.damping
  a.dy *= a.damping

  -- horizontal wrap
  if not a.nowrap then
    if(a.x < 0) then a.x += 127 end
    if(a.x > 127) then a.x -= 127 end
  end

  -- keep player in bounds
  if a == pl then
    if a.y > 122 then a.y = 122
    elseif a.y < 0 then a.y = 0
    end
  end

  -- check if npc has moved "off screen"
  if (is_out_of_bounds(a) and a ~= pl) then
    del(actors,a)
  end
end

-- is an actor sufficiently out of the placespace that they need deletion?
function is_out_of_bounds(a)
  local tolerance = 10
  return a.y < -tolerance or a.y > 127+tolerance or a.x < -tolerance or a.y > 127+tolerance
end

-- countdown to adding an enemy
function update_frames_til_next_enemy()
  if #current_level.spawns == 0 then
    return
  end

  frames_til_next_enemy -= 1
  if (frames_til_next_enemy <= 0) then
    x = flr(rnd(127))
    y = 130
    actor_prefab = current_level.spawns[flr(1+rnd(#current_level.spawns))]

    create_actor(x, y, actor_prefab)
    frames_til_next_enemy = 30
  end
end

-- called once at the start on run
function _init()
  -- create the player
  pl = create_actor(70, 90, actor_prefabs.player)

  -- advance to the first level.
  on_current_level_changed()
end

function on_current_level_changed()
  if current_level_idx > #ordered_levels then
    return
  end
  level_current_frame = 0
  current_level = ordered_levels[current_level_idx]
  current_level.init(current_level)
  music(current_level.song, 1000, 3)
end

function advance_level()
  current_level_idx += 1
  on_current_level_changed()
end

function actor_update(a)
  -- behavior update
  if (a.update ~= nil) then
    a.update(a)
  end

  -- movement update
  apply_movement(a)

  -- animation update
  a.updates_this_frame += 1
  if (a.updates_this_frame > a.frametime) then
    a.updates_this_frame = 0
    a.frame_idx = (a.frame_idx + 1) % #a.frames
  end
end

-- called once every frame
function _update()
  current_level.update(current_level)
  level_current_frame += 1
  if level_current_frame > level_time_frames then
    advance_level()
  end

  -- player movement
  update_player(pl)

  -- apply all the forces
  foreach(actors,actor_update)

  -- check for adding enemies
  update_frames_til_next_enemy()

  -- camera shake
  camera_shake_update()

  --increment time
  t+=1
end


function take_damage(source)
  camera_shake_remaining_frames = 10
  pl.health -= 1

  if (source.hit_sound) then
    sfx(source.hit_sound)
  else
    sfx(sounds.thunk)
  end

  -- game over
  if (pl.health == 0) then
    music(-1)
    sfx(songs.game_over)
  end
end

camera_shake_violence = 5
camera_shake_remaining_frames = 0
function camera_shake_update()
  if (camera_shake_remaining_frames > 0) then
    camera_shake_remaining_frames -= 1
    camera(rnd(camera_shake_violence), rnd(camera_shake_violence))
    if (camera_shake_remaining_frames == 0) then
      camera()
    end
  end
end

function draw_hud()
  rectfill(0,0,127,8,2)
  draw_health()
  draw_score()
end

function draw_health()
  local heart_frame = 84
  local heart_width = 8
  local heart_x = 127-8
  local heart_y = 2
  for i=1,pl.health do
    spr(heart_frame, heart_x, heart_y)
    heart_x -= heart_width
  end
end

function draw_score()
  local score_x = 8
  local score_y = 2
  local score_color = 7
  print("purity: "..score, score_x, score_y, score_color)
end

-- called approximately once per frame.
function _draw()
  current_level.draw_bg(current_level)

  if (colliding and not colliding.is_innocent) then
    rectfill(0,0,127,127,9)
  end
  foreach(actors,draw_actor)
  draw_hud()

  if (pl.health <= 0) then
    rectfill(0,0,127,127,0)

    print("game over", 50,50,1)

  end
end

__gfx__
080000800800008000000000000000000800008008000080000000000000000000000700000a0000000888888888000000000000000000000000000000000000
088888800888888088080000880080000888888008888880055006600000077000007700a0aaa0a0008999999999880000000000000000000000000000000000
0098980000989800088080800880800800989800009898005500dd6607707700077070000aa7aa000899aaaaaaaa998000000000000000000000000666000000
000880000008800008988880089888800808808000088000515006d69777777797777777aa777aa0089aabbbbbbaa99800000000005555000000006555600000
088888800888888008888800088888080088880008888880515006d600077770000777700aa7aa0089aabccccccbaa9800000000055555550000065666560000
0008800000088000089080880890808000088000000880005500dd66000009000000099000aaa0a089abccddddccba980000000055f555500006656666560000
0080800000808800880800008800800000808800008080000550066000000090000000000a0a000089abcdd00ddcba98000000005cfc55500065566666656000
0800080000800000000000000000000000800000080008000000000000000000000000000000000089abcd0000dcba98000000005fff55500656666666656000
000000777770000000000000000000000000000a00a000000000000eeee000000000000eeee000000500000000000005000000005fff55006566666656665600
0000000000000000000000777770000000000000aaaa0000900900fffffe0000900900fffffe000005000000000000050000000055455ddd6666666656665600
000000000000000000000000000000000000000fffffa0070909001ff1ffe0000909001ff1ffe00005500000000000550000000005f5ddddd666665656665600
0000080000080000000008000008000000002001ff1ff077009000ffffffe000009000ffffffe000055500909090055500000000055ddddddd66565656566560
000008988898000000000898889800000000270ffffff7779909f00ffffee0009909f00ffffee0000555055555550555000000000d5ddddddd65600066566660
0000088888880000000008888888000000020070ffff7770000ff000ffffee00000ff000ffffee00005555555555555000000000dd5ddddddd56000006566660
08088888888888080000888888888000002ffff7444ff7000000f900fffffee00000f900fffffee000055555c555550000fddddddd5dddd1dd60000000665660
088888888888888808088888888888080020fff4ffffff0000000f9ff44ff00000000f9ff44ff0000000555555555000000ddddd1d5dddd1dd00000000065660
08888888288888880888888828888888002000074fff4f00000000f94fff3000000000f94fff3000000005b555b500000000dddd1d5dddd0dd00000000006660
08888822822888880888882282288888000200700444ff0000000003ff33300000000003ff3330000000055555550000000000000d5dddd0dd00000000000660
0000888828888000008888882888888000002700f77777000000000339330000000000033933000000000055c5500000000000000dd5ddd00f00000000000600
0000088282880000000008828288000000002000ff77f0000000000333930000000000033393000000000055c5500000000000000dd5dddd0000000000000000
0000008888800000000000888880000000000000ff4ff0000000000033333300000000003333300000000055c5500000000000000dd5dddd0000000000000000
00000088088000000000008808800000000000000f4f4ff00000000000330000000000000033030000000005c5000000000000000dd5dddd0000000000000000
00000008080000000000000808000000000000000004f000000000000003000000000000003000000000000555000000000000000ddd5ddd0000000000000000
000000080800000000000080800000000000000000000000000000000000000000000000000000000000000050000000000000000ddf1ddd0000000000000000
000000000000000000000000000000000400000900000000000000000000000000000000000000000000000000000000000000000dff11ff0000000000000000
0000000000000000000000000000000045555590000000000000000000000000000000000000000000000000000000000000000000ff000ff000000000000000
00000000000000000000000000000000040000090000000000000000000000000000000000000000000000000000000000000000000ff00ff000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ff000f000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000f000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eee000000eee005500050000000500030003000030300000700000000000066600000000077000000770000000000000005550000000000000055500000000
0eeeee0000eeeee0755b5505005b55050e303e0000303000077700000000066666660000007bb700007777000009000900555555555000050555555555555005
0eeeeee000eeeeee0755555555555555e22322e00e232e00777770000006666666766000071b1b70077bb7700999909000000606000000050000060600000005
e00e00e00e00e00e0075555577755555e22322e0e22322e007770000006666666777660007bbbb70071b1b709929999000555555555000550055555555500055
0e00e00ee00e00e007555555055555550ee3ee000ee3ee000070007006676666677666000cccccc00cccccc099999990055cc55555555555055cc55555555555
e00e00e00e00e00e7550500500005005e22322e00e232e00000007770666666666666660cacacacccacacacc0999900955ccc5555555555555ccc55555555555
0e00e00ee00e00e000000000000000000ee0ee0000e0e0000000007066666666666666660cccccc00cccccc00009000055555555555555555555555555555555
00000000000000000000000000000000000000000000000000000000666666666666666600000000000000000000000005555555555550000555555555555000
0003300000003000000000000000000088088000000880000066000066667766666666660000000000a80090000a000005555555555000000555555555500000
00333000000333000000000000000000888880000a0098007766666066667766666667660000000090a88a90000aca0000055555500000000005555550000000
033b33000003b33000033000000030000888000008a899887766667766666666666666660000000009aaaa80000aaaa060006000600000006000600060000000
33b033300033b3330033300000033300008000008aa9aaa8666666660666666666666660000066608898a880000a000066666666666600006666666666660000
3bb00333303bbb33033bb3333003b3300000000008aaaa906666766606666666666666600006676608998999000aa00000000000000000000000000000000000
3b003333330000b333bb33333333b333000000000a9899000666666000677666667760000066666609a89a80aa0aa00000000000000000000000000000000000
30083383330000033bb83383333bbb3300000000900809000066000000077766666700000067666099a09aa8a00a000000000000000000000000000000000000
00333333333000003b333333333000b30000000000090000000000000000006666000000000766000a0009000aa0000000000000000000000000000000000000
00333333333000003033333333300003000070000000000000000077760006660000000000000000000000000000000000000000000000000000000000000000
0003330033300000000e330033300000077677000000000000666777776777760000000000000000033330000000000000000000000000000000000000000000
0000000333330000eeee003333300000777677670000770007777777777777773333000000003330333333330000000000000000000000000000000000000000
00000033333000000e00000333330000777767600006777007777767777677773333333003333333333333333333333000000000000000000000000000000000
00300003333000000000000333300000076777700776677700777667767767003333333333333000333333333333333300000000000000000000000000000000
03000033333000000030003333300000007707707777777700006607767766003333333333300000333000333333000000000000000000000000000000000000
03333333333000000033333333300000000000000767700000000000066700003300033333000000330000000000000000000000000000000000000000000000
00333330303300000003333030330000000000000000000000000000000000003000000000000000300000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000333000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000003330000000000000000033333000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000003333333333333000333333333003300000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000003333333333003300333333330000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000003333000000000000333330000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000009000000000000000000900000000000aaaa00000000000000aaaa0000000000077777000000000000000000000
0000000000000000000000000000000000000a90000000000000000009a000000000a0000a000000000000a0000a000000000000000000000000000000000000
000000900000000000000000090000000000009990000000000000099900000000000aaaa00000000000000aaaa0000000000000000000000000000000000000
00000a90000000000000000009a0000000000aa999900000000009999aa000000000040440000000000000040440000000000800000800080000000000000000
000000999000000000000009990000000000009a9999900000099999a90000000000444f44000000000000444f44000000000898889800080000000000000000
00000aa999900000000009999aa00000a0000aa999999900009999999aa0000a0000ffffff000000000000ffffff000000000888888808880000000000000000
0000009a9999900000099999a90000000a000a0a9999999009999999a0a000a00000fcffcf000000000000fcffcf000008088888888888880000000000000000
a0000aa999999999999999999aa0000aa99900a0a99999999999999a0a00999a0000ffffff000000000000ffffff000008888888888888880000000000000000
0a000a0a9999999999999999a0a000a00a9999999999999999999999999999a000000ffff00000000000000ffff0000008888888288888800000000000000000
a99900a0a99999999999999a0a00999aaaa99999999999999999999999999aaa0000004400000000000000004400000008888822822888000000000000000000
0a9999999999999999999999999999a0009a999999999999999999999999a90000fffffff6ff00000000fffffff6ff0000008888288880000000000000000000
aaa99999999999999999999999999aaa0aa9a9a999999999999999999a9a9aa000ffffff66ff0000000fffffff66fff000000882828800000000000000000000
009a999999999999999999999999a900009a9a9a9999999999999999a9a9a9000fffff6666fff000000ff4ff66664ff000000088888000000000000000000000
aaa9a9a999999999999999999a9a9aaa00aa0aa9a99999999999999a9aa0aa000ff46666564ff000000ff46666564ff000000088088000000000000000000000
009a9a9a9999999999999999a9a9a9000000aa0a9a999999999999a9a0aa00000ff46655664ff000000ff46655664ff000000008080000000000000000000000
0aaa0aa9a99999999999999a9aa0aaa0000000009999999999999999000000000fff666666fff000000ff06666660ff000000008080000000000000000000000
0000aa0a9a999999999999a9a0aa00000000000099999999999999990000000000fff6665fff000000ff0006665000ff00000000000000000000000000000000
0000000099999999999999990000000000000000999999999999999900000000000fff55fff0000000ff0006556000ff00000000000000000000000000000000
000009999999999999999999999000000000000999999999999999999000000000006f66f600000000ff0066666600ff00000000000000000000000000000000
0000999999999999999999999999000000000099999999999999999999000000000066666600000000ff0066666600ff00000000000000000000000000000000
00099999999a99999999a9999999900000000999999999999999999999900000000066666600000000f000666666000f00000000000000000000000000000000
0009999999a9aa9999aa9a9999999000000099999999a999999a9999999900000000666666000000000000666666000000000000000000000000000000000000
000999999a9a00000000a9a99999900000009999999a9aa99aa9a999999900000000666666000000000000666666000000000000000000000000000000000000
009999a9a9a0000000000a9a9a9999000000999999a9a000000a9a99999900000000666666000000000000666666000000000000000000000000000000000000
009a9a9a0a000000000000a0a9a9a9000009999a9a9a00000000a9a9a99990000006666666600000000006666666600000000000000000000000000000000000
00a9a90aa00000000000000aa09a9a000009a9a9a0a0000000000a0a9a9a90000000f6666f000000000000f6666f000000000000000000000000000000000000
009a0aa000000000000000000aa0a900000a9a90aa000000000000aa09a9a0000000ff00ff000000000000ff00ff000000000000000000000000000000000000
0009a0a000000000000000000a0a90000009a0aa0000000000000000aa0a90000000ff00ff000000000000ff00ff000000000000000000000000000000000000
000aaa00000000000000000000aaa00000009a0a0000000000000000a0a900000000ff00ff000000000000ff00ff000000000000000000000000000000000000
0000aa00000000000000000000aa00000000aaa000000000000000000aaa00000000ff00ff000000000000ff00ff000000000000000000000000000000000000
00000a00000000000000000000a0000000000aa000000000000000000aa000000000ff00ff000000000000ff00ff000000000000000000000000000000000000
00000000000000000000000000000000000000a000000000000000000a00000000000f00f00000000000000f00f0000000000000000000000000000000000000
00000000000000aaaa000000000000009a9a9a9aa9a9a9a9a9a9a9a9aaaaaaaa9999999988888888888888888888888800000000000000000000000000000000
0000000000000a0000a0000000000000aaaaaaaa9aaa9aaa9a9a9a9aaaaaaaaa9999999988888898888888988888988800000000000000000000000000000000
00000090000000aaaa00000009000000a9a9a9a9a9a9a9a9a9a9a9a9aaaaaaaa9999999988999999999999999999998800000000000000000000000000000000
00000a90000000404400000009a00000aaaaaaaaaa9aaa9a9a9a9a9aaaaaaaaa9999999988999999999999999999998800000000000000000000000000000000
0000009990000444f4400009990000009a9a9a9aa9a9a9a9a9a9a9a9aaaaaaaa9999999988999999999999999999998800000000000000000000000000000000
00000aa999900ffffff009999aa00000aaaaaaaa9aaa9aaa9a9a9a9aaaaaaaaa9999999988999999999999999999998800000000000000000000000000000000
0000009a99999fcffcf99999a9000000a9a9a9a9a9a9a9a9a9a9a9a9aaaaaaaa9999999988898888898888889888888800000000000000000000000000000000
a0000aa999999ffffff999999aa0000aaaaaaaaaaa9aaa9a9a9a9a9aaaaaaaaa9999999988888888888888888888888800000000000000000000000000000000
0a000a0a999999ffff999999a0a000a0a9a9a9a99a9a9a9a00000000000000000800008008000080000000000000000000000000000000000000000000000000
a99900a0a99999944999999a0a00999a99999999a999a99900000000000000000888888008888880000000000000000000000000000000000000000000000000
0a999999999fffffff6ff999999999a09a9a9a9a9a9a9a9a000000000000000000a8a80000a8a800000000000000000000000000000000000000000000000000
aaa9999999fffffff66fff9999999aaa9999999999a999a900000000000000000808808000088000000000000000000000000000000000000000000000000000
009a999999ff4ff66664ff999999a900a9a9a9a99a9a9a9a00000000000000000088880008888880000000000000000000000000000000000000000000000000
aaa9a9a999ff46666564ff999a9a9aaa99999999a999a99900000000000000000008800000088000000000000000000000000000000000000000000000000000
009a9a9a99ff46655664ff99a9a9a9009a9a9a9a9a9a9a9a00000000000000000080880000808000000000000000000000000000000000000000000000000000
0aaa0aa9a9ff96666669ff9a9aa0aaa09999999999a999a900000000000000000080000008000800000000000000000000000000000000000000000000000000
0000aa0a9ff9996665999ff9a0aa0000776777677676767676767676766676667666766600000000000000000000000000000000000000000000000000000000
000000009ff9996556999ff900000000677767776777677767676767676767676676667600000000000000000000000000000000000000000000000000000000
000009999ff9966666699ff999900000776777677676767676767676667666767666766600000000000000000000000000000000000000000000000000000000
000099999ff9966666699ff999990000677767777767776767676767676767676676667600000000000000000000000000000000000000000000000000000000
000999999f9a96666669a9f999999000776777677676767676767676766676667666766600000000000000000000000000000000000000000000000000000000
0009999999a9a666666a9a9999999000677767776777677767676767676767676676667600000000000000000000000000000000000000000000000000000000
000999999a9a06666660a9a999999000776777677676767676767676667666767666766600000000000000000000000000000000000000000000000000000000
009999a9a9a0066666600a9a9a999900677767777767776767676767676767676676667600000000000000000000000000000000000000000000000000000000
009a9a9a0a006666666600a0a9a9a900666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00a9a90aa0000f6666f0000aa09a9a00666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
009a0aa000000ff00ff000000aa0a900666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
0009a0a000000ff00ff000000a0a9000666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
000aaa0000000ff00ff0000000aaa000666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
0000aa0000000ff00ff0000000aa0000666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000a0000000ff00ff0000000a00000666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000f00f00000000000000666666667777777700000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7c7f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c4c7c7c7c7c7c7c7c7c7c7c7c7c7c7c4f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4c4f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c5c4c4c4c4c4c4c4c4c4c4c4c4c4c4c5f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5c5f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c6c5c5c5c5c5c5c5c5c5c5c5c5c5c5c6f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6c6f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d5c6c6c6c6c6c6c6c6c6c6c6c6c6c6d5f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d4d5d5d5d5d5d5d5d5d5d5d5d5d5d5d4f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c8d4d4d4d4d4d4d4d4d4d4d4d4d4d4c8f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8c8f4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
c9cacacacacacacacacacacacacacacbf4f4e8e7e6e5e4f5f5e4e5e6e7e8f4f4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
011d000028550275502855027550285502355026550245502155021555185501c5502155023550235551c55021550235502455024550245552855428550285502750028500275002850023500265002450021505
011400001f0701f0001f0501b0001f0501f0001b050220501f0501f0501b050220501f0502600026050260002605000400260500000027050220501e0501b0001b050220501f050000002b0502b0502b0502b000
01130000130500000013050000002b0502b050000002a0502a050280002905028000280502705028050000002005020050250502505025050250002405024050230502305022050210502205022050000001b050
01120000000001e0501e0501b0001b0501b050000001e0502200022050220501f0001f0501f0501f050260002205022050260502605026050000002b0502b0502b05000000130501300013050000002b0502b050
011100002a0002a0502a0502900029050280002805027000270502700028050280001f050000002505025050240502e0002205021050220502205022050000002705027050000002a0502a050000002e0502e050
01100000000001f050000001b0500000022050000001f0501f0501f0501f0501f0501f0501f0501f0501f0501f0411f0401f0401f0401f0311f0301f0301f0301f0211f0201f0201f0201f0201f0111f0101f000
011000000c6710e6710e6710c6711360115601176010c6010c6010040100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011600003771439703396033960334603136033560313603376031560439603186033b6030c6033c6031530600000000000000000000000000000000000000000000000000000000000000000000000000000000
011500001f57318603000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003017300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01100000096730966309653096430963309623096130c0000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0110002010752177521775210752117520e75210752177521775211752187521075217752177521775210752157520e7521575210752177521775210752117520e7521075217752177521575213752137520e722
011000001357500300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d0000007320c6650c6050010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011400001874618706187461f7061f746217061f7461d706217461c706217461a7061f7461f7461d7061d7061d746180061d746000061c746000061c746000061a746000061a7461870618746187460000600006
011700181c2422424224242000021c242000021a2421624216242000021d2421624200002242421b2021b2421b2421b2021824223241242423420228242342422320200002000021d2021d202000022420200002
01040000247403074130744307451c105000002620428204202042920400004282041920428204292042820422204292040000428204291042920400004292042820526205282052620429204292010000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
012800001075010740107300e7210e7500e7400e7301072110750107401073011721117501174011730107211075010740107300e7210e7500e7400e730107211075010740107301172111750117401173011720
012800002f7602f7662d74028745267502875029740297302f7602f7662d74028745297502875026740267302f7602f7662d74028740297562b7502d7402d7302b7602b766287402874626740267302672026710
012800002376023766217401c7451a7501c7501d7401d7302376023766217401c7451d7561c7501a7401a7302376023766217401c7451d7561f75621740217351c7601c7661d7401d74621740217302172021710
011e00002451426524285342853428530285342653424534285342653426534265342653026534245342353424534265342453423534235302453423534215342353423520235202352023510235102351023510
011e00003230332403325033260332703322033210332003320023210232202323023240232502326023270232001321013220132301324013250132601327013200632106321063230632306324063260632606
012800003137431374323043237432304323742f374323743137431374000002e374000002e3742f3742b3743137431374000003237400000323742f374353743637434374323742f3742e3742e3412e3012e300
012800002771027710277102771026711267102671026710277112771027710277102871128710287102871027711277102771027710267112671026710267102771127710277102771028711287102871028710
012400202f5342f511285042f5342f5112f5042f5342f5112d5342d5112d5042d5342d5112d5042d5342d5112f5342f5112f5042f5342f5112f5042f5342f5112d5342d5112d5042d5342d5112d5042d5342d511
01240000280652c0652d0652c065280652c0652d0652c065260652a0652b0652a065260652a0652b0652a065280652c0652d0652c065280652c0652d0652c065260652a0652b0652a06526030260212601126001
011e00002b064260642b0642f0642d0642b0642a0642d06428064260642406428064260642605026040260042b064260642b0642d0642a064280642606426060280642406424064210641f0641f0501f0402f004
011e00002b064260642b0642f0642d0642b0642a0642d06428064260642406428064260642605026040000002b064260642b0642d0642a0642806426064260642f0642b0642d0642a0642b0642b0502b04000000
011e00001f0141f0101f0101f0101e0141e0101e0101e0101f0141f0101f0101f0101a0141a0101a0101a0101f0141f0101f0101f0101e0141e0101e0101e010210142101021010210101f0141f0101f0101f010
011e00001f0141f0101f0101f0101e0141e0101e0101e0101f0141f0101f0101f0101a0141a0101a0101a0101f0141f0101f0101f0101e0141e0101e0101e0101801418010180101801013014130101301013010
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 01414344
00 02424344
00 03424344
00 04424344
02 05424344
00 0b464344
00 4b424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 1e1f4344
02 1e204344
00 62624344
03 24234344
03 25264344
01 28294344
02 272a4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
