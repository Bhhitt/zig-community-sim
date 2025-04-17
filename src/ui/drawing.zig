const std = @import("std");
const Agent = @import("agent").Agent;
const Interaction = @import("agent").Interaction;
const Terrain = @import("terrain").Terrain;
const AgentType = @import("agent_type").AgentType;
const RenderConfig = @import("render_config").RenderConfig;

// In the non-SDL version, these are no-op stubs

// Dummy version that does nothing
pub fn renderTerrain(renderer: anytype, x: usize, y: usize, terrain: Terrain, config: RenderConfig) void {
    _ = renderer;
    _ = x;
    _ = y;
    _ = terrain;
    _ = config;
}

// Dummy version that does nothing
pub fn renderAgent(renderer: anytype, agent: Agent, config: RenderConfig) void {
    _ = renderer;
    _ = agent;
    _ = config;
}

// Dummy version that does nothing
pub fn renderInteraction(renderer: anytype, agent1: Agent, agent2: Agent, interaction: Interaction, config: RenderConfig) void {
    _ = renderer;
    _ = agent1;
    _ = agent2;
    _ = interaction;
    _ = config;
}

// Dummy version that does nothing
pub fn renderSimulationStatus(
    renderer: anytype,
    step_count: usize,
    paused: bool,
    spawn_mode: bool,
    selected_agent_type: AgentType,
    agent_count: usize,
    fps: f32,
    config: RenderConfig
) void {
    _ = renderer;
    _ = step_count;
    _ = paused;
    _ = spawn_mode;
    _ = selected_agent_type;
    _ = agent_count;
    _ = fps;
    _ = config;
}