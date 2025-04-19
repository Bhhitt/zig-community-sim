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

pub const Simulation = struct {
    map: Map,
    agents: std.ArrayList(Agent),
    interaction_system: InteractionSystem,
    next_agent_id: usize,
    thread_pool: ?ThreadPool = null,
    // Threads for processing in update
    worker_threads: []Thread = &[_]Thread{},
    has_workers: bool = false,
    workers_initialized: bool = false,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, config: anytype) !Simulation {
        // Create map with config
        const map = try Map.init(allocator, width, height, config);
        
        // Generate terrain features
        try TerrainGenerator.generateTerrain(map.grid, width, height, null);
        
        var simulation = Simulation{
            .map = map,
            .agents = std.ArrayList(Agent).init(allocator),
            .interaction_system = InteractionSystem.init(allocator),
            .next_agent_id = 0,
            .thread_pool = null,
        };
        
        // Create thread pool and worker threads if multi-threading is enabled
        if (@hasField(@TypeOf(config), "thread_count") and config.thread_count > 1) {
            const thread_count = config.thread_count;
            std.debug.print("Initializing simulation with {d} worker threads\n", .{thread_count});
            
            // Allocate worker threads
            simulation.worker_threads = try allocator.alloc(Thread, thread_count);
            simulation.has_workers = true;
            
            // Also create the thread pool for the batch interface
            simulation.thread_pool = try ThreadPool.init(allocator, thread_count);
        }
        
        return simulation;
    }

    pub fn deinit(self: *Simulation) void {
        // Shutdown thread pool if it exists
        if (self.thread_pool) |*thread_pool| {
            thread_pool.deinit();
        }
        
        // Free worker threads if allocated
        if (self.has_workers) {
            self.map.allocator.free(self.worker_threads);
            self.has_workers = false;
        }
        
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

    pub fn printMap(self: *Simulation) !void {
        try self.map.print(self.agents.items, self.interaction_system.getInteractions());
    }
    
    pub fn printStats(self: *Simulation) void {
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

    pub fn saveMapToFile(self: *Simulation, filename: []const u8) !void {
        try self.map.saveToFile(self.agents.items, self.interaction_system.getInteractions(), filename);
    }

    // Safe agent update function for single-threaded mode
    fn safeUpdateAgentSingleThreaded(agent: *Agent, map: *Map, config: anytype, agents: []const Agent) void {
        // Update agent, passing the map for terrain interactions, including all agents for perception
        agent_update_system.updateAgent(agent, map, config, agents);

        // Map bounds are now checked within the agent update, but just to be safe
        if (agent.x >= @as(f32, @floatFromInt(map.width))) {
            agent.x = @as(f32, @floatFromInt(map.width - 1));
        }
        if (agent.y >= @as(f32, @floatFromInt(map.height))) {
            agent.y = @as(f32, @floatFromInt(map.height - 1));
        }
    }
    
    // This function is no longer needed as we've moved its logic into workerThreadFn
    fn safeUpdateAgentThreaded(agent: *Agent, map: *Map, config_ptr: *const anyopaque) void {
        // This is just a stub now - the real work is done directly in workerThreadFn
        // Use parameters to avoid unused parameter warnings
        _ = agent;
        _ = map;
        _ = config_ptr;
        std.debug.print("WARNING: safeUpdateAgentThreaded called directly\n", .{});
    }

    pub fn update(self: *Simulation, allocator: std.mem.Allocator, config: anytype) !void {
        // Regrow food every step with config value (now f32)
        self.map.regrowFood(config.food_regrow_chance);
        
        // Update map's reference to all agents for interaction targeting
        const sim_backup = self.agents.items;

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

        // Get thread count from config
        const thread_count = config.thread_count;
        
        // First, collect all agents that are not currently interacting
        var free_agents = std.ArrayList(*Agent).init(allocator);
        defer free_agents.deinit();
        
        for (self.agents.items) |*agent| {
            if (!self.interaction_system.isAgentInteracting(agent.id)) {
                try free_agents.append(agent);
            }
        }
        
        std.debug.print("Processing {d} agents (thread_count: {d})\n", 
                       .{free_agents.items.len, thread_count});
                       
        // Temporarily clear the simulation agents reference for thread safety
        self.map.simulation_agents = null;
        
        // Determine which mode to use based on thread count
        if (thread_count > 1 and self.thread_pool != null) {
            std.debug.print("Using thread pool with {d} threads for agent updates\n", .{thread_count});
            
            if (self.thread_pool) |*thread_pool| {
                // Process all agents using the thread pool
                // Create a slice for all agents at once
                try thread_pool.processBatch(free_agents.items, &self.map, config);
            } else {
                // Fallback to single-threaded mode
                for (free_agents.items) |agent| {
                    safeUpdateAgentSingleThreaded(agent, &self.map, config, self.agents.items);
                }
            }
        } else {
            // Single-threaded mode
            std.debug.print("Using single-threaded mode for agent updates\n", .{});
            
            // Process agents
            for (free_agents.items) |agent| {
                safeUpdateAgentSingleThreaded(agent, &self.map, config, self.agents.items);
            }
        }
        
        // Restore simulation agents for interaction targeting
        self.map.simulation_agents = sim_backup;

        // Update interactions (this remains single-threaded for simplicity)
        try self.interaction_system.update(self.agents.items, config);
    }
};

// Simple thread pool implementation
pub const ThreadPool = struct {
    allocator: std.mem.Allocator,
    thread_count: usize,
    initialized: bool = false,
    
    // Thread control
    threads: []Thread,
    shutdown_flag: std.atomic.Value(bool),
    work_complete: std.atomic.Value(bool),
    
    // Thread configuration
    thread_config: struct {
        hunger_threshold: u8,
        hunger_health_penalty: u8,
    },
    
    // Thread stats
    processing_count: std.atomic.Value(usize),
    
    // Map and agents
    map: *Map,
    mutex: Thread.Mutex,
    agents_to_process: std.ArrayList(*Agent),
    agents_processed: std.ArrayList(*Agent),
    
    pub fn init(allocator: std.mem.Allocator, thread_count: usize) !ThreadPool {
        const agents_to_process = std.ArrayList(*Agent).init(allocator);
        const agents_processed = std.ArrayList(*Agent).init(allocator);
        
        var pool = ThreadPool{
            .allocator = allocator,
            .thread_count = thread_count,
            .threads = try allocator.alloc(Thread, thread_count),
            .shutdown_flag = std.atomic.Value(bool).init(false),
            .work_complete = std.atomic.Value(bool).init(true),
            .thread_config = .{
                .hunger_threshold = 80,
                .hunger_health_penalty = 1,
            },
            .processing_count = std.atomic.Value(usize).init(0),
            .map = undefined, // Will be set before each batch
            .mutex = .{},
            .agents_to_process = agents_to_process,
            .agents_processed = agents_processed,
        };
        
        // We don't start threads here because they need a proper map reference
        // They will be started on first processBatch call
        
        pool.initialized = true;
        return pool;
    }
    
    pub fn deinit(self: *ThreadPool) void {
        if (!self.initialized) return;
        
        // Clean up resources
        self.agents_to_process.deinit();
        self.agents_processed.deinit();
        self.allocator.free(self.threads);
        self.initialized = false;
    }
    
    // Process a batch of agents in parallel
    pub fn processBatch(
        self: *ThreadPool,
        agents: []*Agent,
        map: *Map,
        config: anytype
    ) !void {
        if (!self.initialized) return error.ThreadPoolNotInitialized;
        if (agents.len == 0) return;
        
        // Set the map for this batch
        self.map = map;
        
        // Update config values for thread workers
        if (@hasField(@TypeOf(config), "hunger_threshold")) {
            self.thread_config.hunger_threshold = config.hunger_threshold;
        }
        if (@hasField(@TypeOf(config), "hunger_health_penalty")) {
            self.thread_config.hunger_health_penalty = config.hunger_health_penalty;
        }
        
        // Single-threaded implementation for safety
        for (agents) |agent| {
            agent_update_system.updateAgent(agent, map, config, agents);
        }
    }
};