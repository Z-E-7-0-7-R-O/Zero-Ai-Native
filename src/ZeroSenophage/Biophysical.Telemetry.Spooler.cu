// --- START OF FILE Biophysical.Telemetry.Spooler.cu ---

#include "Biophysical.Telemetry.Spooler.cuh"
#include "Biochemical.Constants.h"
#include <iostream>
#include <iomanip>
#include <cmath>

__device__ inline void Custom_Atomic_Max_Double(double* address, double value) {
    unsigned long long int* address_as_ull = (unsigned long long int*)address;
    unsigned long long int old = *address_as_ull, assumed;
    do {
        assumed = old;
        old = atomicCAS(address_as_ull, assumed, __double_as_longlong(fmax(value, __longlong_as_double(assumed))));
    } while (assumed != old);
}

BiophysicalAccumulators* g_active_device_accumulators = nullptr;

__global__ void Telemetry_Agent_Reduction_Kernel(int size, const float* atp_curr, const float* desens_curr, const float* motors, BiophysicalAccumulators* acc) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    double local_atp = 0.0;
    double local_active = 0.0;
    double local_desens = 0.0;
    double local_neural = 0.0;

    if (idx < size) {
        float current_atp = atp_curr[idx];
        local_atp = static_cast<double>(current_atp);
        local_active = static_cast<double>(0.5f + 0.5f * copysignf(1.0f, current_atp - 0.1f));
        local_desens = static_cast<double>(desens_curr[idx]);

        float nn_x = motors[0 * size + idx];
        float nn_y = motors[1 * size + idx];
        local_neural = static_cast<double>(sqrtf(nn_x * nn_x + nn_y * nn_y));
    }

    __shared__ double s_atp;
    __shared__ double s_active;
    __shared__ double s_desens;
    __shared__ double s_neural;

    if (threadIdx.x == 0) {
        s_atp = 0.0; s_active = 0.0; s_desens = 0.0; s_neural = 0.0;
    }
    __syncthreads();

    atomicAdd(&s_atp, local_atp);
    atomicAdd(&s_active, local_active);
    atomicAdd(&s_desens, local_desens);
    atomicAdd(&s_neural, local_neural);
    __syncthreads();

    if (threadIdx.x == 0) {
        atomicAdd(&(acc->agent_atp_total), s_atp);
        atomicAdd(&(acc->agent_active_count), s_active);
        atomicAdd(&(acc->agent_desens_total), s_desens);
        atomicAdd(&(acc->senophage_neural_total), s_neural);
    }
}

__global__ void Telemetry_Tissue_Reduction_Kernel(int size, const float* integrity_curr, BiophysicalAccumulators* acc) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    double local_alive = 0.0;
    if (idx < size) {
        local_alive = static_cast<double>(0.5f + 0.5f * copysignf(1.0f, integrity_curr[idx] - 0.001f));
    }

    __shared__ double s_alive;
    if (threadIdx.x == 0) s_alive = 0.0;
    __syncthreads();

    atomicAdd(&s_alive, local_alive);
    __syncthreads();

    if (threadIdx.x == 0) {
        atomicAdd(&(acc->tissue_live_count), s_alive);
    }
}

__global__ void Telemetry_SASP_ATP_Reduction_Kernel(int total_voxels, const float* sasp_grid, const float* atp_grid, BiophysicalAccumulators* acc) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    double local_sasp = 0.0;
    double local_atp = 0.0;

    if (idx < total_voxels) {
        local_sasp = static_cast<double>(sasp_grid[idx]);
        local_atp = static_cast<double>(atp_grid[idx]);
    }

    __shared__ double s_sasp;
    __shared__ double s_atp;

    if (threadIdx.x == 0) {
        s_sasp = 0.0; s_atp = 0.0;
    }
    __syncthreads();

    atomicAdd(&s_sasp, local_sasp);
    atomicAdd(&s_atp, local_atp);
    __syncthreads();

    if (threadIdx.x == 0) {
        atomicAdd(&(acc->sasp_total), s_sasp);
        atomicAdd(&(acc->extracellular_atp_total), s_atp);
    }
}

__global__ void Telemetry_Scavenger_Reduction_Kernel(int size, const float* atp_curr, const float* desens_curr, const float* lipid_curr, const float* motors, BiophysicalAccumulators* acc) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    double local_alive = 0.0;
    double local_lipid = 0.0;
    double local_atp = 0.0;
    double local_desens = 0.0;
    double local_neural = 0.0;

    if (idx < size) {
        float current_atp = atp_curr[idx];
        local_alive = static_cast<double>(0.5f + 0.5f * copysignf(1.0f, current_atp - 0.1f));
        local_lipid = static_cast<double>(lipid_curr[idx]);
        local_atp = static_cast<double>(current_atp);
        local_desens = static_cast<double>(desens_curr[idx]);

        float nn_x = motors[0 * size + idx];
        float nn_y = motors[1 * size + idx];
        local_neural = static_cast<double>(sqrtf(nn_x * nn_x + nn_y * nn_y));
    }

    __shared__ double s_alive;
    __shared__ double s_lipid;
    __shared__ double s_atp;
    __shared__ double s_desens;
    __shared__ double s_neural;

    if (threadIdx.x == 0) {
        s_alive = 0.0; s_lipid = 0.0; s_atp = 0.0; s_desens = 0.0; s_neural = 0.0;
    }
    __syncthreads();

    atomicAdd(&s_alive, local_alive);
    atomicAdd(&s_lipid, local_lipid);
    atomicAdd(&s_atp, local_atp);
    atomicAdd(&s_desens, local_desens);
    atomicAdd(&s_neural, local_neural);
    __syncthreads();

    if (threadIdx.x == 0) {
        atomicAdd(&(acc->scavenger_live_count), s_alive);
        atomicAdd(&(acc->scavenger_lipid_total), s_lipid);
        atomicAdd(&(acc->agent_atp_total), s_atp);
        atomicAdd(&(acc->scavenger_desens_total), s_desens);
        atomicAdd(&(acc->scavenger_neural_total), s_neural);
    }
}

__global__ void Genomic_Proteomic_Reduction_Kernel(
    int total_agents,
    const uint32_t* d_genome, size_t words_per_agent,
    const float* d_prot_actb_curr, const float* d_prot_cd47_curr, const float* d_prot_sirpa_curr, const float* d_prot_p2ry2_curr, const float* d_prot_abca1_curr,
    unsigned long long sys_tick, BiophysicalAccumulators* acc)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    double local_actb = 0.0;
    double local_abca1 = 0.0;
    double local_receptors = 0.0;
    double local_cd47_max = 0.0;
    double local_oncogenic = 0.0;
    double local_cd47_total = 0.0;
    double local_mutations = 0.0;

    if (idx < total_agents) {
        local_actb = static_cast<double>(d_prot_actb_curr[idx]);
        local_abca1 = static_cast<double>(d_prot_abca1_curr[idx]);
        local_receptors = static_cast<double>(d_prot_sirpa_curr[idx] + d_prot_p2ry2_curr[idx]);
        local_cd47_max = static_cast<double>(d_prot_cd47_curr[idx]);
        local_oncogenic = static_cast<double>(0.5f + 0.5f * copysignf(1.0f, d_prot_cd47_curr[idx] - 1.1f));
        local_cd47_total = static_cast<double>(d_prot_cd47_curr[idx]);

        size_t base_address = static_cast<size_t>(idx) * words_per_agent;
        size_t total_mutations = 0;
        uint32_t wild_type = 0xAAAAAAAA;
        size_t offsets[6] = { BiophysicalConstants::LOCUS_OFFSET_ACTB, BiophysicalConstants::LOCUS_OFFSET_CD47, BiophysicalConstants::LOCUS_OFFSET_SIRPA, BiophysicalConstants::LOCUS_OFFSET_P2RY2, BiophysicalConstants::LOCUS_OFFSET_ABCA1, BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR };
        size_t lengths[6] = { BiophysicalConstants::LOCUS_LENGTH_ACTB, BiophysicalConstants::LOCUS_LENGTH_CD47, BiophysicalConstants::LOCUS_LENGTH_SIRPA, BiophysicalConstants::LOCUS_LENGTH_P2RY2, BiophysicalConstants::LOCUS_LENGTH_ABCA1, BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR };

        uint32_t shift = sys_tick % 100;

        for (int k = 0; k < 6; ++k) {
            size_t effective_length = lengths[k];
            for (size_t i = shift; i < effective_length; i += 100) {
                uint32_t read_sequence = d_genome[base_address + offsets[k] + i];
                total_mutations += __popc(read_sequence ^ wild_type);
            }
        }
        local_mutations = static_cast<double>(total_mutations) * 100.0;
    }

    __shared__ double s_actb;
    __shared__ double s_abca1;
    __shared__ double s_receptors;
    __shared__ double s_cd47_max;
    __shared__ double s_oncogenic;
    __shared__ double s_cd47_total;
    __shared__ double s_mutations;

    if (threadIdx.x == 0) {
        s_actb = 0.0; s_abca1 = 0.0; s_receptors = 0.0; s_cd47_max = 0.0;
        s_oncogenic = 0.0; s_cd47_total = 0.0; s_mutations = 0.0;
    }
    __syncthreads();

    atomicAdd(&s_actb, local_actb);
    atomicAdd(&s_abca1, local_abca1);
    atomicAdd(&s_receptors, local_receptors);
    Custom_Atomic_Max_Double(&s_cd47_max, local_cd47_max);
    atomicAdd(&s_oncogenic, local_oncogenic);
    atomicAdd(&s_cd47_total, local_cd47_total);
    atomicAdd(&s_mutations, local_mutations);
    __syncthreads();

    if (threadIdx.x == 0) {
        atomicAdd(&(acc->prot_actb_total), s_actb);
        atomicAdd(&(acc->prot_abca1_total), s_abca1);
        atomicAdd(&(acc->prot_receptors_total), s_receptors);
        Custom_Atomic_Max_Double(&(acc->prot_cd47_max), s_cd47_max);
        atomicAdd(&(acc->oncogenic_cell_count), s_oncogenic);
        atomicAdd(&(acc->cd47_expression_total), s_cd47_total);
        atomicAdd(&(acc->mutated_base_pairs_total), s_mutations);
    }
}

PreallocatedTelemetryRingBuffer::PreallocatedTelemetryRingBuffer(size_t capacity) : buffer_capacity(capacity) {
    buffer.resize(buffer_capacity);
    write_index.store(0, std::memory_order_relaxed);
    read_index.store(0, std::memory_order_relaxed);
}

PreallocatedTelemetryRingBuffer::~PreallocatedTelemetryRingBuffer() {}

void PreallocatedTelemetryRingBuffer::PushRecord(const TelemetryRecordPayload& payload) {
    size_t current_write = write_index.load(std::memory_order_relaxed);
    buffer[current_write % buffer_capacity] = payload;
    write_index.store(current_write + 1, std::memory_order_release);
}

bool PreallocatedTelemetryRingBuffer::PopRecord(TelemetryRecordPayload& out_payload) {
    size_t current_read = read_index.load(std::memory_order_relaxed);
    if (current_read < write_index.load(std::memory_order_acquire)) {
        out_payload = buffer[current_read % buffer_capacity];
        read_index.store(current_read + 1, std::memory_order_relaxed);
        return true;
    }
    return false;
}

bool PreallocatedTelemetryRingBuffer::HasPending() const {
    return read_index.load(std::memory_order_relaxed) < write_index.load(std::memory_order_acquire);
}

AsynchronousTelemetrySpooler::AsynchronousTelemetrySpooler(const std::string& filename, size_t buffer_capacity)
    : ring_buffer(buffer_capacity) {

    csv_file.open(filename, std::ios::out | std::ios::trunc);
    if (csv_file.is_open()) {
        // Phase 96: The pristine 89-column Dual-Chronology header precisely as specified
        csv_file << "Thermodynamic_Tick,Biological_In_Silico_Time_Elapsed,Hardware_Execution_Time_Elapsed,"
            << "Static_Total_Ecosystem_BasePairs,Static_Agent_BasePairs,Static_Environment_Voxels,Static_Total_Agents_Initialized,"
            << "Hardware_VRAM_Total_Bytes,Hardware_VRAM_Used_Bytes,"
            << "Live_Senescent_Cells,Live_Senophages,Live_Scavengers,Active_Genomic_Pool_BasePairs,"
            << "Active_Oncogenic_Cells,Max_CD47_Overexpression,"
            << "Trogoptosis_Collapse_Events,Cumulative_Trogoptosis_Collapse_Events,"
            << "Total_ROS_Bombardment_Strikes,Cumulative_ROS_Bombardment_Strikes,"
            << "Epoch_Junk_DNA_Mutational_Strikes,Cumulative_Junk_DNA_Mutational_Strikes,"
            << "Epoch_Coding_DNA_Mutational_Strikes,Cumulative_Coding_DNA_Mutational_Strikes,"
            << "Epoch_ACTB_Locus_Strikes,Cumulative_ACTB_Locus_Strikes,"
            << "Epoch_CD47_Locus_Strikes,Cumulative_CD47_Locus_Strikes,"
            << "Epoch_CD47_Repressor_Locus_Strikes,Cumulative_CD47_Repressor_Locus_Strikes,"
            << "Epoch_SIRPA_Locus_Strikes,Cumulative_SIRPA_Locus_Strikes,"
            << "Epoch_P2RY2_Locus_Strikes,Cumulative_P2RY2_Locus_Strikes,"
            << "Epoch_ABCA1_Locus_Strikes,Cumulative_ABCA1_Locus_Strikes,"
            << "Epoch_Junk_vs_Coding_Mutation_Ratio,Cumulative_Junk_vs_Coding_Mutation_Ratio,"
            << "Active_Mutated_BasePairs,"
            << "Total_PARP_Successful_Repairs,Cumulative_PARP_Successful_Repairs,"
            << "PARP_ATP_Depletion_Tax,Cumulative_PARP_ATP_Depletion_Tax,"
            << "Mean_Macrophage_Velocity_um_tick,Mean_Levy_Walk_Magnitude,Swarm_Cooperation_Density,Contact_Inhibition_Suppression_Index,"
            << "Macropinocytosis_Clearance_Volume,Cumulative_Macropinocytosis_Clearance_Volume,"
            << "Trogocytosis_Nibbling_Volume,Cumulative_Trogocytosis_Nibbling_Volume,"
            << "Macropinocytosis_vs_Trogocytosis_Ratio,Global_ATP_Pool,"
            << "Total_FAO_Metabolic_Yield,Cumulative_FAO_Metabolic_Yield,"
            << "Total_Autophagy_Yield,Cumulative_Autophagy_Yield,"
            << "Mean_Lipid_Toxicity_Burden,"
            << "Agent_Deaths_By_Starvation,Cumulative_Agent_Deaths_By_Starvation,"
            << "Agent_Deaths_By_Lipotoxicity,Cumulative_Agent_Deaths_By_Lipotoxicity,"
            << "Receptor_Desensitization_Index,Global_SASP_Concentration,Global_Extracellular_ATP_Concentration,"
            << "Mean_ACTB_Expression,Mean_ABCA1_Expression,Mean_SIRPA_Expression,Mean_P2RY2_Expression,"
            << "Mean_Senophage_Neural_Activation,Mean_Senophage_Olfactory_Fatigue,Mean_Scavenger_Neural_Activation,Mean_Scavenger_Olfactory_Fatigue,"
            << "Mean_pH_Acidification_Index,Mean_Cancer_Optical_Hypertrophy,Mean_Nuclear_Mutational_Fluorescence,"
            << "Biological_Compute_Latency_ms,Optical_Render_Latency_ms,VRAM_Cache_Hit_Rate,LBM_Max_Velocity_Magnitude,Sync_Stall_Count,"
            << "WDDM_OS_VRAM_Eviction_Penalty_Bytes,WDDM_VRAM_Budget_Exceeded_Flag,CUDA_Hardware_Command_Queue_Depth,API_Interop_Map_Lock_Latency_ms,DXGI_Present_Blocking_Latency_ms,Thermodynamic_Accumulator_Debt_ms,GPU_Thermal_Throttling_State,"
            << "Optical_FPS,VRAM_Idle_Time_ms\n";
    }

    shutdown_flag.store(false, std::memory_order_relaxed);
    spooler_thread = std::thread(&AsynchronousTelemetrySpooler::SpoolerExecutionLoop, this);
}

AsynchronousTelemetrySpooler::~AsynchronousTelemetrySpooler() {
    FlushAndTerminate();
}

void AsynchronousTelemetrySpooler::FlushAndTerminate() {
    if (!shutdown_flag.load(std::memory_order_relaxed)) {
        shutdown_flag.store(true, std::memory_order_release);
        wake_condition.notify_all();
        if (spooler_thread.joinable()) {
            spooler_thread.join();
        }
        if (csv_file.is_open()) {
            csv_file.close();
        }
    }
}

void AsynchronousTelemetrySpooler::SpoolData(const TelemetryRecordPayload& payload) {
    ring_buffer.PushRecord(payload);
    wake_condition.notify_one();
}

void AsynchronousTelemetrySpooler::WriteToCSV(const TelemetryRecordPayload& payload) {
    if (csv_file.is_open()) {

        // Phase 96: Zero-Cost CPU-Side Time Translation Formatting
        unsigned long long bio_sec = payload.tick;
        unsigned long long b_days = bio_sec / 86400;
        unsigned long long b_hours = (bio_sec % 86400) / 3600;
        unsigned long long b_minutes = (bio_sec % 3600) / 60;
        unsigned long long b_seconds = bio_sec % 60;

        unsigned long long hw_total_ms = static_cast<unsigned long long>(payload.hardware_elapsed_ms);
        unsigned long long h_ms = hw_total_ms % 1000;
        unsigned long long h_sec = (hw_total_ms / 1000) % 60;
        unsigned long long h_min = (hw_total_ms / 60000) % 60;
        unsigned long long h_hr = (hw_total_ms / 3600000);

        csv_file << std::fixed << std::setprecision(6)
            << payload.tick << ",";

        // Rendering Biological Time (DD:HH:MM:SS)
        csv_file << std::setfill('0') << std::setw(2) << b_days << ":"
            << std::setfill('0') << std::setw(2) << b_hours << ":"
            << std::setfill('0') << std::setw(2) << b_minutes << ":"
            << std::setfill('0') << std::setw(2) << b_seconds << ",";

        // Rendering Hardware Time (HH:MM:SS.mmm)
        csv_file << std::setfill('0') << std::setw(2) << h_hr << ":"
            << std::setfill('0') << std::setw(2) << h_min << ":"
            << std::setfill('0') << std::setw(2) << h_sec << "."
            << std::setfill('0') << std::setw(3) << h_ms << ",";

        // Revert setfill for numerical data to avoid leading zeros in floats
        csv_file << std::setfill(' ');

        csv_file << payload.static_total_base_pairs << ","
            << payload.static_agent_base_pairs << ","
            << payload.static_env_voxels << ","
            << payload.static_total_agents << ","
            << payload.vram_total << ","
            << payload.vram_used << ","
            << payload.live_senescent << ","
            << payload.live_senophage << ","
            << payload.live_scavenger << ","
            << payload.active_genomic_pool << ","
            << payload.active_oncogenic << ","
            << payload.max_cd47_overexpression << ","
            << payload.trogoptosis_collapse_events << ","
            << payload.cumulative_trogoptosis_collapse_events << ","
            << payload.total_ros_strikes << ","
            << payload.cumulative_ros_bombardment_strikes << ","
            << payload.epoch_junk_dna_strikes << ","
            << payload.cumulative_junk_dna_strikes << ","
            << payload.epoch_coding_dna_strikes << ","
            << payload.cumulative_coding_dna_strikes << ","
            << payload.epoch_actb_strikes << ","
            << payload.cumulative_actb_strikes << ","
            << payload.epoch_cd47_strikes << ","
            << payload.cumulative_cd47_strikes << ","
            << payload.epoch_cd47_repressor_strikes << ","
            << payload.cumulative_cd47_repressor_strikes << ","
            << payload.epoch_sirpa_strikes << ","
            << payload.cumulative_sirpa_strikes << ","
            << payload.epoch_p2ry2_strikes << ","
            << payload.cumulative_p2ry2_strikes << ","
            << payload.epoch_abca1_strikes << ","
            << payload.cumulative_abca1_strikes << ","
            << payload.epoch_junk_vs_coding_ratio << ","
            << payload.cumulative_junk_vs_coding_ratio << ","
            << payload.active_mutated_base_pairs << ","
            << payload.total_parp_repairs << ","
            << payload.cumulative_parp_successful_repairs << ","
            << payload.parp_atp_tax << ","
            << payload.cumulative_parp_atp_depletion_tax << ","
            << payload.mean_macrophage_velocity << ","
            << payload.mean_levy_walk << ","
            << payload.swarm_cooperation_density << ","
            << payload.cil_suppression_index << ","
            << payload.macropinocytosis_volume << ","
            << payload.cumulative_macropinocytosis_clearance_volume << ","
            << payload.trogocytosis_volume << ","
            << payload.cumulative_trogocytosis_nibbling_volume << ","
            << payload.macro_trogo_ratio << ","
            << payload.global_atp_pool << ","
            << payload.total_fao_yield << ","
            << payload.cumulative_fao_metabolic_yield << ","
            << payload.total_autophagy_yield << ","
            << payload.cumulative_autophagy_yield << ","
            << payload.mean_lipid_burden << ","
            << payload.death_starvation << ","
            << payload.cumulative_agent_deaths_by_starvation << ","
            << payload.death_lipotoxicity << ","
            << payload.cumulative_agent_deaths_by_lipotoxicity << ","
            << payload.receptor_desensitization << ","
            << payload.global_sasp << ","
            << payload.global_extracellular_atp << ","
            << payload.mean_actb << ","
            << payload.mean_abca1 << ","
            << payload.mean_sirpa << ","
            << payload.mean_p2ry2 << ","
            << payload.mean_senophage_neural << ","
            << payload.mean_senophage_fatigue << ","
            << payload.mean_scavenger_neural << ","
            << payload.mean_scavenger_fatigue << ","
            << payload.mean_ph_index << ","
            << payload.mean_cancer_hypertrophy << ","
            << payload.mean_nuclear_fluorescence << ","
            << payload.biological_compute_latency << ","
            << payload.optical_render_latency << ","
            << payload.vram_cache_hit_rate << ","
            << payload.lbm_max_velocity << ","
            << payload.sync_stall_count << ","
            << payload.wddm_os_vram_eviction_penalty_bytes << ","
            << payload.wddm_vram_budget_exceeded_flag << ","
            << payload.cuda_hardware_command_queue_depth << ","
            << payload.api_interop_map_lock_latency_ms << ","
            << payload.dxgi_present_blocking_latency_ms << ","
            << payload.thermodynamic_accumulator_debt_ms << ","
            << payload.gpu_thermal_throttling_state << ","
            << payload.optical_fps << ","
            << payload.vram_idle_time_ms << "\n";
    }
}

void AsynchronousTelemetrySpooler::SpoolerExecutionLoop() {
    while (true) {
        TelemetryRecordPayload payload;
        bool popped = ring_buffer.PopRecord(payload);

        if (popped) {
            WriteToCSV(payload);
        }
        else {
            if (shutdown_flag.load(std::memory_order_acquire)) {
                break;
            }
            std::unique_lock<std::mutex> lock(sleep_mutex);
            wake_condition.wait(lock, [this]() {
                return ring_buffer.HasPending() || shutdown_flag.load(std::memory_order_acquire);
                });
        }
    }
}

BiophysicalAccumulators* h_acc_A = nullptr;
BiophysicalAccumulators* h_acc_B = nullptr;
BiophysicalAccumulators* d_acc_A = nullptr;
BiophysicalAccumulators* d_acc_B = nullptr;

cudaStream_t telemetry_dma_stream;
cudaEvent_t telemetry_copy_event_A;
cudaEvent_t telemetry_copy_event_B;
cudaEvent_t compute_done_event;

struct TelemetryCPUContext {
    double vram_total;
    double vram_used;
    double compute_lat_ms;
    double cumulative_sync_stalls;
    unsigned long long tick;

    // Phase 96: Propagating precise hardware elapsed time without locking the GPU
    double hw_elapsed_ms;

    double wddm_eviction_penalty;
    double wddm_budget_exceeded;
    double cuda_queue_depth;
    double interop_latency;
    double present_latency;
    double accumulator_debt;
    double thermal_throttling;
    double optical_fps;
    double vram_idle_time_ms;
};

TelemetryCPUContext cpu_ctx_A, cpu_ctx_B;
bool is_buffer_A_active = true;
bool is_first_telemetry_frame = true;

BiophysicalTelemetryLogger::BiophysicalTelemetryLogger(const std::string& filename) {
    cudaMallocHost(&h_acc_A, sizeof(BiophysicalAccumulators));
    cudaMallocHost(&h_acc_B, sizeof(BiophysicalAccumulators));

    cudaMalloc(&d_acc_A, sizeof(BiophysicalAccumulators));
    cudaMalloc(&d_acc_B, sizeof(BiophysicalAccumulators));

    cudaMemset(d_acc_A, 0, sizeof(BiophysicalAccumulators));
    cudaMemset(d_acc_B, 0, sizeof(BiophysicalAccumulators));

    g_active_device_accumulators = d_acc_A;

    cudaStreamCreateWithFlags(&telemetry_dma_stream, cudaStreamNonBlocking);

    cudaEventCreateWithFlags(&telemetry_copy_event_A, cudaEventDisableTiming);
    cudaEventCreateWithFlags(&telemetry_copy_event_B, cudaEventDisableTiming);
    cudaEventCreateWithFlags(&compute_done_event, cudaEventDisableTiming);

    last_compute_timestamp = std::chrono::high_resolution_clock::now();

    // Phase 96: Anchoring the absolute Genesis Timestamp of the simulation run
    genesis_timestamp = std::chrono::high_resolution_clock::now();

    cumulative_sync_stalls = 0.0;
    is_buffer_A_active = true;
    is_first_telemetry_frame = true;

    cumulative_state.trogoptosis_collapse_events = 0.0;
    cumulative_state.ros_bombardment_strikes = 0.0;
    cumulative_state.parp_successful_repairs = 0.0;
    cumulative_state.parp_atp_depletion_tax = 0.0;
    cumulative_state.macropinocytosis_clearance_volume = 0.0;
    cumulative_state.trogocytosis_nibbling_volume = 0.0;
    cumulative_state.fao_metabolic_yield = 0.0;
    cumulative_state.autophagy_yield = 0.0;
    cumulative_state.agent_deaths_by_starvation = 0.0;
    cumulative_state.agent_deaths_by_lipotoxicity = 0.0;

    cumulative_state.cumulative_junk_dna_strikes = 0.0;
    cumulative_state.cumulative_coding_dna_strikes = 0.0;
    cumulative_state.cumulative_actb_strikes = 0.0;
    cumulative_state.cumulative_cd47_strikes = 0.0;
    cumulative_state.cumulative_cd47_repressor_strikes = 0.0;
    cumulative_state.cumulative_sirpa_strikes = 0.0;
    cumulative_state.cumulative_p2ry2_strikes = 0.0;
    cumulative_state.cumulative_abca1_strikes = 0.0;

    async_spooler = new AsynchronousTelemetrySpooler(filename, 4194304ULL);
}

BiophysicalTelemetryLogger::~BiophysicalTelemetryLogger() {
    if (async_spooler) {
        delete async_spooler;
    }
    cudaFreeHost(h_acc_A);
    cudaFreeHost(h_acc_B);
    cudaFree(d_acc_A);
    cudaFree(d_acc_B);
    cudaStreamDestroy(telemetry_dma_stream);
    cudaEventDestroy(telemetry_copy_event_A);
    cudaEventDestroy(telemetry_copy_event_B);
    cudaEventDestroy(compute_done_event);
}

void BiophysicalTelemetryLogger::FlushPendingTelemetry() {
    if (async_spooler) {
        async_spooler->FlushAndTerminate();
    }
}

void BiophysicalTelemetryLogger::LogState(
    unsigned long long tick, float vram_total, float vram_used, bool trigger_genomic_scan,
    int agent_count, const float* d_agent_atp_curr, const float* d_agent_desens_curr, const float* d_agent_motors,
    int tissue_count, const float* d_integrity_curr, const float* d_tissue_cd47_curr,
    const float* d_sasp_grid, const float* d_atp_grid, int total_voxels,
    int scavenger_count, const float* d_scavenger_atp_curr, const float* d_scavenger_motors, const float* d_scavenger_desens_curr, const float* d_scavenger_lipid_curr,
    const uint32_t* d_genome,
    const float* d_prot_actb_curr, const float* d_prot_cd47_curr, const float* d_prot_sirpa_curr, const float* d_prot_p2ry2_curr, const float* d_prot_abca1_curr,
    double wddm_eviction_penalty, double wddm_budget_exceeded, double cuda_queue_depth,
    double interop_latency, double present_latency, double accumulator_debt, double thermal_throttling,
    double optical_fps, double vram_idle_time_ms,
    cudaStream_t stream)
{
    int threads = 256;

    Telemetry_Agent_Reduction_Kernel << < (agent_count + threads - 1) / threads, threads, 0, stream >> > (agent_count, d_agent_atp_curr, d_agent_desens_curr, d_agent_motors, g_active_device_accumulators);
    Telemetry_Tissue_Reduction_Kernel << < (tissue_count + threads - 1) / threads, threads, 0, stream >> > (tissue_count, d_integrity_curr, g_active_device_accumulators);
    Telemetry_SASP_ATP_Reduction_Kernel << < (total_voxels + threads - 1) / threads, threads, 0, stream >> > (total_voxels, d_sasp_grid, d_atp_grid, g_active_device_accumulators);
    Telemetry_Scavenger_Reduction_Kernel << < (scavenger_count + threads - 1) / threads, threads, 0, stream >> > (scavenger_count, d_scavenger_atp_curr, d_scavenger_desens_curr, d_scavenger_lipid_curr, d_scavenger_motors, g_active_device_accumulators);

    int total_ecosystem_agents = tissue_count + agent_count + scavenger_count;
    Genomic_Proteomic_Reduction_Kernel << < (total_ecosystem_agents + threads - 1) / threads, threads, 0, stream >> > (
        total_ecosystem_agents, d_genome, BiophysicalConstants::GENOMICS_WORDS_PER_AGENT,
        d_prot_actb_curr, d_prot_cd47_curr, d_prot_sirpa_curr, d_prot_p2ry2_curr, d_prot_abca1_curr, tick, g_active_device_accumulators
        );

    cudaEventRecord(compute_done_event, stream);

    cudaStreamWaitEvent(telemetry_dma_stream, compute_done_event, 0);

    BiophysicalAccumulators* active_h_ptr = is_buffer_A_active ? h_acc_A : h_acc_B;
    cudaMemcpyAsync(active_h_ptr, g_active_device_accumulators, sizeof(BiophysicalAccumulators), cudaMemcpyDeviceToHost, telemetry_dma_stream);

    cudaEvent_t active_copy_event = is_buffer_A_active ? telemetry_copy_event_A : telemetry_copy_event_B;
    cudaEventRecord(active_copy_event, telemetry_dma_stream);

    auto current_timestamp = std::chrono::high_resolution_clock::now();
    std::chrono::duration<float, std::milli> duration = current_timestamp - last_compute_timestamp;
    last_compute_timestamp = current_timestamp;

    double compute_lat_ms = static_cast<double>(duration.count());
    double is_stall = 0.5 + 0.5 * copysign(1.0, compute_lat_ms - 16.66);
    cumulative_sync_stalls += is_stall;

    TelemetryCPUContext* active_ctx = is_buffer_A_active ? &cpu_ctx_A : &cpu_ctx_B;
    active_ctx->tick = tick;
    active_ctx->vram_total = static_cast<double>(vram_total);
    active_ctx->vram_used = static_cast<double>(vram_used);
    active_ctx->compute_lat_ms = compute_lat_ms;
    active_ctx->cumulative_sync_stalls = cumulative_sync_stalls;

    // Phase 96: Registering exact hardware execution epoch
    active_ctx->hw_elapsed_ms = std::chrono::duration<double, std::milli>(current_timestamp - genesis_timestamp).count();

    active_ctx->wddm_eviction_penalty = wddm_eviction_penalty;
    active_ctx->wddm_budget_exceeded = wddm_budget_exceeded;
    active_ctx->cuda_queue_depth = cuda_queue_depth;
    active_ctx->interop_latency = interop_latency;
    active_ctx->present_latency = present_latency;
    active_ctx->accumulator_debt = accumulator_debt;
    active_ctx->thermal_throttling = thermal_throttling;

    active_ctx->optical_fps = optical_fps;
    active_ctx->vram_idle_time_ms = vram_idle_time_ms;

    cudaEvent_t inactive_copy_event = is_buffer_A_active ? telemetry_copy_event_B : telemetry_copy_event_A;
    BiophysicalAccumulators* inactive_h_ptr = is_buffer_A_active ? h_acc_B : h_acc_A;
    TelemetryCPUContext* inactive_ctx = is_buffer_A_active ? &cpu_ctx_B : &cpu_ctx_A;

    if (!is_first_telemetry_frame) {
        if (cudaEventQuery(inactive_copy_event) == cudaSuccess) {

            cumulative_state.trogoptosis_collapse_events += inactive_h_ptr->collapse_events;
            cumulative_state.ros_bombardment_strikes += inactive_h_ptr->total_ros_strikes;
            cumulative_state.parp_successful_repairs += inactive_h_ptr->total_parp_repairs;
            cumulative_state.parp_atp_depletion_tax += inactive_h_ptr->parp_atp_tax;
            cumulative_state.macropinocytosis_clearance_volume += inactive_h_ptr->macropinocytosis_volume;
            cumulative_state.trogocytosis_nibbling_volume += inactive_h_ptr->trogocytosis_volume;
            cumulative_state.fao_metabolic_yield += inactive_h_ptr->fao_atp_yield;
            cumulative_state.autophagy_yield += inactive_h_ptr->autophagy_yield;
            cumulative_state.agent_deaths_by_starvation += inactive_h_ptr->death_by_starvation;
            cumulative_state.agent_deaths_by_lipotoxicity += inactive_h_ptr->death_by_lipotoxicity;

            cumulative_state.cumulative_junk_dna_strikes += inactive_h_ptr->epoch_junk_dna_strikes;
            cumulative_state.cumulative_coding_dna_strikes += inactive_h_ptr->epoch_coding_dna_strikes;
            cumulative_state.cumulative_actb_strikes += inactive_h_ptr->epoch_actb_strikes;
            cumulative_state.cumulative_cd47_strikes += inactive_h_ptr->epoch_cd47_strikes;
            cumulative_state.cumulative_cd47_repressor_strikes += inactive_h_ptr->epoch_cd47_repressor_strikes;
            cumulative_state.cumulative_sirpa_strikes += inactive_h_ptr->epoch_sirpa_strikes;
            cumulative_state.cumulative_p2ry2_strikes += inactive_h_ptr->epoch_p2ry2_strikes;
            cumulative_state.cumulative_abca1_strikes += inactive_h_ptr->epoch_abca1_strikes;

            double epoch_ratio = (inactive_h_ptr->epoch_coding_dna_strikes > 0.0)
                ? (inactive_h_ptr->epoch_junk_dna_strikes / inactive_h_ptr->epoch_coding_dna_strikes)
                : inactive_h_ptr->epoch_junk_dna_strikes;

            double cumulative_ratio = (cumulative_state.cumulative_coding_dna_strikes > 0.0)
                ? (cumulative_state.cumulative_junk_dna_strikes / cumulative_state.cumulative_coding_dna_strikes)
                : cumulative_state.cumulative_junk_dna_strikes;

            double live_senescent = inactive_h_ptr->tissue_live_count;
            double live_senophage = inactive_h_ptr->agent_active_count;
            double live_scavenger = inactive_h_ptr->scavenger_live_count;
            double total_live_agents = live_senophage + live_scavenger;
            double active_genomic_pool = (live_senescent + live_senophage + live_scavenger) * 104120416.0;

            double avg_vel_mag = (total_live_agents > 0) ? (inactive_h_ptr->velocity_magnitude / total_live_agents) : 0.0;
            double avg_levy_mag = (total_live_agents > 0) ? (inactive_h_ptr->levy_walk_magnitude / total_live_agents) : 0.0;
            double avg_swarm_dens = (total_live_agents > 0) ? (inactive_h_ptr->swarm_cooperation_density / total_live_agents) : 0.0;
            double avg_cil_supp = (total_live_agents > 0) ? (inactive_h_ptr->cil_suppression_index / total_live_agents) : 0.0;
            double macro_trogo_ratio = (inactive_h_ptr->trogocytosis_volume > 0.0001) ? (inactive_h_ptr->macropinocytosis_volume / inactive_h_ptr->trogocytosis_volume) : inactive_h_ptr->macropinocytosis_volume;
            double avg_lipid_burden = (live_scavenger > 0) ? (inactive_h_ptr->scavenger_lipid_total / live_scavenger) : 0.0;
            double avg_combined_desens = (total_live_agents > 0) ? ((inactive_h_ptr->agent_desens_total + inactive_h_ptr->scavenger_desens_total) / total_live_agents) : 0.0;
            double avg_senophage_neural = (live_senophage > 0) ? (inactive_h_ptr->senophage_neural_total / live_senophage) : 0.0;
            double avg_senophage_fatigue = (live_senophage > 0) ? (inactive_h_ptr->agent_desens_total / live_senophage) : 0.0;
            double avg_scavenger_neural = (live_scavenger > 0) ? (inactive_h_ptr->scavenger_neural_total / live_scavenger) : 0.0;
            double avg_scavenger_fatigue = (live_scavenger > 0) ? (inactive_h_ptr->scavenger_desens_total / live_scavenger) : 0.0;

            double total_sasp = inactive_h_ptr->sasp_total;
            double mean_ph_index = (total_voxels > 0) ? ((total_sasp * 0.6 + live_senescent * 0.4) / static_cast<double>(total_voxels)) : 0.0;
            double total_cd47_expression = inactive_h_ptr->cd47_expression_total;
            double mean_cancer_hypertrophy = (total_ecosystem_agents > 0) ? (total_cd47_expression / static_cast<double>(total_ecosystem_agents)) : 0.0;
            double total_mutations = inactive_h_ptr->mutated_base_pairs_total;
            double mean_nuclear_fluorescence = (total_ecosystem_agents > 0) ? (total_mutations / static_cast<double>(total_ecosystem_agents)) * 0.15 : 0.0;

            double cache_hit_proxy = 98.5 - (avg_levy_mag * 12.0) + (avg_swarm_dens * 0.5);
            cache_hit_proxy = fmin(99.9, fmax(40.0, cache_hit_proxy));

            TelemetryRecordPayload payload;
            payload.tick = inactive_ctx->tick;

            // Phase 96: Handing over the persistent timing anchor to the Spooler Thread
            payload.hardware_elapsed_ms = inactive_ctx->hw_elapsed_ms;

            payload.static_total_base_pairs = BiophysicalConstants::GENOMICS_TOTAL_BASE_PAIRS;
            payload.static_agent_base_pairs = BiophysicalConstants::GENOMICS_WORDS_PER_AGENT * 16.0;
            payload.static_env_voxels = BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS;
            payload.static_total_agents = BiophysicalConstants::TOTAL_ECOSYSTEM_AGENTS_INITIALIZED;
            payload.vram_total = inactive_ctx->vram_total;
            payload.vram_used = inactive_ctx->vram_used;
            payload.live_senescent = live_senescent;
            payload.live_senophage = live_senophage;
            payload.live_scavenger = live_scavenger;
            payload.active_genomic_pool = active_genomic_pool;
            payload.active_oncogenic = inactive_h_ptr->oncogenic_cell_count;
            payload.max_cd47_overexpression = inactive_h_ptr->prot_cd47_max;

            payload.trogoptosis_collapse_events = inactive_h_ptr->collapse_events;
            payload.cumulative_trogoptosis_collapse_events = cumulative_state.trogoptosis_collapse_events;

            payload.total_ros_strikes = inactive_h_ptr->total_ros_strikes;
            payload.cumulative_ros_bombardment_strikes = cumulative_state.ros_bombardment_strikes;

            payload.epoch_junk_dna_strikes = inactive_h_ptr->epoch_junk_dna_strikes;
            payload.cumulative_junk_dna_strikes = cumulative_state.cumulative_junk_dna_strikes;

            payload.epoch_coding_dna_strikes = inactive_h_ptr->epoch_coding_dna_strikes;
            payload.cumulative_coding_dna_strikes = cumulative_state.cumulative_coding_dna_strikes;

            payload.epoch_actb_strikes = inactive_h_ptr->epoch_actb_strikes;
            payload.cumulative_actb_strikes = cumulative_state.cumulative_actb_strikes;

            payload.epoch_cd47_strikes = inactive_h_ptr->epoch_cd47_strikes;
            payload.cumulative_cd47_strikes = cumulative_state.cumulative_cd47_strikes;

            payload.epoch_cd47_repressor_strikes = inactive_h_ptr->epoch_cd47_repressor_strikes;
            payload.cumulative_cd47_repressor_strikes = cumulative_state.cumulative_cd47_repressor_strikes;

            payload.epoch_sirpa_strikes = inactive_h_ptr->epoch_sirpa_strikes;
            payload.cumulative_sirpa_strikes = cumulative_state.cumulative_sirpa_strikes;

            payload.epoch_p2ry2_strikes = inactive_h_ptr->epoch_p2ry2_strikes;
            payload.cumulative_p2ry2_strikes = cumulative_state.cumulative_p2ry2_strikes;

            payload.epoch_abca1_strikes = inactive_h_ptr->epoch_abca1_strikes;
            payload.cumulative_abca1_strikes = cumulative_state.cumulative_abca1_strikes;

            payload.epoch_junk_vs_coding_ratio = epoch_ratio;
            payload.cumulative_junk_vs_coding_ratio = cumulative_ratio;

            payload.active_mutated_base_pairs = inactive_h_ptr->mutated_base_pairs_total;

            payload.total_parp_repairs = inactive_h_ptr->total_parp_repairs;
            payload.cumulative_parp_successful_repairs = cumulative_state.parp_successful_repairs;

            payload.parp_atp_tax = inactive_h_ptr->parp_atp_tax;
            payload.cumulative_parp_atp_depletion_tax = cumulative_state.parp_atp_depletion_tax;

            payload.mean_macrophage_velocity = avg_vel_mag;
            payload.mean_levy_walk = avg_levy_mag;
            payload.swarm_cooperation_density = avg_swarm_dens;
            payload.cil_suppression_index = avg_cil_supp;

            payload.macropinocytosis_volume = inactive_h_ptr->macropinocytosis_volume;
            payload.cumulative_macropinocytosis_clearance_volume = cumulative_state.macropinocytosis_clearance_volume;

            payload.trogocytosis_volume = inactive_h_ptr->trogocytosis_volume;
            payload.cumulative_trogocytosis_nibbling_volume = cumulative_state.trogocytosis_nibbling_volume;

            payload.macro_trogo_ratio = macro_trogo_ratio;
            payload.global_atp_pool = inactive_h_ptr->agent_atp_total;

            payload.total_fao_yield = inactive_h_ptr->fao_atp_yield;
            payload.cumulative_fao_metabolic_yield = cumulative_state.fao_metabolic_yield;

            payload.total_autophagy_yield = inactive_h_ptr->autophagy_yield;
            payload.cumulative_autophagy_yield = cumulative_state.autophagy_yield;

            payload.mean_lipid_burden = avg_lipid_burden;

            payload.death_starvation = inactive_h_ptr->death_by_starvation;
            payload.cumulative_agent_deaths_by_starvation = cumulative_state.agent_deaths_by_starvation;

            payload.death_lipotoxicity = inactive_h_ptr->death_by_lipotoxicity;
            payload.cumulative_agent_deaths_by_lipotoxicity = cumulative_state.agent_deaths_by_lipotoxicity;

            payload.receptor_desensitization = avg_combined_desens;
            payload.global_sasp = inactive_h_ptr->sasp_total;
            payload.global_extracellular_atp = inactive_h_ptr->extracellular_atp_total;
            payload.mean_actb = inactive_h_ptr->prot_actb_total / static_cast<double>(total_ecosystem_agents);
            payload.mean_abca1 = inactive_h_ptr->prot_abca1_total / static_cast<double>(total_ecosystem_agents);
            payload.mean_sirpa = (inactive_h_ptr->prot_receptors_total * 0.5) / static_cast<double>(total_ecosystem_agents);
            payload.mean_p2ry2 = payload.mean_sirpa;
            payload.mean_senophage_neural = avg_senophage_neural;
            payload.mean_senophage_fatigue = avg_senophage_fatigue;
            payload.mean_scavenger_neural = avg_scavenger_neural;
            payload.mean_scavenger_fatigue = avg_scavenger_fatigue;
            payload.mean_ph_index = mean_ph_index;
            payload.mean_cancer_hypertrophy = mean_cancer_hypertrophy;
            payload.mean_nuclear_fluorescence = mean_nuclear_fluorescence;
            payload.biological_compute_latency = inactive_ctx->compute_lat_ms;
            payload.optical_render_latency = 16.66;
            payload.vram_cache_hit_rate = cache_hit_proxy;
            payload.lbm_max_velocity = inactive_h_ptr->lbm_max_velocity;
            payload.sync_stall_count = inactive_ctx->cumulative_sync_stalls;

            payload.wddm_os_vram_eviction_penalty_bytes = inactive_ctx->wddm_eviction_penalty;
            payload.wddm_vram_budget_exceeded_flag = inactive_ctx->wddm_budget_exceeded;
            payload.cuda_hardware_command_queue_depth = inactive_ctx->cuda_queue_depth;
            payload.api_interop_map_lock_latency_ms = inactive_ctx->interop_latency;
            payload.dxgi_present_blocking_latency_ms = inactive_ctx->present_latency;
            payload.thermodynamic_accumulator_debt_ms = inactive_ctx->accumulator_debt;
            payload.gpu_thermal_throttling_state = inactive_ctx->thermal_throttling;

            payload.optical_fps = inactive_ctx->optical_fps;
            payload.vram_idle_time_ms = inactive_ctx->vram_idle_time_ms;

            async_spooler->SpoolData(payload);
        }
    }

    is_buffer_A_active = !is_buffer_A_active;
    g_active_device_accumulators = is_buffer_A_active ? d_acc_A : d_acc_B;
    is_first_telemetry_frame = false;
}
// --- END OF FILE Biophysical.Telemetry.Spooler.cu ---