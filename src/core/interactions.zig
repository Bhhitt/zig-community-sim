const std = @import("std");
const Agent = @import("agent").Agent;
const AgentType = @import("agent_type").AgentType;
const Interaction = @import("agent").Interaction;
const InteractionType = @import("interaction_type").InteractionType;

pub const InteractionSystem = struct {
    interactions: std.ArrayList(Interaction),
    mutex: std.Thread.Mutex = .{}, // Add mutex for thread safety
    
    pub fn init(allocator: std.mem.Allocator) InteractionSystem {
        return .{
            .interactions = std.ArrayList(Interaction).init(allocator),
        };
    }
    
    pub fn deinit(self: *InteractionSystem) void {
        self.interactions.deinit();
    }
    
    // Internal version without mutex locking
    fn isAgentInteractingInternal(self: *InteractionSystem, agent_id: usize) bool {
        for (self.interactions.items) |interaction| {
            if (interaction.agent1_id == agent_id or interaction.agent2_id == agent_id) {
                return true;
            }
        }
        return false;
    }
    
    // Public version with mutex locking and timeout prevention
    pub fn isAgentInteracting(self: *InteractionSystem, agent_id: usize) bool {
        // Use a simple timeout mechanism to prevent infinite waits
        var timeout_counter: usize = 0;
        const max_timeout: usize = 10000; // Arbitrarily large number to prevent infinite loops
        
        while (true) {
            // Try to acquire the lock with non-blocking check
            if (self.mutex.tryLock()) {
                defer self.mutex.unlock();
                // Got the lock, check if agent is interacting
                return self.isAgentInteractingInternal(agent_id);
            }
            
            // Failed to get lock, increment timeout counter
            timeout_counter += 1;
            if (timeout_counter >= max_timeout) {
                std.debug.print("WARNING: isAgentInteracting mutex timeout for agent {d}\n", .{agent_id});
                return false; // Assume not interacting if we can't get the lock
            }
            
            // Sleep briefly to avoid CPU spin
            std.time.sleep(100 * std.time.ns_per_us); // shorter sleep than update - 100 microseconds
        }
    }
    
    pub fn getInteractions(self: *InteractionSystem) []const Interaction {
        // Use a simple timeout mechanism to prevent infinite waits
        var timeout_counter: usize = 0;
        const max_timeout: usize = 10000; // Arbitrarily large number to prevent infinite loops
        
        while (true) {
            // Try to acquire the lock with non-blocking check
            if (self.mutex.tryLock()) {
                defer self.mutex.unlock();
                // Got the lock, return all interactions
                return self.interactions.items;
            }
            
            // Failed to get lock, increment timeout counter
            timeout_counter += 1;
            if (timeout_counter >= max_timeout) {
                std.debug.print("WARNING: getInteractions mutex timeout\n", .{});
                return &[_]Interaction{}; // Return empty slice if we can't get the lock
            }
            
            // Sleep briefly to avoid CPU spin
            std.time.sleep(100 * std.time.ns_per_us); // shorter sleep - 100 microseconds
        }
    }
    
    pub fn findNearbyAgent(agents: []Agent, current_agent: Agent, max_distance: usize) ?*const Agent {
        for (agents) |*other| {
            if (other.id == current_agent.id) continue; // Skip self
    
            const dx = if (other.x > current_agent.x) other.x - current_agent.x else current_agent.x - other.x;
            const dy = if (other.y > current_agent.y) other.y - current_agent.y else current_agent.y - other.y;
    
            // Manhattan distance
            if (dx + dy <= @as(f32, @floatFromInt(max_distance))) {
                return other;
            }
        }
        return null;
    }
    
    // Find an agent within awareness radius but not necessarily interaction distance
    pub fn findPotentialInteractionPartner(
        agents: []Agent, 
        current_agent: *Agent, 
        awareness_radius: usize,
        desire_chance: u8
    ) ?*Agent {
        // Check if already has a target
        if (current_agent.interaction_target_id != null) {
            // Find the target agent
            for (agents) |*other| {
                if (other.id == current_agent.interaction_target_id.?) {
                    // Calculate distance
                    const dx = if (other.x > current_agent.x) other.x - current_agent.x else current_agent.x - other.x;
                    const dy = if (other.y > current_agent.y) other.y - current_agent.y else current_agent.y - other.y;
                    
                    // If close enough for direct interaction, return it
                    if (dx + dy <= 1.0) {
                        // Clear target since they're now close enough
                        current_agent.interaction_target_id = null;
                        return other;
                    }
                    
                    // Still targeting this agent but not close enough yet
                    return null;
                }
            }
            
            // Target not found, clear the target
            current_agent.interaction_target_id = null;
        }
        
        // Random chance to desire interaction
        const random_value = @as(u8, @truncate(@mod(current_agent.seed, 100)));
        if (random_value >= desire_chance) {
            return null; // Not interested in interaction this time
        }
        
        // Look for potential partners within awareness radius
        for (agents) |*other| {
            if (other.id == current_agent.id) continue; // Skip self
            if (other.interaction_target_id != null) continue; // Skip agents already targeting someone
            
            // Check if this is a recent interaction partner - if so, reduce chance of re-interaction
            const was_recent_partner = (current_agent.last_interaction_partner == other.id);
            
            const dx = if (other.x > current_agent.x) other.x - current_agent.x else current_agent.x - other.x;
            const dy = if (other.y > current_agent.y) other.y - current_agent.y else current_agent.y - other.y;
            
            // Check if within awareness radius
            if (dx + dy <= @as(f32, @floatFromInt(awareness_radius))) {
                // If already close enough for interaction, return immediately
                if (dx + dy <= 1.0) {
                    // If this was a recent interaction partner, there's a 90% chance to ignore them
                    // This strongly discourages repeated interactions
                    if (was_recent_partner) {
                        const should_ignore = @mod(current_agent.seed, 100) < 90;
                        if (should_ignore) continue;
                    }
                    return other;
                }
                
                // For targeting at a distance, very strongly prefer new interaction partners
                // Almost never choose to target a recent interaction partner
                if (was_recent_partner) {
                    const should_ignore = @mod(current_agent.seed, 100) < 95;
                    if (should_ignore) continue;
                }
                
                // Otherwise, set as target and return null
                current_agent.interaction_target_id = other.id;
                return null;
            }
        }
        
        return null;
    }
    
    pub fn update(self: *InteractionSystem, agents: []Agent, config: anytype) !void {
        // Use a simple timeout mechanism to prevent infinite waits
        var timeout_counter: usize = 0;
        const max_timeout: usize = 100000; // Arbitrarily large number to prevent infinite loops
        while (true) {
            // Try to acquire the lock with non-blocking check
            if (self.mutex.tryLock()) {
                defer self.mutex.unlock();
                // Got the lock, process interactions
                break;
            }
            
            // Failed to get lock, increment timeout counter
            timeout_counter += 1;
            if (timeout_counter >= max_timeout) {
                std.debug.print("WARNING: InteractionSystem mutex timeout - continuing without lock\n", .{});
                return; // Skip this update rather than waiting forever
            }
            
            // Sleep briefly to avoid CPU spin
            std.time.sleep(1 * std.time.ns_per_ms);
        }
        
        // Count interactions before removal
        const initial_count = self.interactions.items.len;
        var removed_count: usize = 0;
        
        // Process interactions based on their state
        var i: usize = 0;
        while (i < self.interactions.items.len) {
            var interaction = &self.interactions.items[i];
            
            // Process based on interaction state
            switch (interaction.state) {
                .Initiating => {
                    // Check if agents are close enough to begin actual interaction
                    var agent1_found: ?*Agent = null;
                    var agent2_found: ?*Agent = null;
                    
                    // Find both agents
                    for (agents) |*agent| {
                        if (agent.id == interaction.agent1_id) agent1_found = agent;
                        if (agent.id == interaction.agent2_id) agent2_found = agent;
                        if (agent1_found != null and agent2_found != null) break;
                    }
                    
                    // If both agents found, check their distance
                    if (agent1_found != null and agent2_found != null) {
                        const dx = if (agent1_found.?.x > agent2_found.?.x) 
                                    agent1_found.?.x - agent2_found.?.x 
                                 else 
                                    agent2_found.?.x - agent1_found.?.x;
                        const dy = if (agent1_found.?.y > agent2_found.?.y) 
                                    agent1_found.?.y - agent2_found.?.y 
                                 else 
                                    agent2_found.?.y - agent1_found.?.y;
                        
                        // If close enough, transition to Active state
                        if (dx + dy <= 1.0) {
                            interaction.state = .Active;
                        }
                        
                        // If initiating for too long, cancel the interaction
                        if (interaction.duration <= 5) { // Has been trying to meet for too long
                            // Remove the interaction
                            _ = self.interactions.swapRemove(i);
                            removed_count += 1;
                            continue; // Skip to next interaction
                        }
                    } else {
                        // One or both agents missing, remove the interaction
                        _ = self.interactions.swapRemove(i);
                        removed_count += 1;
                        continue;
                    }
                    
                    // Decrease duration
                    interaction.duration -= 1;
                    i += 1;
                },
                
                .Active => {
                    // Active interaction - check if duration expired
                    if (interaction.duration == 0) {
                        // Transition to Finishing state
                        interaction.state = .Finishing;
                        interaction.duration = 2; // Short duration for finishing state
                        
                        // Update agents' last interaction partner
                        for (agents) |*agent| {
                            if (agent.id == interaction.agent1_id) {
                                agent.last_interaction_partner = interaction.agent2_id;
                            } else if (agent.id == interaction.agent2_id) {
                                agent.last_interaction_partner = interaction.agent1_id;
                            }
                        }
                        
                        i += 1;
                    } else {
                        interaction.duration -= 1;
                        i += 1;
                    }
                },
                
                .Concluding => {
                    // Simply decrement duration for concluding state
                    interaction.duration -= 1;
                    if (interaction.duration == 0) {
                        // Remove the interaction
                        _ = self.interactions.swapRemove(i);
                        removed_count += 1;
                    } else {
                        i += 1;
                    }
                },
                
                .Finishing => {
                    // Apply separation forces to agents
                    for (agents) |*agent| {
                        if (agent.id == interaction.agent1_id or agent.id == interaction.agent2_id) {
                            // Find the other agent
                            const other_id = if (agent.id == interaction.agent1_id) 
                                                interaction.agent2_id 
                                             else 
                                                interaction.agent1_id;
                            
                            // Find the other agent in the agents list
                            for (agents) |other_agent| {
                                if (other_agent.id == other_id) {
                                    // Apply a much stronger force to move away (setting velocity directly)
                                    // This will help prevent immediate re-interactions
                                    if (agent.x < other_agent.x) {
                                        agent.vx = -1.5;
                                    } else {
                                        agent.vx = 1.5;
                                    }
                                    
                                    if (agent.y < other_agent.y) {
                                        agent.vy = -1.5;
                                    } else {
                                        agent.vy = 1.5;
                                    }
                                    
                                    break;
                                }
                            }
                        }
                    }
                    
                    // Check if finishing state is complete
                    if (interaction.duration == 0) {
                        // Remove the interaction
                        _ = self.interactions.swapRemove(i);
                        removed_count += 1;
                    } else {
                        interaction.duration -= 1;
                        i += 1;
                    }
                }
            }
        }
        
        // Build a list of free agents (not already in interactions)
        var free_agent_ids = std.ArrayList(usize).init(std.heap.page_allocator);
        defer free_agent_ids.deinit();
        
        for (agents, 0..) |agent, idx| {
            if (!self.isAgentInteractingInternal(agent.id)) {
                try free_agent_ids.append(idx);
            }
        }
        
        // Shuffle free agents for more varied interactions
        if (free_agent_ids.items.len > 1) {
            const seed = if (agents.len > 0) agents[0].seed else @as(u64, @truncate(@abs(std.time.milliTimestamp())));
            // Use crypto.random instead of std.rand (which isn't available)
            
            // Simple shuffle - for each position, swap with a random position
            var j: usize = 0;
            while (j < free_agent_ids.items.len) {
                const r = @mod(seed + j * 17, free_agent_ids.items.len);
                const temp = free_agent_ids.items[j];
                free_agent_ids.items[j] = free_agent_ids.items[r];
                free_agent_ids.items[r] = temp;
                j += 1;
            }
        }
        
        // Process free agents in pairs for more efficient interaction creation
        var processed: usize = 0;
        var idx: usize = 0;
        while (idx < free_agent_ids.items.len) {
            const agent_idx = free_agent_ids.items[idx];
            const agent = &agents[agent_idx];
            
            // Look for potential interaction partners at longer range
            if (findPotentialInteractionPartner(
                agents, 
                agent, 
                config.interaction_awareness_radius, 
                config.interaction_desire_chance
            )) |nearby_agent| {
                // Skip if the other agent is already in an interaction
                if (self.isAgentInteractingInternal(nearby_agent.id)) {
                    idx += 1;
                    continue;
                }
                
                // Check if these agents were previously paired with each other
                const repeated_interaction = (agent.last_interaction_partner == nearby_agent.id) and 
                                           (nearby_agent.last_interaction_partner == agent.id);
                
                // Log if it's a repeated interaction
                if (repeated_interaction) {
                    // Log every 20th occurrence to avoid flooding console
                    if (@mod(agent.seed, 20) == 0) {
                        std.debug.print("REPEATED: Agents {d} and {d} interacting again\n", 
                            .{agent.id, nearby_agent.id});
                    }
                }
                
                // Update last interaction partners
                agent.last_interaction_partner = nearby_agent.id;
                nearby_agent.last_interaction_partner = agent.id;
                
                // Create a new interaction based on agent types
                const combined_seed = agent.seed ^ nearby_agent.seed;
                const interaction_type = InteractionType.chooseInteractionType(
                    agent.type, 
                    nearby_agent.type, 
                    combined_seed
                );
                const interaction = Interaction.init(agent.*, nearby_agent.*, interaction_type);
                try self.interactions.append(interaction);
                processed += 1;
            }
            
            idx += 1;
            // No limit on interactions per update - process all potential interactions
        }
        
        // Count interactions created in this update
        const created_count = self.interactions.items.len - (initial_count - removed_count);
        
        // Count repeated interactions
        var repeated_count: usize = 0;
        for (agents) |agent| {
            if (agent.last_interaction_partner != null) {
                for (self.interactions.items) |interaction| {
                    if ((interaction.agent1_id == agent.id and interaction.agent2_id == agent.last_interaction_partner) or
                        (interaction.agent2_id == agent.id and interaction.agent1_id == agent.last_interaction_partner)) {
                        repeated_count += 1;
                        break;
                    }
                }
            }
        }
        
        // Every 50 updates, print interaction statistics
        const random_val = agents[0].seed % 50;
        if (random_val == 0) {
            std.debug.print("Interactions: {d} (Removed: {d}, Created: {d}, Repeated: {d})\n", 
                .{self.interactions.items.len, removed_count, created_count, repeated_count});
        }
    }
};