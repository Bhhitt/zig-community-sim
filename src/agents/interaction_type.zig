// Defines types of interactions agents can have and related logic

/// Represents the type of interaction between two agents.
pub const InteractionType = enum {
    Greeting,
    Trading,
    Collaboration,
    Teaching,
    Resource,
    
    /// Returns a symbol representing the interaction type.
    pub fn getSymbol(self: InteractionType) u8 {
        return switch (self) {
            .Greeting => 'G',
            .Trading => 'T',
            .Collaboration => 'C',
            .Teaching => 'E',  // Education
            .Resource => 'R',
        };
    }
    
    /// Determines the appropriate interaction type based on the agent types.
    pub fn chooseInteractionType(
        agent1_type: @import("agent_type").AgentType, 
        agent2_type: @import("agent_type").AgentType, 
        random_value: u64
    ) InteractionType {
        const mod_value = @mod(random_value, 100);
        
        if (agent1_type == agent2_type) {
            // Same type agents have specific preferences
            return switch (agent1_type) {
                .Settler => if (mod_value < 70) .Greeting else .Collaboration,
                .Explorer => if (mod_value < 60) .Trading else .Greeting,
                .Builder => if (mod_value < 80) .Collaboration else .Trading,
                .Farmer => if (mod_value < 65) .Resource else .Trading,
                .Miner => if (mod_value < 75) .Resource else .Collaboration,
                .Scout => if (mod_value < 80) .Teaching else .Trading,
            };
        } else {
            // Interactions between different agent types
            if (agent1_type == .Scout or agent2_type == .Scout) {
                // Scouts share information with others
                return if (mod_value < 70) .Teaching else .Greeting;
            } else if (agent1_type == .Explorer or agent2_type == .Explorer) {
                // Explorers prefer trading with others
                return if (mod_value < 60) .Trading else .Greeting;
            } else if (agent1_type == .Farmer or agent2_type == .Farmer) {
                // Farmers provide resources to others
                return if (mod_value < 65) .Resource else .Trading;
            } else if (agent1_type == .Miner or agent2_type == .Miner) {
                // Miners provide resources but also collaborate on projects
                return if (mod_value < 50) .Resource else .Collaboration;
            } else if (agent1_type == .Builder or agent2_type == .Builder) {
                // Builders generally prefer collaboration with others
                return if (mod_value < 70) .Collaboration else .Trading;
            } else {
                // Settlers default to greeting
                return .Greeting;
            }
        }
    }
};