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
const thread_count = 1; // Number of threads to use for agent updates (FORCE SINGLE-THREADED FOR DEBUG)

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
        std.debug.print("[DEBUG] spawnAgent called: id={} x={} y={} type={s} health={} energy={} agents.len={}\n", .{
            self.next_agent_id, config.x, config.y, @tagName(config.type), config.health, config.energy, self.agents.items.len
        });
        const agent = Agent.init(self.next_agent_id, config.x, config.y, config.type, config.health, config.energy);

        try self.agents.append(agent);
        self.next_agent_id += 1;
        std.debug.print("[DEBUG] Agent appended: id={} total_agents={}\n", .{agent.id, self.agents.items.len});
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
                agent_update_system.updateAgent(&agents[i], &simulation.map, config);

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

    pub fn update(self: *Simulation, config: anytype) !void {
        std.debug.print("[DEBUG] update called: agents.len={} map.size={}x{}\n", .{self.agents.items.len, self.map.width, self.map.height});
        // Regrow food every step with config value (now f32)
        self.map.regrowFood(config.food_regrow_chance);

        const agent_count = self.agents.items.len;

        // Skip threading if very few agents
        if (agent_count < thread_count * 2) {
            // Use original single-threaded approach for small agent counts
            var idx: usize = 0;
            for (self.agents.items) |*agent| {
                std.debug.print("[DEBUG] update: agent idx={} id={} pos=({}, {}) health={} energy={} type={s}\n", .{
                    idx, agent.id, agent.x, agent.y, agent.health, agent.energy, @tagName(agent.type)
                });
                if (!self.interaction_system.isAgentInteracting(agent.id)) {
                    agent_update_system.updateAgent(agent, &self.map, config);

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
            std.debug.print("[DEBUG] update: multi-threaded batch update\n", .{});
            var mutex = Thread.Mutex{};
            var threads: [thread_count]Thread = undefined;
            var contexts: [thread_count]AgentUpdateContext = undefined;

            const batch_size = (agent_count + thread_count - 1) / thread_count; // Ceiling division

            // Create and start threads
            for (0..thread_count) |i| {
                const start = i * batch_size;
                const end = @min(start + batch_size, agent_count);
                // Skip empty batches
                if (start >= agent_count) continue;
                contexts[i] = AgentUpdateContext{
                    .agents = self.agents.items,
                    .simulation = self,
                    .start_index = start,
                    .end_index = end,
                    .mutex = &mutex,
                };
                std.debug.print("[DEBUG] update: spawning thread {} for agents[{}..{})\n", .{i, start, end});
                threads[i] = try Thread.spawn(.{}, updateAgentBatch, .{&contexts[i], config});
            }
            // Wait for all threads to complete
            for (0..thread_count) |i| {
                if (i * batch_size < agent_count) {
                    threads[i].join();
                }
            }
        }
        std.debug.print("[DEBUG] update: calling interaction_system.update()\n", .{});
        // Update interactions (this remains single-threaded for simplicity)
        try self.interaction_system.update(self.agents.items);
    }
};