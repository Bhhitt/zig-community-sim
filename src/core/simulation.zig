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
        const agent = Agent.init(self.next_agent_id, @as(f32, @floatFromInt(config.x)), @as(f32, @floatFromInt(config.y)), config.type, config.health, config.energy);

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
    fn safeUpdateAgentSingleThreaded(agent: *Agent, map: *Map, config: anytype, all_agents: []Agent) void {
        // Update agent, passing the map for terrain interactions, including all agents for perception
        agent_update_system.updateAgent(agent, map, config, all_agents);

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
        perception_radius: usize,
        food_seek_aggressiveness_base: f32,
        food_seek_aggressiveness_hunger_coeff: f32,
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
                .perception_radius = 5,
                .food_seek_aggressiveness_base = 0.5,
                .food_seek_aggressiveness_hunger_coeff = 0.01,
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
        
        // Signal all worker threads to shut down
        self.shutdown_flag.store(true, .seq_cst);
        
        // Wait for a little while to allow threads to see the shutdown flag
        std.time.sleep(10 * std.time.ns_per_ms);
        
        // Free allocated resources
        self.agents_to_process.deinit();
        self.agents_processed.deinit();
        self.allocator.free(self.threads);
        self.initialized = false;
    }
    
    // Worker thread function that processes agents from the shared queue
    fn workerThreadFn(self: *ThreadPool, thread_id: usize, config_ptr: *const anyopaque) void {
        // We can't directly inspect anyopaque type, so we'll use our thread_config instead
        // This avoids issues with trying to get the type of an opaque pointer
        _ = config_ptr; // Acknowledge the parameter but don't use it directly
        
        std.debug.print("Worker thread {d} started\n", .{thread_id});
        
        // Process agents until work is complete or shutdown is requested
        while (!self.shutdown_flag.load(.seq_cst)) {
            // Get an agent to process
            const agent = self.getNextAgentToProcess();
            if (agent == null) {
                // No more work to do, check if we're done
                if (self.work_complete.load(.seq_cst)) {
                    break;
                }
                // Wait a bit before checking again (yield to other threads)
                std.time.sleep(1 * std.time.ns_per_ms);
                continue;
            }
            
            // Get a stable copy of all_agents for this thread
            const all_agents = self.map.simulation_agents orelse &[_]Agent{};
            
            // Safety check for valid agent
            if (agent) |valid_agent| {
                // Instead of using the passed in config which is now opaque,
                // we'll create a minimal config with the fields we need
                const thread_safe_config = struct {
                    hunger_threshold: u8,
                    hunger_health_penalty: u8,
                    perception_radius: usize,
                    food_seek_aggressiveness_base: f32,
                    food_seek_aggressiveness_hunger_coeff: f32,
                }{
                    .hunger_threshold = self.thread_config.hunger_threshold,
                    .hunger_health_penalty = self.thread_config.hunger_health_penalty,
                    .perception_radius = self.thread_config.perception_radius,
                    .food_seek_aggressiveness_base = self.thread_config.food_seek_aggressiveness_base,
                    .food_seek_aggressiveness_hunger_coeff = self.thread_config.food_seek_aggressiveness_hunger_coeff,
                };
                
                // Process the agent with our thread-safe configuration
                agent_update_system.updateAgent(valid_agent, self.map, thread_safe_config, all_agents);
                
                // Mark as processed
                self.mutex.lock();
                _ = self.processing_count.fetchSub(1, .seq_cst);
                self.agents_processed.append(valid_agent) catch {};
                self.mutex.unlock();
            }
        }
        
        std.debug.print("Worker thread {d} exiting\n", .{thread_id});
    }
    
    // Get the next agent to process from the queue
    fn getNextAgentToProcess(self: *ThreadPool) ?*Agent {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (self.agents_to_process.items.len == 0) {
            return null;
        }
        
        // Get the last agent (for efficiency, we're using it as a stack)
        const agent = self.agents_to_process.items[self.agents_to_process.items.len - 1];
        _ = self.agents_to_process.pop();
        _ = self.processing_count.fetchAdd(1, .seq_cst);
        
        return agent;
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
        if (@hasField(@TypeOf(config), "perception_radius")) {
            self.thread_config.perception_radius = config.perception_radius;
        }
        if (@hasField(@TypeOf(config), "food_seek_aggressiveness_base")) {
            self.thread_config.food_seek_aggressiveness_base = config.food_seek_aggressiveness_base;
        }
        if (@hasField(@TypeOf(config), "food_seek_aggressiveness_hunger_coeff")) {
            self.thread_config.food_seek_aggressiveness_hunger_coeff = config.food_seek_aggressiveness_hunger_coeff;
        }
        std.debug.print("Processing {d} agents using ThreadPool with {d} threads\n", 
            .{agents.len, self.thread_count});
            
        // Reset processing state
        self.agents_to_process.clearRetainingCapacity();
        self.agents_processed.clearRetainingCapacity();
        self.processing_count.store(0, .seq_cst);
        self.work_complete.store(false, .seq_cst);
        
        // Ensure we have capacity for all agents
        try self.agents_to_process.ensureTotalCapacity(agents.len);
        try self.agents_processed.ensureTotalCapacity(agents.len);
        
        // Add all agents to the processing queue
        for (agents) |agent| {
            try self.agents_to_process.append(agent);
        }
        
        // Start worker threads if not already running
        const config_ptr: *const anyopaque = @ptrCast(&config);
        
        // Create and start the worker threads
        for (0..self.thread_count) |i| {
            self.threads[i] = try Thread.spawn(.{}, workerThreadFn, .{self, i, config_ptr});
        }
        
        // Wait for all agents to be processed
        while (true) {
            const items_to_process = self.agents_to_process.items.len;
            const items_processing = self.processing_count.load(.seq_cst);
            
            if (items_to_process == 0 and items_processing == 0) {
                // All work is done
                self.work_complete.store(true, .seq_cst);
                break;
            }
            
            // Wait a bit before checking again
            std.time.sleep(1 * std.time.ns_per_ms);
        }
        
        // Wait for all threads to finish
        for (0..self.thread_count) |i| {
            self.threads[i].join();
        }
        
        std.debug.print("All {d} agents processed by ThreadPool\n", .{agents.len});
    }
};