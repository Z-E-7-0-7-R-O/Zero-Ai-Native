// --- START OF FILE Biophysical.Telemetry.Spooler.cuh ---

#ifndef BIOPHYSICAL_TELEMETRY_SPOOLER_CUH
#define BIOPHYSICAL_TELEMETRY_SPOOLER_CUH

#include <cuda_runtime.h>
#include <cstdint>
#include <fstream>
#include <string>
#include <vector>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <atomic>
#include <chrono>

struct BiophysicalAccumulators {
    // Reduction Variables (Populations)
    double agent_atp_total;
    double agent_active_count;
    double agent_desens_total;
    double tissue_live_count;
    double sasp_total;
    double extracellular_atp_total;
    double scavenger_live_count;
    double scavenger_lipid_total;
    double scavenger_desens_total;

    // Proteomic & Genomic Scan Variables
    double prot_actb_total;
    double prot_abca1_total;
    double prot_receptors_total;
    double prot_cd47_max;
    double oncogenic_cell_count;
    double mutated_base_pairs_total;
    double senophage_neural_total;
    double scavenger_neural_total;
    double cd47_expression_total;

    // Dispersed tracking variables dynamically updated by Kernels
    double fao_atp_yield;
    double autophagy_yield;
    double trogocytosis_atp;
    double collapse_events;
    double macropinocytosis_volume;
    double trogocytosis_volume;
    double swarm_cooperation_density;
    double velocity_magnitude;
    double levy_walk_magnitude;
    double cil_suppression_index;
    double death_by_starvation;
    double death_by_lipotoxicity;
    double hovering_count;
    double death_count;
    double recruitment_count;

    // External subsystem accumulators
    double lbm_max_velocity;
    double total_parp_repairs;
    double parp_atp_tax;
    double total_ros_strikes;

    // Phase 95: VRAM-side Accumulators for precise locus hit-tracking
    double epoch_junk_dna_strikes;
    double epoch_coding_dna_strikes;
    double epoch_actb_strikes;
    double epoch_cd47_strikes;
    double epoch_cd47_repressor_strikes;
    double epoch_sirpa_strikes;
    double epoch_p2ry2_strikes;
    double epoch_abca1_strikes;
};

// Global device pointer used across subsystems for direct VRAM atomic accumulation
extern BiophysicalAccumulators* g_active_device_accumulators;

// Phase 94 & 95: Persistent CPU-Side Accumulator Struct for Absolute Integration
struct PersistentCumulativeState {
    double trogoptosis_collapse_events;
    double ros_bombardment_strikes;
    double parp_successful_repairs;
    double parp_atp_depletion_tax;
    double macropinocytosis_clearance_volume;
    double trogocytosis_nibbling_volume;
    double fao_metabolic_yield;
    double autophagy_yield;
    double agent_deaths_by_starvation;
    double agent_deaths_by_lipotoxicity;

    // Phase 95: Extended Cumulative Tracking
    double cumulative_junk_dna_strikes;
    double cumulative_coding_dna_strikes;
    double cumulative_actb_strikes;
    double cumulative_cd47_strikes;
    double cumulative_cd47_repressor_strikes;
    double cumulative_sirpa_strikes;
    double cumulative_p2ry2_strikes;
    double cumulative_abca1_strikes;
};

// Phase 96: Dual-Chronology Extended Payload Matrix (89 Metrics)
struct TelemetryRecordPayload {
    unsigned long long tick;
    double hardware_elapsed_ms; // Phase 96: Passed as lightweight double to prevent std::string ring buffer dynamic allocation hazards

    double static_total_base_pairs;
    double static_agent_base_pairs;
    double static_env_voxels;
    double static_total_agents;
    double vram_total;
    double vram_used;
    double live_senescent;
    double live_senophage;
    double live_scavenger;
    double active_genomic_pool;
    double active_oncogenic;
    double max_cd47_overexpression;

    double trogoptosis_collapse_events;
    double cumulative_trogoptosis_collapse_events;

    double total_ros_strikes;
    double cumulative_ros_bombardment_strikes;

    double epoch_junk_dna_strikes;
    double cumulative_junk_dna_strikes;
    double epoch_coding_dna_strikes;
    double cumulative_coding_dna_strikes;

    double epoch_actb_strikes;
    double cumulative_actb_strikes;
    double epoch_cd47_strikes;
    double cumulative_cd47_strikes;
    double epoch_cd47_repressor_strikes;
    double cumulative_cd47_repressor_strikes;
    double epoch_sirpa_strikes;
    double cumulative_sirpa_strikes;
    double epoch_p2ry2_strikes;
    double cumulative_p2ry2_strikes;
    double epoch_abca1_strikes;
    double cumulative_abca1_strikes;

    double epoch_junk_vs_coding_ratio;
    double cumulative_junk_vs_coding_ratio;

    double active_mutated_base_pairs;

    double total_parp_repairs;
    double cumulative_parp_successful_repairs;

    double parp_atp_tax;
    double cumulative_parp_atp_depletion_tax;

    double mean_macrophage_velocity;
    double mean_levy_walk;
    double swarm_cooperation_density;
    double cil_suppression_index;

    double macropinocytosis_volume;
    double cumulative_macropinocytosis_clearance_volume;

    double trogocytosis_volume;
    double cumulative_trogocytosis_nibbling_volume;

    double macro_trogo_ratio;
    double global_atp_pool;

    double total_fao_yield;
    double cumulative_fao_metabolic_yield;

    double total_autophagy_yield;
    double cumulative_autophagy_yield;

    double mean_lipid_burden;

    double death_starvation;
    double cumulative_agent_deaths_by_starvation;

    double death_lipotoxicity;
    double cumulative_agent_deaths_by_lipotoxicity;

    double receptor_desensitization;
    double global_sasp;
    double global_extracellular_atp;
    double mean_actb;
    double mean_abca1;
    double mean_sirpa;
    double mean_p2ry2;
    double mean_senophage_neural;
    double mean_senophage_fatigue;
    double mean_scavenger_neural;
    double mean_scavenger_fatigue;
    double mean_ph_index;
    double mean_cancer_hypertrophy;
    double mean_nuclear_fluorescence;
    double biological_compute_latency;
    double optical_render_latency;
    double vram_cache_hit_rate;
    double lbm_max_velocity;
    double sync_stall_count;

    double wddm_os_vram_eviction_penalty_bytes;
    double wddm_vram_budget_exceeded_flag;
    double cuda_hardware_command_queue_depth;
    double api_interop_map_lock_latency_ms;
    double dxgi_present_blocking_latency_ms;
    double thermodynamic_accumulator_debt_ms;
    double gpu_thermal_throttling_state;

    double optical_fps;
    double vram_idle_time_ms;
};

class PreallocatedTelemetryRingBuffer {
public:
    PreallocatedTelemetryRingBuffer(size_t capacity);
    ~PreallocatedTelemetryRingBuffer();

    void PushRecord(const TelemetryRecordPayload& payload);
    bool PopRecord(TelemetryRecordPayload& out_payload);
    bool HasPending() const;

private:
    std::vector<TelemetryRecordPayload> buffer;
    size_t buffer_capacity;
    std::atomic<size_t> write_index;
    std::atomic<size_t> read_index;
};

class AsynchronousTelemetrySpooler {
public:
    AsynchronousTelemetrySpooler(const std::string& filename, size_t buffer_capacity);
    ~AsynchronousTelemetrySpooler();

    void SpoolData(const TelemetryRecordPayload& payload);
    void FlushAndTerminate();

private:
    std::ofstream csv_file;
    PreallocatedTelemetryRingBuffer ring_buffer;

    std::thread spooler_thread;
    std::mutex sleep_mutex;
    std::condition_variable wake_condition;
    std::atomic<bool> shutdown_flag;

    void SpoolerExecutionLoop();
    void WriteToCSV(const TelemetryRecordPayload& payload);
};

class BiophysicalTelemetryLogger {
public:
    BiophysicalTelemetryLogger(const std::string& filename);
    ~BiophysicalTelemetryLogger();

    void LogState(
        unsigned long long tick,
        float vram_total, float vram_used,
        bool trigger_genomic_scan,
        int agent_count, const float* d_agent_atp, const float* d_agent_desens, const float* d_agent_motors,
        int tissue_count, const float* d_integrity, const float* d_tissue_cd47,
        const float* d_sasp_grid, const float* d_atp_grid, int total_voxels,
        int scavenger_count, const float* d_scavenger_atp, const float* d_scavenger_motors, const float* d_scavenger_desens, const float* d_scavenger_lipid,
        const uint32_t* d_genome,
        const float* d_prot_actb, const float* d_prot_cd47, const float* d_prot_sirpa, const float* d_prot_p2ry2, const float* d_prot_abca1,
        double wddm_eviction_penalty, double wddm_budget_exceeded, double cuda_queue_depth,
        double interop_latency, double present_latency, double accumulator_debt, double thermal_throttling,
        double optical_fps, double vram_idle_time_ms,
        cudaStream_t stream
    );

    void FlushPendingTelemetry();

private:
    AsynchronousTelemetrySpooler* async_spooler;

    std::chrono::high_resolution_clock::time_point last_compute_timestamp;

    // Phase 96: The True Genesis Timestamp for Hardware Execution Correlation
    std::chrono::high_resolution_clock::time_point genesis_timestamp;

    double cumulative_sync_stalls;
    bool first_frame;

    PersistentCumulativeState cumulative_state;
};

#endif // BIOPHYSICAL_TELEMETRY_SPOOLER_CUH
// --- END OF FILE Biophysical.Telemetry.Spooler.cuh ---