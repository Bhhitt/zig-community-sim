const std = @import("std");
const Agent = @import("agent.zig").Agent;
const AgentType = @import("agent.zig").AgentType;
const Interaction = @import("agent.zig").Interaction;
const InteractionType = @import("agent.zig").InteractionType;
const Map = @import("map.zig").Map;
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
    interactions: std.ArrayList(Interaction),
    next_agent_id: usize,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Simulation {
        return Simulation{
            .map = try Map.init(allocator, width, height),
            .agents = std.ArrayList(Agent).init(allocator),
            .interactions = std.ArrayList(Interaction).init(allocator),
            .next_agent_id = 0,
        };
    }

    pub fn deinit(self: *Simulation) void {
        self.map.deinit();
        self.agents.deinit();
        self.interactions.deinit();
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
        try self.map.print(self.agents.items, self.interactions.items);
    }
    
    pub fn printStats(self: Simulation) void {
        std.debug.print("Stats: {d} agents, {d} active interactions\n", 
            .{self.agents.items.len, self.interactions.items.len});
    }

    pub fn saveMapToFile(self: Simulation, filename: []const u8) !void {
        try self.map.saveToFile(self.agents.items, self.interactions.items, filename);
    }

    pub fn findNearbyAgent(self: Simulation, agent: Agent, max_distance: usize) ?*const Agent {
        for (self.agents.items) |*other| {
            if (other.id == agent.id) continue; // Skip self

            const dx = if (other.x > agent.x) other.x - agent.x else agent.x - other.x;
            const dy = if (other.y > agent.y) other.y - agent.y else agent.y - other.y;

            // Manhattan distance
            if (dx + dy <= max_distance) {
                return other;
            }
        }
        return null;
    }

    fn isInteracting(self: Simulation, agent_id: usize) bool {
        for (self.interactions.items) |interaction| {
            if (interaction.agent1_id == agent_id or interaction.agent2_id == agent_id) {
                return true;
            }
        }
        return false;
    }

    pub fn chooseInteractionType(self: *const Simulation, agent1: Agent, agent2: Agent) InteractionType {
        _ = self; // Unused parameter, but needed for method syntax
        // Different agent types prefer different interactions
        // Use a combination of agent seeds for randomness
        const combined_seed = agent1.seed ^ agent2.seed;
        const random_value = @mod(combined_seed, 100);

        if (agent1.type == agent2.type) {
            // Same type agents have specific preferences
            return switch (agent1.type) {
                .Settler => if (random_value < 70) .Greeting else .Collaboration,
                .Explorer => if (random_value < 60) .Trading else .Greeting,
                .Builder => if (random_value < 80) .Collaboration else .Trading,
                .Farmer => if (random_value < 65) .Resource else .Trading,
                .Miner => if (random_value < 75) .Resource else .Collaboration,
                .Scout => if (random_value < 80) .Teaching else .Trading,
            };
        } else {
            // Interactions between different agent types
            if (agent1.type == .Scout or agent2.type == .Scout) {
                // Scouts share information with others
                return if (random_value < 70) .Teaching else .Greeting;
            } else if (agent1.type == .Explorer or agent2.type == .Explorer) {
                // Explorers prefer trading with others
                return if (random_value < 60) .Trading else .Greeting;
            } else if (agent1.type == .Farmer or agent2.type == .Farmer) {
                // Farmers provide resources to others
                return if (random_value < 65) .Resource else .Trading;
            } else if (agent1.type == .Miner or agent2.type == .Miner) {
                // Miners provide resources but also collaborate on projects
                return if (random_value < 50) .Resource else .Collaboration;
            } else if (agent1.type == .Builder or agent2.type == .Builder) {
                // Builders generally prefer collaboration with others
                return if (random_value < 70) .Collaboration else .Trading;
            } else {
                // Settlers default to greeting
                return .Greeting;
            }
        }
    }

    pub fn updateInteractions(self: *Simulation) !void {
        // Use timestamp as simple random source instead of rand module

        // Remove expired interactions
        var i: usize = 0;
        while (i < self.interactions.items.len) {
            if (self.interactions.items[i].duration == 0) {
                _ = self.interactions.swapRemove(i);
            } else {
                self.interactions.items[i].duration -= 1;
                i += 1;
            }
        }

        // Check for new possible interactions
        for (self.agents.items) |agent| {
            // Skip if agent is already interacting
            if (self.isInteracting(agent.id)) continue;

            // Look for nearby agents to interact with
            if (self.findNearbyAgent(agent, 1)) |nearby_agent| {
                // Skip if the other agent is already in an interaction
                if (self.isInteracting(nearby_agent.id)) continue;

                // Create a new interaction based on agent types
                const interaction_type = self.chooseInteractionType(agent, nearby_agent.*);
                const interaction = Interaction.init(agent, nearby_agent.*, interaction_type);
                try self.interactions.append(interaction);

                // Each agent can only be in one interaction at a time
                break;
            }
        }
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
            const is_interacting = simulation.isInteracting(agents[i].id);
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
                if (!self.isInteracting(agent.id)) {
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
        try self.updateInteractions();
    }
};
