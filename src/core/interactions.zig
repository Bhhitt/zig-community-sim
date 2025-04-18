const std = @import("std");
const Agent = @import("agent").Agent;
const AgentType = @import("agent_type").AgentType;
const Interaction = @import("agent").Interaction;
const InteractionType = @import("interaction_type").InteractionType;

pub const InteractionSystem = struct {
    interactions: std.ArrayList(Interaction),
    
    pub fn init(allocator: std.mem.Allocator) InteractionSystem {
        return .{
            .interactions = std.ArrayList(Interaction).init(allocator),
        };
    }
    
    pub fn deinit(self: *InteractionSystem) void {
        self.interactions.deinit();
    }
    
    pub fn isAgentInteracting(self: InteractionSystem, agent_id: usize) bool {
        for (self.interactions.items) |interaction| {
            if (interaction.agent1_id == agent_id or interaction.agent2_id == agent_id) {
                return true;
            }
        }
        return false;
    }
    
    pub fn getInteractions(self: InteractionSystem) []const Interaction {
        return self.interactions.items;
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
    
    pub fn update(self: *InteractionSystem, agents: []Agent) !void {
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
        for (agents) |agent| {
            // Skip if agent is already interacting
            if (self.isAgentInteracting(agent.id)) continue;
            
            // Look for nearby agents to interact with
            if (findNearbyAgent(agents, agent, 1)) |nearby_agent| {
                // Skip if the other agent is already in an interaction
                if (self.isAgentInteracting(nearby_agent.id)) continue;
                
                // Create a new interaction based on agent types
                const combined_seed = agent.seed ^ nearby_agent.seed;
                const interaction_type = InteractionType.chooseInteractionType(
                    agent.type, 
                    nearby_agent.type, 
                    combined_seed
                );
                const interaction = Interaction.init(agent, nearby_agent.*, interaction_type);
                try self.interactions.append(interaction);
                
                // Each agent can only be in one interaction at a time
                break;
            }
        }
    }
};