minetest.register_node("metallicum:block", {
    description = "Titanium Block",  
    tiles = {"metallicum_titanium_block.png"},
    is_ground_content = false,  
    groups = {cracky = 1, stone = 2},
    sounds = default and default.node_sound_stone_defaults() or nil,
})

minetest.register_craft({
    type = "cooking",
    output = "metallicum:ingot",
    recipe = "metallicum:titanium_ore",
    cook_time = 5,
})

minetest.register_ore({
    ore_type = "scatter",
    ore = "metallicum:titanium_ore",
    wherein = "default:stone",
    clust_scarcity = 25 * 25 * 25,
    clust_size = 6,
    height_min = -2000,
    height_max = -1500,
})

minetest.register_node("metallicum:titanium_ore", {
    description = "Titanium Ore",  
    tiles = {"metallicum_titanium_ore.png"},
    is_ground_content = false,
    groups = {cracky = 1, stone = 2},
    sounds = default and default.node_sound_stone_defaults() or nil,
})

minetest.register_craftitem("metallicum:ingot", {
    description = "Titanium Ingot",
    inventory_image = "metallicum_titanium_ingot.png",
})

minetest.register_craft({
    output = "metallicum:ingot 9",
    recipe = {{"metallicum:block"}},
})

minetest.register_craft({
    output = "metallicum:block",
    recipe = {
        {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
        {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
        {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
    },
})

-- support
local function register_tool(name, description, inventory_image, tool_capabilities, recipe)
    minetest.register_tool(name, {
        description = description,
        inventory_image = inventory_image,
        tool_capabilities = tool_capabilities or {max_drop_level = 3, groupcaps = {}},
        sound = {breaks = "default_tool_breaks"},
    })
    minetest.register_craft({
        output = name,
        recipe = recipe,
    })
end

-- titanium mace
minetest.register_tool("metallicum:mace", {
    description = "Mace",
    inventory_image = "metallicum_mace.png",
    groups = {snappy = 1},
    max_drop_level = 1,
    tool_capabilities = {
        groupcaps = {
            snappy = {
                times = {[1] = 0.25, [2] = 0.30, [3] = 0.10},
                uses = 2000,
                maxlevel = 1,
            },
        },
        damage_groups = {fleshy = 5},
    },
    recipe = {
        {"metallicum:titanium_block"},
        {"default:stick"},
        {"default:stick"},
    },
})

local player_damage_tracker = {}

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    if hitter:get_wielded_item():get_name() == "metallicum:mace" then
        local velocity = player:get_velocity()
        local fall_speed = velocity.y

        if fall_speed < -10 then
            damage = damage * 2
        end
        local player_name = player:get_player_name()
        if not player_damage_tracker[player_name] then
            player_damage_tracker[player_name] = 0
        end
        player_damage_tracker[player_name] = player_damage_tracker[player_name] + 1
        damage = damage + player_damage_tracker[player_name]
        player:punch(hitter, time_from_last_punch, tool_capabilities, dir)
    end

    return damage
end)

minetest.register_on_dieplayer(function(player)
    local player_name = player:get_player_name()
    player_damage_tracker[player_name] = nil
end)

-- grappling hook
local MAX_DISTANCE = 10
local MAX_TRAVEL_DISTANCE = 10 
local STOP_DISTANCE = 0.18  
local MIN_SPEED = 0.5 
local grappling_hooks = {}

minetest.register_tool("metallicum:grappling_hook", {
    description = "Grappling Hook",
    inventory_image = "metallicum_graple.png",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "node" then
            local target_pos = pointed_thing.under
            local player_pos = user:get_pos()

            local dir = vector.subtract(target_pos, player_pos)
            local dist = vector.length(dir)
            dist = math.min(dist, MAX_DISTANCE)

            if dist < 0.1 then
                return itemstack
            end
            dir = vector.normalize(dir)
            local speed = math.min(1.5, dist * 0.05)

            grappling_hooks[user:get_player_name()] = {
                target_pos = target_pos,
                current_pos = player_pos,
                dir = dir,
                speed = speed,
                distance = dist,
                last_move_time = minetest.get_gametime(),
            }
        end
        return itemstack
    end,
})

local function update_grappling_hook(player_name, data)
    local user = minetest.get_player_by_name(player_name)
    if not user then return end

    local player_pos = user:get_pos()
    local target_pos = data.target_pos
    local dir = data.dir
    local speed = data.speed
    local current_dist = vector.distance(player_pos, target_pos)

    if current_dist > MAX_TRAVEL_DISTANCE then
        user:set_pos(player_pos)
        grappling_hooks[player_name] = nil
        return
    end

    current_dist = math.min(current_dist, MAX_DISTANCE)
    local new_speed = math.min(speed, current_dist * 0.1)
    local move_dir = vector.multiply(dir, new_speed)
    local next_pos = vector.add(player_pos, move_dir)
    local node_at_next_pos = minetest.get_node(next_pos).name
    local node_at_target_pos = minetest.get_node(target_pos).name
    local target_node_walkable = minetest.registered_nodes[node_at_target_pos].walkable

    if target_node_walkable then
        if minetest.registered_nodes[node_at_next_pos].walkable then
            user:set_pos(player_pos) 
            grappling_hooks[player_name] = nil
        else
            user:set_pos(next_pos)
        end
        if current_dist <= STOP_DISTANCE then
            user:set_pos(target_pos)
            grappling_hooks[player_name] = nil
        end
    else
        user:set_pos(player_pos)
        grappling_hooks[player_name] = nil
    end
end

minetest.register_globalstep(function(dtime)
    for player_name, data in pairs(grappling_hooks) do
        local elapsed_time = minetest.get_gametime() - data.last_move_time
        data.speed = math.max(data.speed - (elapsed_time * 0.05), MIN_SPEED)
        update_grappling_hook(player_name, data)
    end
end)

minetest.register_craft({
    output = "metallicum:grappling_hook",
    recipe = {
        {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
        {"metallicum:ingot", "default:stick", "metallicum:ingot"},
        {"", "default:stick", ""},
    },
})


-- titanium boots
minetest.register_tool("metallicum:boots", {
    description = "Titanium Boots",
    inventory_image = "metallicum_titanium_boot.png",
})

local function apply_speed(player)
    if player then
        local speed = player:get_physics_override().speed or 1.0
        player:set_physics_override({speed = speed + 1.0})
    end
end

minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local item = player:get_wielded_item()
        if item:get_name() == "metallicum:boots" then
            local speed = player:get_physics_override().speed
            if speed == 1.0 then
                minetest.after(0, function() apply_speed(player) end)
            end
        elseif player:get_physics_override().speed > 1.0 then
            player:set_physics_override({speed = 1.0})
        end
    end
end)

minetest.register_craft({
    output = "metallicum:boots", 
    recipe = {
        {"", "", ""},
        {"metallicum:ingot", "", "metallicum:ingot"},
        {"metallicum:ingot", "", "metallicum:ingot"},
    },
})

-- mining laser
minetest.register_tool("metallicum:mining_laser", {
    description = "Mining Laser",
    inventory_image = "metallicum_laser_gun.png",
    wear = 0,

    on_use = function(itemstack, user, pointed_thing)
        if itemstack:get_wear() < 65535 then
            if pointed_thing.type == "node" then
                local pos = pointed_thing.under
                local start_pos = {x = pos.x, y = pos.y, z = pos.z}
                
                minetest.add_particlespawner({
                    amount = 10,
                    time = 0.5,
                    minpos = start_pos,
                    maxpos = start_pos,
                    minvel = {x = -1, y = 1, z = -1},
                    maxvel = {x = 1, y = 1, z = 1},
                    minsize = 0.5,
                    maxsize = 1,
                    texture = "metallicum_fire.png",
                })

                for x = -1, 1 do
                    for y = -1, 1 do
                        for z = -1, 1 do
                            local target_pos = {x = start_pos.x + x, y = start_pos.y + y, z = start_pos.z + z}
                            local node = minetest.get_node(target_pos)
                            
                            local item_name = minetest.registered_nodes[node.name].drop
                            
                            if item_name then
                                local itemstack_dropped = ItemStack(item_name)
                                
                                if user:get_inventory():room_for_item("main", itemstack_dropped) then
                                    user:get_inventory():add_item("main", itemstack_dropped)
                                else
                                    minetest.add_item(target_pos, itemstack_dropped)
                                end
                            end
                            
                            minetest.node_dig(target_pos, node, user)
                        end
                    end
                end
            end

            itemstack:set_wear(itemstack:get_wear() + 2000)
        else
            minetest.chat_send_player(user:get_player_name(), "The Mining Laser is out of durability!")
            itemstack:take_item()
        end

        return itemstack
    end,
})

minetest.register_craft({
    output = "metallicum:mining_laser",
    recipe = {
        {"default:steel_ingot", "metallicum:ingot", ""},
        {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
        {"", "", "default:stick"},
    },
})


--titanium tools
register_tool("metallicum:pick", "Titanium Pickaxe", "metallicum_titanium_pick.png", {
    max_drop_level = 3,
    groupcaps = {
        cracky = {times = {[1] = 1.50, [2] = 0.90, [3] = 0.50}, uses = 2500, maxlevel = 3},
    },
    damage_groups = {fleshy = 15},
    durability = 2500,
}, {
    {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
    {"", "default:stick", ""},
    {"", "default:stick", ""},
})

register_tool("metallicum:katana", "Katana", "metallicum_katana.png", {
    max_drop_level = 1,
    groupcaps = {
        snappy = {times = {[1] = 0.25, [2] = 0.30, [3] = 0.10}, uses = 2000, maxlevel = 1},
    },
    damage_groups = {fleshy = 35},
    durability = 2000,
}, {
    {"","metallicum:ingot",""},
    {"","metallicum:ingot",""},
    {"","default:stick",""},
})

register_tool("metallicum:axe", "Titanium Axe", "metallicum_titanium_axe.png", {
    max_drop_level = 3,
    groupcaps = {
        choppy = {times = {[1] = 2.50, [2] = 1.80, [3] = 1.20}, uses = 2500, maxlevel = 4},
    },
    damage_groups = {fleshy = 20},
    durability = 2500,
}, {
    {"metallicum:ingot", "metallicum:ingot", ""},
    {"metallicum:ingot", "default:stick", ""},
    {"", "default:stick", ""},
})

register_tool("metallicum:brass_knuckles", "Brass Knuckles", "metallicum_knuckles.png", {
    max_drop_level = 3,
    groupcaps = {
        choppy = {times = {[1] = 2.50, [2] = 1.80, [3] = 1.20}, uses = 2500, maxlevel = 4},
    },
    damage_groups = {fleshy = 20},
    durability = 2500,
}, {
    {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
    {"metallicum:ingot", "", "metallicum:ingot"},
    {"", "metallicum:ingot", ""},
})

register_tool("metallicum:shovel", "Titanium Shovel", "metallicum_titanium_shovel.png", {
    max_drop_level = 2,
    groupcaps = {
        snappy = {times = {[1] = 0.50, [2] = 0.30, [3] = 0.10}, uses = 2000, maxlevel = 1},
    },
    damage_groups = {fleshy = 18},
    durability = 2000,
}, {
    {"","metallicum:ingot",""},
    {"","default:stick",""},
    {"","default:stick",""},
})

-- Freeze Gun
minetest.register_tool("metallicum:freeze_gun", {
    description = "Freeze Gun",
    inventory_image = "metallicum_freeze.png", 
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = user:get_pos()
            local dir = user:get_look_dir()
            local offset = 2  
            local spawn_pos = vector.add(pos, vector.multiply(dir, offset))
            local velocity = 20 

            local projectile = minetest.add_entity(spawn_pos, "metallicum:bullet")
            projectile:set_velocity({
                x = dir.x * velocity,
                y = dir.y * velocity,
                z = dir.z * velocity
            })

            itemstack:add_wear(65535 / 50)  
        end
        return itemstack
    end,
})

minetest.register_entity("metallicum:bullet", {
    hp_max = 1,
    physical = true,
    visual = "sprite",
    visual_size = {x = 0.2, y = 0.2},
    textures = {"metallicum_snow.png"},
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if pos then
            local velocity = self.object:get_velocity()
            velocity.y = velocity.y - 9.8 * dtime  
            self.object:set_velocity(velocity)

            local node_pos = vector.new(math.floor(pos.x), math.floor(pos.y), math.floor(pos.z))
            local node = minetest.get_node(node_pos)

            minetest.log("action", "Bullet hits node: " .. minetest.get_node(node_pos).name)

            if node.name == "default:dirt" or node.name == "default:sand" then
                minetest.set_node(node_pos, {name = "default:snowblock"})
            end

            self.object:remove()

            minetest.add_particle({
                pos = pos,
                velocity = {x = 0, y = 2, z = 0},
                acceleration = {x = 0, y = -10, z = 0},
                expirationtime = 1,
                size = 5,
                texture = "metallicum_snow.png",
                glow = 14,
            })
        end
    end,
})

minetest.register_craft({
    output = "metallicum:freeze_gun",
    recipe = {
        {"default:steel_ingot", "default:steel_ingot", ""},
        {"metallicum:ingot", "default:snowblock", "metallicum:ingot"},
        {"", "", "default:stick"},
    },
})

--Freeze Blast
minetest.register_craftitem("metallicum:freeze_blast", {
    description = "Freeze Blast",
    inventory_image = "metallicum_freeze_blast.png",
    on_use = function(itemstack, user, pointed_thing)
        local dir = user:get_look_dir()
        local velocity = 15 
        local pos = user:get_pos()

        local object = minetest.add_entity(pos, "metallicum:freeze_blast_entity")
        if object then
            object:set_velocity({
                x = dir.x * velocity,
                y = dir.y * velocity + 2,
                z = dir.z * velocity
            })
            object:set_acceleration({x = 0, y = -9.8, z = 0}) 
        end

        itemstack:take_item()
        return itemstack
    end,
})

minetest.register_entity("metallicum:freeze_blast_entity", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        visual = "sprite",
        visual_size = {x = 0.5, y = 0.5},
        textures = {"metallicum_freeze_blast.png"},
    },

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        local velocity = self.object:get_velocity()

        if math.abs(velocity.x) < 0.1 and math.abs(velocity.y) < 0.1 and math.abs(velocity.z) < 0.1 then
            self.object:set_velocity({x = 0, y = 0, z = 0})
        end

        local dir = vector.normalize(velocity)
        local distance_check = 0.5  

        local check_pos = vector.add(pos, vector.multiply(dir, distance_check))
        local node_name = minetest.get_node(check_pos).name

        if minetest.registered_nodes[node_name] and minetest.registered_nodes[node_name].walkable then
            create_ice_explosion(pos)

            self.object:remove()
        end
    end,
})

function create_ice_explosion(pos)
    local radius = 3
    for x = -radius, radius do
        for y = -radius, radius do
            for z = -radius, radius do
                local p = {x = pos.x + x, y = pos.y + y, z = pos.z + z}
                if minetest.get_node(p).name ~= "air" then
                    minetest.set_node(p, {name = "default:ice"})
                end
            end
        end
    end
end

minetest.register_craft({
    output = "metallicum:freeze_blast",
    recipe = {
        {"", "metallicum:ingot", ""},
        {"metallicum:ingot", "default:ice", "metallicum:ingot"},
        {"", "metallicum:ingot", ""},
    },
})

-- line launcher
local line_launchers = {}
local max_distance = 50 
local max_angle = 45 

minetest.register_tool("metallicum:line_launcher", {
    description = "Line Launcher",
    inventory_image = "metallicum_line_launcher.png",
    on_use = function(itemstack, user, pointed_thing)
        if pointed_thing.type == "node" then
            local target_pos = pointed_thing.under
            local player_pos = user:get_pos()

            local dir = vector.subtract(target_pos, player_pos)
            local dist = vector.length(dir)
            dist = math.min(dist, max_distance)

            if dist < 0.1 then
                return itemstack
            end
            local horizontal_dir = vector.new(dir.x, 0, dir.z)
            local horizontal_length = vector.length(horizontal_dir)
            horizontal_dir = vector.normalize(horizontal_dir)
            local angle = math.deg(math.acos(vector.dot(horizontal_dir, vector.normalize(dir))))
            if angle > max_angle then
                minetest.chat_send_player(user:get_player_name(), "The angle is too big for the movement!")
                return itemstack
            end

            dir = vector.normalize(dir)
            local speed = math.min(1.5, dist * 0.05)

            line_launchers[user:get_player_name()] = {
                target_pos = target_pos,
                current_pos = player_pos,
                dir = dir,
                speed = speed,
                distance = dist,
                last_move_time = minetest.get_gametime(),
            }
        end
        return itemstack
    end,
})

local function update_line_launcher(player_name, data)
    local user = minetest.get_player_by_name(player_name)
    if user then
        local player_pos = user:get_pos()
        local target_pos = data.target_pos
        local dir = data.dir
        local speed = data.speed
        local dist = data.distance
        local current_dist = vector.distance(player_pos, target_pos)
        current_dist = math.min(current_dist, max_distance)
        local new_speed = math.min(speed, current_dist * 0.1)
        local move_dir = vector.multiply(dir, new_speed)
        local next_pos = vector.add(player_pos, move_dir)
        local node_at_next_pos = minetest.get_node(next_pos).name
        if minetest.registered_nodes[node_at_next_pos].walkable then
            user:set_pos(player_pos)
            line_launchers[player_name] = nil
        else
            user:set_pos(next_pos)
        end

        if current_dist <= 0.1 then
            user:set_pos(target_pos)
            line_launchers[player_name] = nil
        end
    end
end

minetest.register_globalstep(function(dtime)
    for player_name, data in pairs(line_launchers) do
        local elapsed_time = minetest.get_gametime() - data.last_move_time
        local new_speed = data.speed - (elapsed_time * 0.05)
        data.speed = math.max(new_speed, 0.5)

        update_line_launcher(player_name, data)
    end
end)

minetest.register_craft({
    output = "metallicum:line_launcher",
    recipe = {
        {"metallicum:ingot", "metallicum:ingot", "metallicum:ingot"},
        {"", "default:stick", ""},
        {"", "metallicum:ingot", ""},
    },
})


-- Spear (not implemented...)
minetest.register_craftitem("metallicum:titanium_spear", {
    description = "Titanium Spear",
    inventory_image = "metallicum_titanium_spear.png",
    on_use = function(itemstack, user, pointed_thing)
        local pos = vector.add(user:get_pos(), {x=0, y=1.5, z=0})
        local dir = user:get_look_dir()
        local obj = minetest.add_entity(vector.add(pos, vector.multiply(dir, 1.2)), "metallicum:spear_entity")
        if obj then
            -- Velocità iniziale
            local velocity = vector.multiply(dir, 16)
            obj:set_velocity(velocity)
            -- Gravità
            obj:set_acceleration({x=0, y=-4, z=0})
            local yaw = math.atan2(dir.z, dir.x)
            obj:set_yaw(yaw)
            obj:set_properties({physical = true, collide_with_objects = true})
        end
        itemstack:take_item()
        return itemstack
    end,
})

minetest.register_entity("metallicum:spear_entity", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.2, -0.2, -0.2, 0.2, 0.2, 0.2},
        visual = "sprite",
        textures = {"metallicum_titanium_spear.png"},
    },
    on_activate = function(self, staticdata)
        self.initial_pos = self.object:get_pos()
    end,
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        local objs = minetest.get_objects_inside_radius(pos, 1.0)
        for _, obj in ipairs(objs) do
            if obj:is_player() then
                obj:punch(self.object, 1.0, {
                    full_punch_interval = 1.0,
                    damage_groups = {fleshy = 6},  
                }, nil)
                self.object:remove()
                break
            end
        end

        local dist = vector.distance(pos, self.initial_pos)
        if dist > 10 then 
            self.object:remove()
            local spawn_pos = self.initial_pos or {x=0, y=0, z=0}
            minetest.add_item(spawn_pos, "metallicum:titanium_spear")
        end
    end,

    on_punch = function(self, puncher, time_from_last_punch, tool_caps, dir)
        if not self.object then return end 
        local pos = self.object:get_pos() 
        self.object:remove()

        minetest.add_item(pos, "metallicum:titanium_spear") 
    end,
})




-- not a big triumph :/