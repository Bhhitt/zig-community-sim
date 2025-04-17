const std = @import("std");
const Agent = @import("agent").Agent;
const AgentType = @import("agent_type").AgentType;
const Map = @import("map").Map;
const InteractionSystem = @import("interactions").InteractionSystem;
const TerrainGenerator = @import("terrain").TerrainGenerator;
const Thread = std.Thread;

const max_agents = 100000; // Increased to handle stress tests
const thread_count = 10; // Number of threads to use for agent updates

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

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Simulation {
        // Create map
        const map = try Map.init(allocator, width, height);
        
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
        const agent = Agent.init(self.next_agent_id, config.x, config.y, config.type, config.health, config.energy);

        try self.agents.append(agent);
        self.next_agent_id += 1;
    }

    pub fn printMap(self: Simulation) !void {
        try self.map.print(self.agents.items, self.interaction_system.getInteractions());
    }
    
    pub fn printStats(self: Simulation) void {
        std.debug.print("Stats: {d} agents, {d} active interactions\n", 
            .{self.agents.items.len, self.interaction_system.getInteractions().len});
    }

    pub fn saveMapToFile(self: Simulation, filename: []const u8) !void {
        try self.map.saveToFile(self.agents.items, self.interaction_system.getInteractions(), filename);
    }

    // Worker thread function to update a batch of agents
    fn updateAgentBatch(context: *AgentUpdateContext) void {
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
                agents[i].update(&simulation.map);

                // Map bounds are now checked within the agent update, but just to be safe
                if (agents[i].x >= simulation.map.width) {
                    agents[i].x = simulation.map.width - 1;
                }
                if (agents[i].y >= simulation.map.height) {
                    agents[i].y = simulation.map.height - 1;
                }
            }
        }
    }

    pub fn update(self: *Simulation) !void {
        const agent_count = self.agents.items.len;

        // Skip threading if very few agents
        if (agent_count < thread_count * 2) {
            // Use original single-threaded approach for small agent counts
            for (self.agents.items) |*agent| {
                if (!self.interaction_system.isAgentInteracting(agent.id)) {
                    agent.update(&self.map);

                    // Map bounds are now checked within the agent update, but just to be safe
                    if (agent.x >= self.map.width) {
                        agent.x = self.map.width - 1;
                    }
                    if (agent.y >= self.map.height) {
                        agent.y = self.map.height - 1;
                    }
                }
            }
        } else {
            // Use multi-threaded approach for larger agent counts
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

                threads[i] = try Thread.spawn(.{}, updateAgentBatch, .{&contexts[i]});
            }

            // Wait for all threads to complete
            for (0..thread_count) |i| {
                if (i * batch_size < agent_count) {
                    threads[i].join();
                }
            }
        }

        // Update interactions (this remains single-threaded for simplicity)
        try self.interaction_system.update(self.agents.items);
    }
};