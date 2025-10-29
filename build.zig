const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create main module
    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create shared lib module for imports
    const lib_module = b.createModule(.{
        .root_source_file = b.path("src/types.zig"),
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

    // Examples - all share main module for imports
    const example_simple_payment = b.addExecutable(.{
        .name = "simple_payment",
        .root_source_file = b.path("examples/simple_payment.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_simple_payment.root_module.addImport("types.zig", b.createModule(.{ .root_source_file = b.path("src/types.zig") }));
    example_simple_payment.root_module.addImport("crypto.zig", b.createModule(.{ .root_source_file = b.path("src/crypto.zig") }));
    example_simple_payment.root_module.addImport("ledger.zig", b.createModule(.{ .root_source_file = b.path("src/ledger.zig") }));
    example_simple_payment.root_module.addImport("transaction.zig", b.createModule(.{ .root_source_file = b.path("src/transaction.zig") }));

    const example_consensus = b.addExecutable(.{
        .name = "ledger_consensus",
        .root_source_file = b.path("examples/ledger_consensus.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_consensus.root_module.addImport("types.zig", b.createModule(.{ .root_source_file = b.path("src/types.zig") }));
    example_consensus.root_module.addImport("ledger.zig", b.createModule(.{ .root_source_file = b.path("src/ledger.zig") }));
    example_consensus.root_module.addImport("consensus.zig", b.createModule(.{ .root_source_file = b.path("src/consensus.zig") }));

    const example_http = b.addExecutable(.{
        .name = "http_server_demo",
        .root_source_file = b.path("examples/http_server_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_http.root_module.addImport("types.zig", b.createModule(.{ .root_source_file = b.path("src/types.zig") }));
    example_http.root_module.addImport("ledger.zig", b.createModule(.{ .root_source_file = b.path("src/ledger.zig") }));
    example_http.root_module.addImport("rpc.zig", b.createModule(.{ .root_source_file = b.path("src/rpc.zig") }));

    const example_network = b.addExecutable(.{
        .name = "network_demo",
        .root_source_file = b.path("examples/network_demo.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_network.root_module.addImport("network.zig", b.createModule(.{ .root_source_file = b.path("src/network.zig") }));

    const examples_step = b.step("examples", "Build all examples");
    examples_step.dependOn(&b.addInstallArtifact(example_simple_payment, .{}).step);
    examples_step.dependOn(&b.addInstallArtifact(example_consensus, .{}).step);
    examples_step.dependOn(&b.addInstallArtifact(example_http, .{}).step);
    examples_step.dependOn(&b.addInstallArtifact(example_network, .{}).step);

    // Benchmarks
    const benchmark_exe = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("benchmarks/benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_exe.root_module.addImport("types.zig", b.createModule(.{ .root_source_file = b.path("src/types.zig") }));
    benchmark_exe.root_module.addImport("crypto.zig", b.createModule(.{ .root_source_file = b.path("src/crypto.zig") }));
    benchmark_exe.root_module.addImport("ledger.zig", b.createModule(.{ .root_source_file = b.path("src/ledger.zig") }));
    benchmark_exe.root_module.addImport("transaction.zig", b.createModule(.{ .root_source_file = b.path("src/transaction.zig") }));

    const benchmark_step = b.step("benchmark", "Run performance benchmarks");
    benchmark_step.dependOn(&b.addInstallArtifact(benchmark_exe, .{}).step);
    const run_benchmark = b.addRunArtifact(benchmark_exe);
    benchmark_step.dependOn(&run_benchmark.step);

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
