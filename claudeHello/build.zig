const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "community-sim",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Add SDL3 to our executable
    
    // Add the SDL3 header directory
    exe.addIncludePath(b.path("SDL3/vendored/SDL/include"));
    
    // Add the directory containing the SDL3 library
    exe.addLibraryPath(b.path("SDL3/vendored/SDL/build"));
    
    // Link against SDL3
    exe.linkSystemLibrary("SDL3");
    
    // Set rpath to find the dynamic library at runtime
    exe.addRPath(b.path("SDL3/vendored/SDL/build"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}