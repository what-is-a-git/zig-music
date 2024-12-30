const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zig-music",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.linkLibC();
    exe.linkLibrary(build_dr_libs(b, target, optimize));
    exe.linkLibrary(build_stb_vorbis(b, target, optimize));

    exe.linkLibrary(build_libogg(b, target, optimize));
    exe.linkLibrary(build_libopus(b, target, optimize));
    exe.linkLibrary(build_libopusfile(b, target, optimize));

    // dlls n stuff
    exe.addLibraryPath(b.path("vendor/lib"));
    if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("al-soft/OpenAL32");
        b.installFile("vendor/lib/al-soft/OpenAL32.dll", "bin/OpenAL32.dll");
    } else {
        exe.linkSystemLibrary("openal");
    }

    exe.addIncludePath(b.path("vendor/include"));
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit testing, not currently in use.
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}

fn build_dr_libs(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const dr_libs = b.addStaticLibrary(.{ .name = "dr_libs", .target = target, .optimize = optimize });
    dr_libs.linkLibC();
    dr_libs.addIncludePath(b.path("vendor/include/dr_libs/"));
    dr_libs.addCSourceFiles(.{ .root = b.path("vendor/src/dr_libs/"), .files = &.{
        "dr_flac.c",
        "dr_mp3.c",
        "dr_wav.c",
    } });
    return dr_libs;
}

fn build_stb_vorbis(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const stb_vorbis = b.addStaticLibrary(.{ .name = "stb_vorbis", .target = target, .optimize = optimize });
    stb_vorbis.linkLibC();
    stb_vorbis.addIncludePath(b.path("vendor/include/stb/"));
    stb_vorbis.addCSourceFile(.{ .file = b.path("vendor/src/stb/stb_vorbis.c") });
    return stb_vorbis;
}

fn build_libogg(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const libogg = b.addStaticLibrary(.{ .name = "libogg", .target = target, .optimize = optimize });
    libogg.linkLibC();

    libogg.addIncludePath(b.path("vendor/include/"));
    libogg.addIncludePath(b.path("vendor/src/ogg/"));

    libogg.addCSourceFiles(.{
        .root = b.path("vendor/src/ogg/"),
        .files = &.{
            "bitwise.c",
            "framing.c",
        },
        // you need this flag or else sometimes it just crashes lmfao
        .flags = &.{"-fno-sanitize=undefined"},
    });

    const ogg_config_header = b.addConfigHeader(
        .{
            .style = .{ .cmake = b.path("vendor/include/ogg/config_types.h.in") },
            .include_path = "ogg/config_types.h",
        },
        .{
            .INCLUDE_INTTYPES_H = 0,
            .INCLUDE_STDINT_H = 1,
            .INCLUDE_SYS_TYPES_H = 0,
            .SIZE16 = .int16_t,
            .USIZE16 = .uint16_t,
            .SIZE32 = .int32_t,
            .USIZE32 = .uint32_t,
            .SIZE64 = .int64_t,
            .USIZE64 = .uint64_t,
        },
    );

    libogg.installConfigHeader(ogg_config_header);
    return libogg;
}

fn build_libopusfile(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const libopusfile = b.addStaticLibrary(.{ .name = "libopusfile", .target = target, .optimize = optimize });
    libopusfile.linkLibC();

    libopusfile.addIncludePath(b.path("vendor/include/"));
    libopusfile.addIncludePath(b.path("vendor/src/opusfile/src/"));

    libopusfile.addCSourceFiles(.{
        .root = b.path("vendor/src/opusfile/src/"),
        .files = &.{
            "info.c",
            "internal.c",
            "opusfile.c",
            "stream.c",
        },
    });

    return libopusfile;
}

fn build_libopus(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    // A LOT OF PATHS BECAUSE DAMN THIS IS A COMPLEX LIBRARY
    const sources = &[_][]const u8{
        "vendor/src/opus/src/analysis.c",
        "vendor/src/opus/src/mapping_matrix.c",
        "vendor/src/opus/src/mlp_data.c",
        "vendor/src/opus/src/mlp.c",
        "vendor/src/opus/src/opus_decoder.c",
        "vendor/src/opus/src/opus_encoder.c",
        "vendor/src/opus/src/opus_multistream_decoder.c",
        "vendor/src/opus/src/opus_multistream_encoder.c",
        "vendor/src/opus/src/opus_multistream.c",
        "vendor/src/opus/src/opus_projection_decoder.c",
        "vendor/src/opus/src/opus_projection_encoder.c",
        "vendor/src/opus/src/opus.c",
        "vendor/src/opus/src/repacketizer.c",

        "vendor/src/opus/celt/bands.c",
        "vendor/src/opus/celt/celt.c",
        "vendor/src/opus/celt/celt_encoder.c",
        "vendor/src/opus/celt/celt_decoder.c",
        "vendor/src/opus/celt/cwrs.c",
        "vendor/src/opus/celt/entcode.c",
        "vendor/src/opus/celt/entdec.c",
        "vendor/src/opus/celt/entenc.c",
        "vendor/src/opus/celt/kiss_fft.c",
        "vendor/src/opus/celt/laplace.c",
        "vendor/src/opus/celt/mathops.c",
        "vendor/src/opus/celt/mdct.c",
        "vendor/src/opus/celt/modes.c",
        "vendor/src/opus/celt/pitch.c",
        "vendor/src/opus/celt/celt_lpc.c",
        "vendor/src/opus/celt/quant_bands.c",
        "vendor/src/opus/celt/rate.c",
        "vendor/src/opus/celt/vq.c",

        "vendor/src/opus/silk/CNG.c",
        "vendor/src/opus/silk/code_signs.c",
        "vendor/src/opus/silk/init_decoder.c",
        "vendor/src/opus/silk/decode_core.c",
        "vendor/src/opus/silk/decode_frame.c",
        "vendor/src/opus/silk/decode_parameters.c",
        "vendor/src/opus/silk/decode_indices.c",
        "vendor/src/opus/silk/decode_pulses.c",
        "vendor/src/opus/silk/decoder_set_fs.c",
        "vendor/src/opus/silk/dec_API.c",
        "vendor/src/opus/silk/enc_API.c",
        "vendor/src/opus/silk/encode_indices.c",
        "vendor/src/opus/silk/encode_pulses.c",
        "vendor/src/opus/silk/gain_quant.c",
        "vendor/src/opus/silk/interpolate.c",
        "vendor/src/opus/silk/LP_variable_cutoff.c",
        "vendor/src/opus/silk/NLSF_decode.c",
        "vendor/src/opus/silk/NSQ.c",
        "vendor/src/opus/silk/NSQ_del_dec.c",
        "vendor/src/opus/silk/PLC.c",
        "vendor/src/opus/silk/shell_coder.c",
        "vendor/src/opus/silk/tables_gain.c",
        "vendor/src/opus/silk/tables_LTP.c",
        "vendor/src/opus/silk/tables_NLSF_CB_NB_MB.c",
        "vendor/src/opus/silk/tables_NLSF_CB_WB.c",
        "vendor/src/opus/silk/tables_other.c",
        "vendor/src/opus/silk/tables_pitch_lag.c",
        "vendor/src/opus/silk/tables_pulses_per_block.c",
        "vendor/src/opus/silk/VAD.c",
        "vendor/src/opus/silk/control_audio_bandwidth.c",
        "vendor/src/opus/silk/quant_LTP_gains.c",
        "vendor/src/opus/silk/VQ_WMat_EC.c",
        "vendor/src/opus/silk/HP_variable_cutoff.c",
        "vendor/src/opus/silk/NLSF_encode.c",
        "vendor/src/opus/silk/NLSF_VQ.c",
        "vendor/src/opus/silk/NLSF_unpack.c",
        "vendor/src/opus/silk/NLSF_del_dec_quant.c",
        "vendor/src/opus/silk/process_NLSFs.c",
        "vendor/src/opus/silk/stereo_LR_to_MS.c",
        "vendor/src/opus/silk/stereo_MS_to_LR.c",
        "vendor/src/opus/silk/check_control_input.c",
        "vendor/src/opus/silk/control_SNR.c",
        "vendor/src/opus/silk/init_encoder.c",
        "vendor/src/opus/silk/control_codec.c",
        "vendor/src/opus/silk/A2NLSF.c",
        "vendor/src/opus/silk/ana_filt_bank_1.c",
        "vendor/src/opus/silk/biquad_alt.c",
        "vendor/src/opus/silk/bwexpander_32.c",
        "vendor/src/opus/silk/bwexpander.c",
        "vendor/src/opus/silk/debug.c",
        "vendor/src/opus/silk/decode_pitch.c",
        "vendor/src/opus/silk/inner_prod_aligned.c",
        "vendor/src/opus/silk/lin2log.c",
        "vendor/src/opus/silk/log2lin.c",
        "vendor/src/opus/silk/LPC_analysis_filter.c",
        "vendor/src/opus/silk/LPC_inv_pred_gain.c",
        "vendor/src/opus/silk/table_LSF_cos.c",
        "vendor/src/opus/silk/NLSF2A.c",
        "vendor/src/opus/silk/NLSF_stabilize.c",
        "vendor/src/opus/silk/NLSF_VQ_weights_laroia.c",
        "vendor/src/opus/silk/pitch_est_tables.c",
        "vendor/src/opus/silk/resampler.c",
        "vendor/src/opus/silk/resampler_down2_3.c",
        "vendor/src/opus/silk/resampler_down2.c",
        "vendor/src/opus/silk/resampler_private_AR2.c",
        "vendor/src/opus/silk/resampler_private_down_FIR.c",
        "vendor/src/opus/silk/resampler_private_IIR_FIR.c",
        "vendor/src/opus/silk/resampler_private_up2_HQ.c",
        "vendor/src/opus/silk/resampler_rom.c",
        "vendor/src/opus/silk/sigm_Q15.c",
        "vendor/src/opus/silk/sort.c",
        "vendor/src/opus/silk/sum_sqr_shift.c",
        "vendor/src/opus/silk/stereo_decode_pred.c",
        "vendor/src/opus/silk/stereo_encode_pred.c",
        "vendor/src/opus/silk/stereo_find_predictor.c",
        "vendor/src/opus/silk/stereo_quant_pred.c",
        "vendor/src/opus/silk/LPC_fit.c",
    };

    const celt_sources_x86 = &[_][]const u8{
        "vendor/src/opus/celt/x86/x86_celt_map.c",
        "vendor/src/opus/celt/x86/x86cpu.c",
    };

    const celt_sources_sse = &[_][]const u8{
        "vendor/src/opus/celt/x86/pitch_sse.c",
    };

    const celt_sources_sse2 = &[_][]const u8{
        "vendor/src/opus/celt/x86/pitch_sse2.c",
        "vendor/src/opus/celt/x86/vq_sse2.c",
    };

    const celt_sources_sse4_1 = &[_][]const u8{
        "vendor/src/opus/celt/x86/celt_lpc_sse4_1.c",
        "vendor/src/opus/celt/x86/pitch_sse4_1.c",
    };

    const celt_sources_arm = &[_][]const u8{
        "vendor/src/opus/celt/arm/arm_celt_map.c",
        "vendor/src/opus/celt/arm/armcpu.c",
    };

    const celt_sources_arm_neon = &[_][]const u8{
        "vendor/src/opus/celt/arm/celt_neon_intr.c",
        "vendor/src/opus/celt/arm/pitch_neon_intr.c",
    };

    const silk_sources_x86 = &[_][]const u8{
        "vendor/src/opus/silk/x86/x86_silk_map.c",
    };

    const silk_sources_sse4_1 = &[_][]const u8{
        "vendor/src/opus/silk/x86/NSQ_sse4_1.c",
        "vendor/src/opus/silk/x86/NSQ_del_dec_sse4_1.c",
        "vendor/src/opus/silk/x86/VAD_sse4_1.c",
        "vendor/src/opus/silk/x86/VQ_WMat_EC_sse4_1.c",
    };

    const silk_sources_arm = &[_][]const u8{
        "vendor/src/opus/silk/arm/arm_silk_map.c",
    };

    const silk_sources_arm_neon = &[_][]const u8{
        "vendor/src/opus/silk/arm/biquad_alt_neon_intr.c",
        "vendor/src/opus/silk/arm/LPC_inv_pred_gain_neon_intr.c",
        "vendor/src/opus/silk/arm/NSQ_del_dec_neon_intr.c",
        "vendor/src/opus/silk/arm/NSQ_neon.c",
    };

    const silk_sources_float = &[_][]const u8{
        "vendor/src/opus/silk/float/apply_sine_window_FLP.c",
        "vendor/src/opus/silk/float/corrMatrix_FLP.c",
        "vendor/src/opus/silk/float/encode_frame_FLP.c",
        "vendor/src/opus/silk/float/find_LPC_FLP.c",
        "vendor/src/opus/silk/float/find_LTP_FLP.c",
        "vendor/src/opus/silk/float/find_pitch_lags_FLP.c",
        "vendor/src/opus/silk/float/find_pred_coefs_FLP.c",
        "vendor/src/opus/silk/float/LPC_analysis_filter_FLP.c",
        "vendor/src/opus/silk/float/LTP_analysis_filter_FLP.c",
        "vendor/src/opus/silk/float/LTP_scale_ctrl_FLP.c",
        "vendor/src/opus/silk/float/noise_shape_analysis_FLP.c",
        "vendor/src/opus/silk/float/process_gains_FLP.c",
        "vendor/src/opus/silk/float/regularize_correlations_FLP.c",
        "vendor/src/opus/silk/float/residual_energy_FLP.c",
        "vendor/src/opus/silk/float/warped_autocorrelation_FLP.c",
        "vendor/src/opus/silk/float/wrappers_FLP.c",
        "vendor/src/opus/silk/float/autocorrelation_FLP.c",
        "vendor/src/opus/silk/float/burg_modified_FLP.c",
        "vendor/src/opus/silk/float/bwexpander_FLP.c",
        "vendor/src/opus/silk/float/energy_FLP.c",
        "vendor/src/opus/silk/float/inner_product_FLP.c",
        "vendor/src/opus/silk/float/k2a_FLP.c",
        "vendor/src/opus/silk/float/LPC_inv_pred_gain_FLP.c",
        "vendor/src/opus/silk/float/pitch_analysis_core_FLP.c",
        "vendor/src/opus/silk/float/scale_copy_vector_FLP.c",
        "vendor/src/opus/silk/float/scale_vector_FLP.c",
        "vendor/src/opus/silk/float/schur_FLP.c",
        "vendor/src/opus/silk/float/sort_FLP.c",
    };

    // the actual library
    const libopus = b.addStaticLibrary(.{ .name = "libopus", .target = target, .optimize = optimize });
    libopus.linkLibC();

    libopus.defineCMacro("USE_ALLOCA", null);
    libopus.defineCMacro("OPUS_BUILD", null);
    libopus.defineCMacro("HAVE_CONFIG_H", null);

    libopus.addIncludePath(b.path("vendor/include"));
    libopus.addIncludePath(b.path("vendor/src/opus/"));
    libopus.addIncludePath(b.path("vendor/src/opus/src/"));
    libopus.addIncludePath(b.path("vendor/src/opus/celt/"));
    libopus.addIncludePath(b.path("vendor/src/opus/celt/arm"));
    libopus.addIncludePath(b.path("vendor/src/opus/silk/"));
    libopus.addIncludePath(b.path("vendor/src/opus/silk/float"));
    libopus.addIncludePath(b.path("vendor/src/opus/silk/fixed"));

    libopus.addCSourceFiles(.{ .files = sources ++ silk_sources_float, .flags = &.{} });
    if (target.result.cpu.arch.isX86()) {
        const sse = target.result.cpu.features.isEnabled(@intFromEnum(std.Target.x86.Feature.sse));
        const sse2 = target.result.cpu.features.isEnabled(@intFromEnum(std.Target.x86.Feature.sse2));
        const sse4_1 = target.result.cpu.features.isEnabled(@intFromEnum(std.Target.x86.Feature.sse4_1));

        // addConfigHeader is a bit painful to work with when the check is #if defined(FOO)
        if (sse and sse2 and sse4_1) {
            const config_header = b.addConfigHeader(.{ .style = .blank }, .{
                .OPUS_X86_MAY_HAVE_SSE = 1,
                .OPUS_X86_MAY_HAVE_SSE2 = 1,
                .OPUS_X86_MAY_HAVE_SSE4_1 = 1,
                .OPUS_X86_PRESUME_SSE = 1,
                .OPUS_X86_PRESUME_SSE2 = 1,
                .OPUS_X86_PRESUME_SSE4_1 = 1,
            });
            libopus.addConfigHeader(config_header);
        } else if (sse and sse2) {
            const config_header = b.addConfigHeader(.{ .style = .blank }, .{
                .OPUS_X86_MAY_HAVE_SSE = 1,
                .OPUS_X86_MAY_HAVE_SSE2 = 1,
                .OPUS_X86_PRESUME_SSE = 1,
                .OPUS_X86_PRESUME_SSE2 = 1,
            });
            libopus.addConfigHeader(config_header);
        } else if (sse) {
            const config_header = b.addConfigHeader(.{ .style = .blank }, .{
                .OPUS_X86_MAY_HAVE_SSE = 1,
                .OPUS_X86_PRESUME_SSE = 1,
            });
            libopus.addConfigHeader(config_header);
        }

        libopus.addCSourceFiles(.{ .files = celt_sources_x86 ++ silk_sources_x86, .flags = &.{} });
        if (sse) {
            libopus.addCSourceFiles(.{ .files = celt_sources_sse, .flags = &.{} });
        }

        if (sse2) {
            libopus.addCSourceFiles(.{ .files = celt_sources_sse2, .flags = &.{} });
        }

        if (sse4_1) {
            libopus.addCSourceFiles(.{ .files = celt_sources_sse4_1 ++ silk_sources_sse4_1, .flags = &.{} });
        }
    }

    if (target.result.cpu.arch.isAARCH64() or target.result.cpu.arch.isArm()) {
        const neon = target.result.cpu.features.isEnabled(@intFromEnum(std.Target.aarch64.Feature.neon)) or
            target.result.cpu.features.isEnabled(@intFromEnum(std.Target.arm.Feature.neon));

        const config_header = b.addConfigHeader(.{ .style = .blank }, .{
            .OPUS_ARM_MAY_HAVE_NEON_INTR = neon,
            .OPUS_ARM_PRESUME_NEON_INTR = neon,
        });
        libopus.addConfigHeader(config_header);
        libopus.addCSourceFiles(.{ .files = celt_sources_arm ++ silk_sources_arm, .flags = &.{} });

        if (neon) {
            libopus.addCSourceFiles(.{ .files = celt_sources_arm_neon ++ silk_sources_arm_neon, .flags = &.{} });
        }
    }

    return libopus;
}
