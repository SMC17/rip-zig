const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create module
    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "rippled-zig",
        .root_module = main_module,
    });
    exe.linkLibC();
    
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the XRP Ledger daemon");
    run_step.dependOn(&run_cmd.step);

    // Examples
    const example_simple_payment_module = b.createModule(.{
        .root_source_file = b.path("examples/simple_payment.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const example_simple_payment = b.addExecutable(.{
        .name = "simple_payment",
        .root_module = example_simple_payment_module,
    });
    
    const example_consensus_module = b.createModule(.{
        .root_source_file = b.path("examples/ledger_consensus.zig"),
        .target = target,
        .optimize = optimize,
    });

    const example_consensus = b.addExecutable(.{
        .name = "ledger_consensus",
        .root_module = example_consensus_module,
    });

    const examples_step = b.step("examples", "Build all examples");
    examples_step.dependOn(&b.addInstallArtifact(example_simple_payment, .{}).step);
    examples_step.dependOn(&b.addInstallArtifact(example_consensus, .{}).step);

    // Tests
    const test_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const unit_tests = b.addTest(.{
        .root_module = test_module,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
