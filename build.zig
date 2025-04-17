const std = @import("std");

// Although this function looks imperative, note that its job is to
// declare what the build system should do, not to actually do it.
pub fn build(b: *std.Build) void {
    // Standard target options allows the user to select cross-compilation
    const target = b.standardTargetOptions(.{});

    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});
    
    // Add SDL3 to the build
    const use_sdl = b.option(bool, "sdl", "Enable SDL3 support") orelse true; // Defaults to true
    
    // Create build_options module first as it's used by other modules
    const build_options_module = b.addModule("build_options", .{
        .root_source_file = b.path("src/build_options.zig"),
    });

    // Create modules for world components
    const terrain_module = b.addModule("terrain", .{
        .root_source_file = b.path("src/world/terrain.zig"),
    });

    // Forward declaration of agent_module
    var agent_module: *std.Build.Module = undefined;
    
    const map_module = b.addModule("map", .{
        .root_source_file = b.path("src/world/map.zig"),
        .imports = &.{
            .{ .name = "terrain", .module = terrain_module },
        },
    });

    // Create modules for agent components
    const movement_types_module = b.addModule("movement_types", .{
        .root_source_file = b.path("src/agents/movement_types.zig"),
    });
    
    const agent_type_module = b.addModule("agent_type", .{
        .root_source_file = b.path("src/agents/agent_type.zig"),
        .imports = &.{
            .{ .name = "movement_types", .module = movement_types_module },
        },
    });
    
    const interaction_type_module = b.addModule("interaction_type", .{
        .root_source_file = b.path("src/agents/interaction_type.zig"),
        .imports = &.{
            .{ .name = "agent_type", .module = agent_type_module },
        },
    });
    
    const terrain_effects_module = b.addModule("terrain_effects", .{
        .root_source_file = b.path("src/agents/terrain_effects.zig"),
        .imports = &.{
            .{ .name = "terrain", .module = terrain_module },
            .{ .name = "agent_type", .module = agent_type_module },
        },
    });
    
    // Create the agent module with its dependencies
    agent_module = b.addModule("agent", .{
        .root_source_file = b.path("src/agents/agent.zig"),
        .imports = &.{
            .{ .name = "map", .module = map_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "movement_types", .module = movement_types_module },
            .{ .name = "terrain_effects", .module = terrain_effects_module },
            .{ .name = "interaction_type", .module = interaction_type_module },
        },
    });
    
    // Now add agent_module to map's imports
    map_module.addImport("agent", agent_module);
    
    // Config module
    const config_module = b.addModule("config", .{
        .root_source_file = b.path("src/core/config.zig"),
    });
    
    // Interactions module
    const interactions_module = b.addModule("interactions", .{
        .root_source_file = b.path("src/core/interactions.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "interaction_type", .module = interaction_type_module },
        },
    });
    
    // Simulation module
    const simulation_module = b.addModule("simulation", .{
        .root_source_file = b.path("src/core/simulation.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "map", .module = map_module },
            .{ .name = "interactions", .module = interactions_module },
            .{ .name = "terrain", .module = terrain_module },
        },
    });
    
    // UI modules
    const render_config_module = b.addModule("render_config", .{
        .root_source_file = b.path("src/ui/render_config.zig"),
    });
    
    const drawing_module = b.addModule("drawing", .{
        .root_source_file = b.path("src/ui/drawing.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "render_config", .module = render_config_module },
        },
    });
    
    const input_handler_module = b.addModule("input_handler", .{
        .root_source_file = b.path("src/ui/input_handler.zig"),
        .imports = &.{
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "config", .module = config_module },
        },
    });
    
    // First create the SDL renderer module
    const sdl_renderer_module = b.addModule("sdl_renderer", .{
        .root_source_file = b.path("src/ui/sdl_renderer.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "map", .module = map_module },
            .{ .name = "terrain", .module = terrain_module },
            .{ .name = "render_config", .module = render_config_module },
            .{ .name = "input_handler", .module = input_handler_module },
            .{ .name = "build_options", .module = build_options_module },
        },
    });
    
    const renderer_module = b.addModule("renderer", .{
        .root_source_file = b.path("src/ui/renderer.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "map", .module = map_module },
            .{ .name = "drawing", .module = drawing_module },
            .{ .name = "input_handler", .module = input_handler_module },
            .{ .name = "render_config", .module = render_config_module },
            .{ .name = "sdl_renderer", .module = sdl_renderer_module },
            .{ .name = "build_options", .module = build_options_module },
        },
    });
    
    // App module
    const app_module = b.addModule("app", .{
        .root_source_file = b.path("src/core/app.zig"),
        .imports = &.{
            .{ .name = "config", .module = config_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "simulation", .module = simulation_module },
            .{ .name = "renderer", .module = renderer_module },
        },
    });
    
    // Benchmark module
    const benchmark_module = b.addModule("benchmark", .{
        .root_source_file = b.path("src/benchmark.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "map", .module = map_module },
            .{ .name = "simulation", .module = simulation_module },
        },
    });
    
    // Create the main executable
    const exe = b.addExecutable(.{
        .name = "zig-community-sim",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // Create a build options module
    const options = b.addOptions();
    options.addOption(bool, "USE_SDL", use_sdl);
    
    // Add SDL3 if enabled
    if (use_sdl) {
        // For Homebrew on macOS, SDL3 is installed via homebrew
        exe.linkSystemLibrary("SDL3");
        
        // Add the SDL3 include path from homebrew
        exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
        
        // Add the SDL3 library path from homebrew
        exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
        
        std.debug.print("Building with SDL3 support enabled\n", .{});
        std.debug.print("Using SDL3 from homebrew at /opt/homebrew\n", .{});
        
        // Define build options to indicate SDL is available
        exe.root_module.addCMacro("USE_SDL", "1");
        
        // Update the build_options module to enable SDL
        build_options_module.addCMacro("USE_SDL", "1");
    }
    
    // Add all module dependencies
    exe.root_module.addImport("app", app_module);
    exe.root_module.addImport("config", config_module);
    exe.root_module.addImport("agent_type", agent_type_module);
    exe.root_module.addImport("benchmark", benchmark_module);
    exe.root_module.addImport("agent", agent_module);
    exe.root_module.addImport("map", map_module);
    exe.root_module.addImport("build_options", build_options_module);
    
    // Install the executable
    b.installArtifact(exe);
    
    // Add a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
    
    // Add a benchmark step
    const bench_cmd = b.addRunArtifact(exe);
    bench_cmd.step.dependOn(b.getInstallStep());
    bench_cmd.addArg("benchmark");
    
    const benchmark_step = b.step("benchmark", "Run performance benchmark");
    benchmark_step.dependOn(&bench_cmd.step);

    // Create test steps
    const test_step = b.step("test", "Run all tests");
    const agent_tests = b.step("test-agents", "Run agent tests only");
    const interaction_tests = b.step("test-interactions", "Run interaction tests only");
    const movement_tests = b.step("test-movement", "Run movement tests only");
    const integration_tests = b.step("test-integration", "Run integration tests only");

    // Create test_utils module
    const test_utils_module = b.addModule("test_utils", .{
        .root_source_file = b.path("tests/utils/test_utils.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "map", .module = map_module },
        },
    });

    // Main test suite
    const tests = b.addTest(.{
        .root_source_file = b.path("tests/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    tests.root_module.addImport("agent", agent_module);
    tests.root_module.addImport("map", map_module);
    tests.root_module.addImport("test_utils", test_utils_module);
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    // Agent tests
    const agent_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/agent_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    agent_test_exe.root_module.addImport("agent", agent_module);
    agent_test_exe.root_module.addImport("map", map_module);
    const run_agent_tests = b.addRunArtifact(agent_test_exe);
    agent_tests.dependOn(&run_agent_tests.step);

    // Interaction tests
    const interaction_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/interaction_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    interaction_test_exe.root_module.addImport("agent", agent_module);
    interaction_test_exe.root_module.addImport("map", map_module);
    const run_interaction_tests = b.addRunArtifact(interaction_test_exe);
    interaction_tests.dependOn(&run_interaction_tests.step);

    // Movement tests
    const movement_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/movement_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    movement_test_exe.root_module.addImport("agent", agent_module);
    movement_test_exe.root_module.addImport("map", map_module);
    movement_test_exe.root_module.addImport("movement_types", movement_types_module);
    const run_movement_tests = b.addRunArtifact(movement_test_exe);
    movement_tests.dependOn(&run_movement_tests.step);

    // Integration tests
    const integration_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/integration_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    integration_test_exe.root_module.addImport("agent", agent_module);
    integration_test_exe.root_module.addImport("map", map_module);
    integration_test_exe.root_module.addImport("test_utils", test_utils_module);
    const run_integration_tests = b.addRunArtifact(integration_test_exe);
    integration_tests.dependOn(&run_integration_tests.step);
    
    // Create a separate build command for perf_test
    const perf_test = b.addExecutable(.{
        .name = "perf_test",
        .root_source_file = b.path("perf_test.zig"),
        .target = target,
        .optimize = .ReleaseFast,  // Always use ReleaseFast for perf test
    });
    
    b.installArtifact(perf_test);
    
    const perf_test_run = b.addRunArtifact(perf_test);
    perf_test_run.step.dependOn(b.getInstallStep());
    
    const perf_test_step = b.step("perf-test", "Run the performance test");
    perf_test_step.dependOn(&perf_test_run.step);
}