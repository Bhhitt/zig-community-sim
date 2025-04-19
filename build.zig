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
    
    // Add agent_update_system as a module for both main and test builds
    const agent_update_system_module = b.addModule("agent_update_system", .{
        .root_source_file = b.path("src/agents/agent_update_system.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "map", .module = map_module },
            .{ .name = "terrain_effects", .module = terrain_effects_module },
            .{ .name = "agent_type", .module = agent_type_module },
        },
    });
    
    // Config module
    const config_module = b.addModule("config", .{
        .root_source_file = b.path("src/core/config.zig"),
    });
    
    // Interactions module
    const interactions_module = b.addModule("interactions", .{
        .root_source_file = b.path("src/core/interactions.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "agent_type", .module = agent_type_module },
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
            .{ .name = "agent_update_system", .module = agent_update_system_module },
            .{ .name = "movement_types", .module = movement_types_module },
        },
    });
    simulation_module.addImport("agent_type", agent_type_module);
    
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
    
    // Create stats_window module with correct imports
    const stats_window_module = b.addModule("stats_window", .{
        .root_source_file = b.path("src/ui/stats_window.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "agent_type", .module = agent_type_module },
        },
    });

    // Create app module and add stats_window as import
    const app_module = b.addModule("app", .{
        .root_source_file = b.path("src/core/app.zig"),
        .imports = &.{
            .{ .name = "config", .module = config_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "simulation", .module = simulation_module },
            .{ .name = "renderer", .module = renderer_module },
            .{ .name = "stats_window", .module = stats_window_module },
        },
    });
    
    // Benchmark module
    const benchmark_module = b.addModule("benchmark", .{
        .root_source_file = b.path("src/benchmark.zig"),
        .imports = &.{
            .{ .name = "simulation", .module = simulation_module },
            .{ .name = "agent_type", .module = agent_type_module },
            .{ .name = "agent", .module = agent_module },
        },
    });
    
    // Benchmark executable
    const benchmark_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("src/benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_exe.root_module.addImport("simulation", simulation_module);
    benchmark_exe.root_module.addImport("agent_type", agent_type_module);
    benchmark_exe.root_module.addImport("config", config_module);
    benchmark_exe.root_module.addImport("map", map_module);
    benchmark_exe.root_module.addImport("interactions", interactions_module);
    benchmark_exe.root_module.addImport("movement_types", movement_types_module);
    benchmark_exe.root_module.addImport("agent_update_system", agent_update_system_module);
    benchmark_exe.root_module.addImport("terrain", terrain_module);
    benchmark_exe.root_module.addImport("terrain_effects", terrain_effects_module);
    benchmark_exe.root_module.addImport("interaction_type", interaction_type_module);
    benchmark_exe.root_module.addImport("agent", agent_module);
    b.installArtifact(benchmark_exe);
    
    // Install the benchmark binary
    b.installArtifact(benchmark_exe);
    // Add a step to run the benchmark
    const run_benchmark = b.addRunArtifact(benchmark_exe);
    const benchmark_step = b.step("benchmark", "Run the simulation benchmark");
    benchmark_step.dependOn(&run_benchmark.step);

    // Create a run step for the benchmark executable
    // const benchmark_step = b.step("benchmark", "Run the simulation benchmark");
    // benchmark_step.dependOn(&benchmark_exe.step);

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
        
        // Link SDL_ttf for stats window text rendering
        exe.linkSystemLibrary("SDL3_ttf");
    }
    
    // Add all module dependencies
    exe.root_module.addImport("app", app_module);
    exe.root_module.addImport("config", config_module);
    exe.root_module.addImport("agent_type", agent_type_module);
    exe.root_module.addImport("agent", agent_module);
    exe.root_module.addImport("map", map_module);
    exe.root_module.addImport("build_options", build_options_module);
    exe.root_module.addImport("agent_update_system", agent_update_system_module);
    exe.root_module.addImport("benchmark", benchmark_module);
    
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

    // Create test steps
    const test_step = b.step("test", "Run all tests");
    const agent_tests = b.step("test-agents", "Run agent tests only");
    const interaction_tests = b.step("test-interactions", "Run interaction tests only");
    const movement_tests_module = b.addTest(.{
        .root_source_file = b.path("tests/movement_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    movement_tests_module.root_module.addImport("map", map_module);
    movement_tests_module.root_module.addImport("agent", agent_module);
    movement_tests_module.root_module.addImport("agent_update_system", agent_update_system_module);
    movement_tests_module.root_module.addImport("config", config_module);
    const movement_tests = b.step("test-movement", "Run movement tests only");
    const integration_tests = b.step("test-integration", "Run integration tests only");

    // Create test_utils module
    const test_utils_module = b.addModule("test_utils", .{
        .root_source_file = b.path("tests/utils/test_utils.zig"),
        .imports = &.{
            .{ .name = "agent", .module = agent_module },
            .{ .name = "map", .module = map_module },
            .{ .name = "config", .module = config_module },
        },
    });

    // Main test suite
    const main_tests = b.addTest(.{
        .root_source_file = b.path("tests/main.zig"),
        .name = "main_tests",
        .target = target,
        .optimize = optimize,
    });
    main_tests.root_module.addImport("agent", agent_module);
    main_tests.root_module.addImport("map", map_module);
    main_tests.root_module.addImport("test_utils", test_utils_module);
    main_tests.root_module.addImport("simulation", simulation_module);
    main_tests.root_module.addImport("agent_update_system", agent_update_system_module);
    main_tests.root_module.addImport("config", config_module);
    main_tests.root_module.addImport("agent_type", agent_type_module);
    main_tests.root_module.addImport("movement_types", movement_types_module);
    main_tests.root_module.addImport("terrain_effects", terrain_effects_module);
    main_tests.root_module.addImport("interaction_type", interaction_type_module);
    main_tests.root_module.addImport("interactions", interactions_module);
    main_tests.root_module.addImport("terrain", terrain_module);
    test_step.dependOn(&main_tests.step);

    // Agent tests
    const agent_test_exe = b.addTest(.{
        .root_source_file = b.path("tests/agent_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    agent_test_exe.root_module.addImport("agent", agent_module);
    agent_test_exe.root_module.addImport("map", map_module);
    agent_test_exe.root_module.addImport("config", config_module);
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
    interaction_test_exe.root_module.addImport("config", config_module);
    const run_interaction_tests = b.addRunArtifact(interaction_test_exe);
    interaction_tests.dependOn(&run_interaction_tests.step);

    // Movement tests
    const run_movement_tests = b.addRunArtifact(movement_tests_module);
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
    integration_test_exe.root_module.addImport("config", config_module);
    integration_test_exe.root_module.addImport("agent_update_system", agent_update_system_module);
    const run_integration_tests = b.addRunArtifact(integration_test_exe);
    integration_tests.dependOn(&run_integration_tests.step);

    // Agent perception test
    const agent_perception_test_exe = b.addTest(.{
        .root_source_file = b.path("src/agents/test_agent_perception.zig"),
        .target = target,
        .optimize = optimize,
    });
    agent_perception_test_exe.root_module.addImport("agent", agent_module);
    agent_perception_test_exe.root_module.addImport("map", map_module);
    agent_perception_test_exe.root_module.addImport("agent_update_system", agent_update_system_module);
    agent_perception_test_exe.root_module.addImport("config", config_module);
    agent_perception_test_exe.root_module.addImport("terrain_effects", terrain_effects_module);
    agent_perception_test_exe.root_module.addImport("agent_type", agent_type_module);
    agent_perception_test_exe.root_module.addImport("movement_types", movement_types_module);
    agent_perception_test_exe.root_module.addImport("interaction_type", interaction_type_module);
    agent_perception_test_exe.root_module.addImport("terrain", terrain_module);
    const run_agent_perception_tests = b.addRunArtifact(agent_perception_test_exe);
    agent_tests.dependOn(&run_agent_perception_tests.step);

    // Register src/core/simulation.zig as a module named 'simulation' for both main and test builds
    const simulation = b.addModule("simulation", .{ .root_source_file = b.path("src/core/simulation.zig") });
    exe.root_module.addImport("simulation", simulation);
    main_tests.root_module.addImport("simulation", simulation);
    agent_test_exe.root_module.addImport("simulation", simulation);
    interaction_test_exe.root_module.addImport("simulation", simulation);
    integration_test_exe.root_module.addImport("simulation", simulation);

    // Ensure simulation module has all needed imports
    simulation.addImport("map", map_module);
    simulation.addImport("agent", agent_module);
    simulation.addImport("agent_type", agent_type_module);
    simulation.addImport("movement_types", movement_types_module);
    simulation.addImport("terrain_effects", terrain_effects_module);
    simulation.addImport("interaction_type", interaction_type_module);
    simulation.addImport("agent_update_system", agent_update_system_module);
    simulation.addImport("interactions", interactions_module);
    simulation.addImport("terrain", terrain_module);
}