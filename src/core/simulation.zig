const std = @import("std");
const AgentType = @import("agent").AgentType;
const Agent = @import("agent").Agent;
const Map = @import("map").Map;
const InteractionSystem = @import("interactions").InteractionSystem;
const TerrainGenerator = @import("terrain").TerrainGenerator;
const Thread = std.Thread;
const agent_update_system = @import("agent_update_system");
const AgentTypeFields = @import("agent_type").AgentTypeFields;

const max_agents = 100000; // Increased to handle stress tests

// Number of threads to use for agent updates is now configurable via config.thread_count

// Thread context for parallel agent updates
const AgentUpdateContext = struct {
    agents: []Agent,
    simulation: *Simulation,
    start_index: usize,
    end_index: usize,
    mutex: *Thread.Mutex,
};

pub const Simulation = struct {
    map: Map,
    agents: std.ArrayList(Agent),
    interaction_system: InteractionSystem,
    next_agent_id: usize,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, config: anytype) !Simulation {
        // Create map with config
        const map = try Map.init(allocator, width, height, config);
        
        // Generate terrain features
        try TerrainGenerator.generateTerrain(map.grid, width, height, null);
        
        return Simulation{
            .map = map,
            .agents = std.ArrayList(Agent).init(allocator),
            .interaction_system = InteractionSystem.init(allocator),
            .next_agent_id = 0,
        };
    }

    pub fn deinit(self: *Simulation) void {
        self.map.deinit();
        self.agents.deinit();
        self.interaction_system.deinit();
    }

    pub fn spawnAgent(self: *Simulation, config: struct {
        x: usize,
        y: usize,
        type: AgentType,
        health: u8 = 100,
        energy: u8 = 100,
    }) !void {
        const agent = Agent.init(self.next_agent_id, @floatFromInt(config.x), @floatFromInt(config.y), config.type, config.health, config.energy);

        try self.agents.append(agent);
        self.next_agent_id += 1;
    }

    pub fn printMap(self: Simulation) !void {
        try self.map.print(self.agents.items, self.interaction_system.getInteractions());
    }
    
    pub fn printStats(self: Simulation) void {
        const agent_count = self.agents.items.len;
        const interaction_count = self.interaction_system.getInteractions().len;
        var type_counts = [_]usize{0} ** AgentTypeFields.len;
        for (self.agents.items) |agent| {
            type_counts[@intFromEnum(agent.type)] += 1;
        }
        std.debug.print("Agents: {d} [", .{agent_count});
        var i: usize = 0;
        inline for (AgentTypeFields) |field| {
            const tag = @as(AgentType, @enumFromInt(field.value));
            const symbol = AgentType.getSymbol(tag);
            std.debug.print("{c}:{d}{s}", .{symbol, type_counts[i], if (i + 1 == AgentTypeFields.len) "]" else " "});
            i += 1;
        }
        std.debug.print(" | Interactions: {d}", .{interaction_count});
    }

    pub fn saveMapToFile(self: Simulation, filename: []const u8) !void {
        try self.map.saveToFile(self.agents.items, self.interaction_system.getInteractions(), filename);
    }

    // Worker thread function to update a batch of agents
    fn updateAgentBatch(context: *AgentUpdateContext, config: anytype) void {
        const agents = context.agents;
        const simulation = context.simulation;
        const start = context.start_index;
        const end = context.end_index;

        for (start..end) |i| {
            // Locking the mutex to safely check interaction status
            context.mutex.lock();
            const is_interacting = simulation.interaction_system.isAgentInteracting(agents[i].id);
            context.mutex.unlock();

            if (!is_interacting) {
                // Update agent, passing the map for terrain interactions
                agent_update_system.updateAgent(&agents[i], &simulation.map, config, agents);

                // Map bounds are now checked within the agent update, but just to be safe
                if (agents[i].x >= @as(f32, @floatFromInt(simulation.map.width))) {
                    agents[i].x = @as(f32, @floatFromInt(simulation.map.width - 1));
                }
                if (agents[i].y >= @as(f32, @floatFromInt(simulation.map.height))) {
                    agents[i].y = @as(f32, @floatFromInt(simulation.map.height - 1));
                }
            }
        }
    }

    pub fn update(self: *Simulation, allocator: std.mem.Allocator, config: anytype) !void {
        // Regrow food every step with config value (now f32)
        self.map.regrowFood(config.food_regrow_chance);

        const agent_count = self.agents.items.len;

        // Remove dead agents before update (health == 0)
        var remove_idx: usize = 0;
        while (remove_idx < self.agents.items.len) {
            if (self.agents.items[remove_idx].health == 0) {
                _ = self.agents.swapRemove(remove_idx);
                // Don't increment remove_idx, as swapRemove places a new agent at remove_idx
            } else {
                remove_idx += 1;
            }
        }

        // Skip threading if very few agents
        if (agent_count < config.thread_count * 2) {
            // Use original single-threaded approach for small agent counts
            var idx: usize = 0;
            for (self.agents.items) |*agent| {
                if (!self.interaction_system.isAgentInteracting(agent.id)) {
                    agent_update_system.updateAgent(agent, &self.map, config, self.agents.items);

                    // Map bounds are now checked within the agent update, but just to be safe
                    if (agent.x >= @as(f32, @floatFromInt(self.map.width))) {
                        agent.x = @as(f32, @floatFromInt(self.map.width - 1));
                    }
                    if (agent.y >= @as(f32, @floatFromInt(self.map.height))) {
                        agent.y = @as(f32, @floatFromInt(self.map.height - 1));
                    }
                }
                idx += 1;
            }
        } else {
            // Use multi-threaded approach for larger agent counts
            var mutex = Thread.Mutex{};
            var threads = try allocator.alloc(Thread, config.thread_count);
            defer allocator.free(threads);
            var contexts = try allocator.alloc(AgentUpdateContext, config.thread_count);
            defer allocator.free(contexts);

            const batch_size = (self.agents.items.len + config.thread_count - 1) / config.thread_count; // Ceiling division

            // Create and start threads
            for (0..config.thread_count) |thread_idx| {
                const start = thread_idx * batch_size;
                const end = @min(start + batch_size, self.agents.items.len);
                contexts[thread_idx] = AgentUpdateContext{
                    .agents = self.agents.items,
                    .simulation = self,
                    .start_index = start,
                    .end_index = end,
                    .mutex = &mutex,
                };
                threads[thread_idx] = try Thread.spawn(.{}, updateAgentBatch, .{&contexts[thread_idx], config});
            }
            // Wait for all threads to complete
            for (0..config.thread_count) |thread_idx| {
                if (thread_idx * batch_size < self.agents.items.len) {
                    threads[thread_idx].join();
                }
            }
        }

        // Update interactions (this remains single-threaded for simplicity)
        try self.interaction_system.update(self.agents.items);
    }
};