// --- START OF FILE Stochastic.Mutagenesis.Kinematics.cu ---

#include "Stochastic.Mutagenesis.Kinematics.cuh"
#include "Biochemical.Constants.h"
#include "Autonomous.Senolytic.Population.cuh" 
#include <iostream>

__device__ inline uint64_t Stochastic_Ray_Hash(uint64_t input) {
    uint64_t state = input * 6364136223846793005ULL + 1442695040888963407ULL;
    uint32_t xorshifted = ((state >> 18u) ^ state) >> 27u;
    uint32_t rot = state >> 59u;
    uint32_t high = (xorshifted >> rot) | (xorshifted << ((-rot) & 31));

    state = state * 6364136223846793005ULL + 1442695040888963407ULL;
    xorshifted = ((state >> 18u) ^ state) >> 27u;
    rot = state >> 59u;
    uint32_t low = (xorshifted >> rot) | (xorshifted << ((-rot) & 31));

    return (static_cast<uint64_t>(high) << 32) | static_cast<uint64_t>(low);
}

// Phase 95: Continuous Locus Hit Detection without Linear Branches
// Mathematically computes if a target offset falls within [locus_offset, locus_offset + locus_length - 1]
__device__ inline float Detect_Locus_Hit(float target_offset, float locus_offset, float locus_length) {
    float d1 = target_offset - locus_offset;
    float d2 = (locus_offset + locus_length - 1.0f) - target_offset;
    // Returns 1.0f if target is inside the locus bounds, else 0.0f
    return (0.5f + 0.5f * copysignf(1.0f, d1)) * (0.5f + 0.5f * copysignf(1.0f, d2));
}

__global__ void Tissue_Genotoxicity_Kernel(
    uint32_t* d_global_genome,
    size_t words_per_agent,
    int base_global_offset,
    int population_size,
    const float* p_x_curr, const float* p_y_curr, const float* integrity_curr,
    const float* sasp_grid, int width, int height,
    unsigned long long sys_tick,
    BiophysicalAccumulators* acc)
{
    int agent_idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (agent_idx >= population_size) return;

    int grid_x = (static_cast<int>(floorf(p_x_curr[agent_idx])) % width + width) % width;
    int grid_y = (static_cast<int>(floorf(p_y_curr[agent_idx])) % height + height) % height;

    float local_sasp = sasp_grid[grid_y * width + grid_x];
    float local_integrity = integrity_curr[agent_idx];
    float damage_proxy = fmaxf(0.0f, 1.0f - local_integrity);

    float sasp_ros = (BiophysicalConstants::ROS_VMAX_SASP * local_sasp) / (BiophysicalConstants::ROS_KM_SASP + local_sasp);
    float structural_ros = (BiophysicalConstants::ROS_VMAX_STRUCTURAL * damage_proxy) / (BiophysicalConstants::ROS_KM_STRUCTURAL + damage_proxy);

    float total_ros_burden = sasp_ros + structural_ros;

    int mutation_count = __float2int_ru(total_ros_burden);
    size_t base_memory_address = static_cast<size_t>(base_global_offset + agent_idx) * words_per_agent;

    atomicAdd(&(acc->total_ros_strikes), static_cast<double>(mutation_count));

    // Local registers to prevent VRAM atomic congestion during high-volume loops
    double local_hit_actb = 0.0;
    double local_hit_cd47 = 0.0;
    double local_hit_cd47r = 0.0;
    double local_hit_sirpa = 0.0;
    double local_hit_p2ry2 = 0.0;
    double local_hit_abca1 = 0.0;
    double local_hit_coding = 0.0;
    double local_hit_junk = 0.0;

    for (int i = 0; i < mutation_count; ++i) {
        uint64_t seed = Stochastic_Ray_Hash(sys_tick ^ static_cast<uint64_t>(agent_idx) ^ static_cast<uint64_t>(i * 73821));
        size_t target_word_offset = seed % words_per_agent;

        // Phase 95: Continuous Locus Tracking
        float f_target = static_cast<float>(target_word_offset);

        float hit_actb = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_ACTB), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_ACTB));
        float hit_cd47 = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_CD47), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_CD47));
        float hit_cd47r = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR));
        float hit_sirpa = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_SIRPA), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_SIRPA));
        float hit_p2ry2 = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_P2RY2), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_P2RY2));
        float hit_abca1 = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_ABCA1), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_ABCA1));

        float hit_coding = hit_actb + hit_cd47 + hit_cd47r + hit_sirpa + hit_p2ry2 + hit_abca1;
        float hit_junk = 1.0f - hit_coding;

        local_hit_actb += static_cast<double>(hit_actb);
        local_hit_cd47 += static_cast<double>(hit_cd47);
        local_hit_cd47r += static_cast<double>(hit_cd47r);
        local_hit_sirpa += static_cast<double>(hit_sirpa);
        local_hit_p2ry2 += static_cast<double>(hit_p2ry2);
        local_hit_abca1 += static_cast<double>(hit_abca1);
        local_hit_coding += static_cast<double>(hit_coding);
        local_hit_junk += static_cast<double>(hit_junk);

        size_t target_word = base_memory_address + target_word_offset;
        uint32_t bitmask = 1U << (Stochastic_Ray_Hash(seed + 1) % 32);
        atomicXor(&d_global_genome[target_word], bitmask);
    }

    // Committing the dissected strikes to global tracking atomically
    if (mutation_count > 0) {
        atomicAdd(&(acc->epoch_junk_dna_strikes), local_hit_junk);
        atomicAdd(&(acc->epoch_coding_dna_strikes), local_hit_coding);
        atomicAdd(&(acc->epoch_actb_strikes), local_hit_actb);
        atomicAdd(&(acc->epoch_cd47_strikes), local_hit_cd47);
        atomicAdd(&(acc->epoch_cd47_repressor_strikes), local_hit_cd47r);
        atomicAdd(&(acc->epoch_sirpa_strikes), local_hit_sirpa);
        atomicAdd(&(acc->epoch_p2ry2_strikes), local_hit_p2ry2);
        atomicAdd(&(acc->epoch_abca1_strikes), local_hit_abca1);
    }
}

__global__ void Agent_Genotoxicity_Kernel(
    uint32_t* d_global_genome,
    size_t words_per_agent,
    int base_global_offset,
    int population_size,
    const float* p_x_curr, const float* p_y_curr, const float* atp_curr, const float* lipid_curr,
    const float* sasp_grid, int width, int height,
    unsigned long long sys_tick,
    BiophysicalAccumulators* acc)
{
    int agent_idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (agent_idx >= population_size) return;

    int grid_x = (static_cast<int>(floorf(p_x_curr[agent_idx])) % width + width) % width;
    int grid_y = (static_cast<int>(floorf(p_y_curr[agent_idx])) % height + height) % height;

    float local_sasp = sasp_grid[grid_y * width + grid_x];
    float current_atp = atp_curr[agent_idx];
    float current_lipid = lipid_curr[agent_idx];

    float starvation_proxy = 100.0f / (current_atp + 1.0f);

    float sasp_ros = (BiophysicalConstants::ROS_VMAX_SASP * local_sasp) / (BiophysicalConstants::ROS_KM_SASP + local_sasp);
    float starvation_ros = (BiophysicalConstants::ROS_VMAX_METABOLIC * starvation_proxy) / (BiophysicalConstants::ROS_KM_METABOLIC + starvation_proxy);
    float lipotoxicity_ros = (BiophysicalConstants::ROS_VMAX_LIPOTOXICITY * current_lipid) / (BiophysicalConstants::ROS_KM_LIPOTOXICITY + current_lipid);

    float total_ros_burden = sasp_ros + starvation_ros + lipotoxicity_ros;

    int mutation_count = __float2int_ru(total_ros_burden);
    size_t base_memory_address = static_cast<size_t>(base_global_offset + agent_idx) * words_per_agent;

    atomicAdd(&(acc->total_ros_strikes), static_cast<double>(mutation_count));

    double local_hit_actb = 0.0;
    double local_hit_cd47 = 0.0;
    double local_hit_cd47r = 0.0;
    double local_hit_sirpa = 0.0;
    double local_hit_p2ry2 = 0.0;
    double local_hit_abca1 = 0.0;
    double local_hit_coding = 0.0;
    double local_hit_junk = 0.0;

    for (int i = 0; i < mutation_count; ++i) {
        uint64_t seed = Stochastic_Ray_Hash(sys_tick ^ static_cast<uint64_t>(agent_idx) ^ static_cast<uint64_t>(i * 91827));
        size_t target_word_offset = seed % words_per_agent;

        // Phase 95: Continuous Locus Tracking
        float f_target = static_cast<float>(target_word_offset);

        float hit_actb = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_ACTB), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_ACTB));
        float hit_cd47 = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_CD47), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_CD47));
        float hit_cd47r = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR));
        float hit_sirpa = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_SIRPA), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_SIRPA));
        float hit_p2ry2 = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_P2RY2), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_P2RY2));
        float hit_abca1 = Detect_Locus_Hit(f_target, static_cast<float>(BiophysicalConstants::LOCUS_OFFSET_ABCA1), static_cast<float>(BiophysicalConstants::LOCUS_LENGTH_ABCA1));

        float hit_coding = hit_actb + hit_cd47 + hit_cd47r + hit_sirpa + hit_p2ry2 + hit_abca1;
        float hit_junk = 1.0f - hit_coding;

        local_hit_actb += static_cast<double>(hit_actb);
        local_hit_cd47 += static_cast<double>(hit_cd47);
        local_hit_cd47r += static_cast<double>(hit_cd47r);
        local_hit_sirpa += static_cast<double>(hit_sirpa);
        local_hit_p2ry2 += static_cast<double>(hit_p2ry2);
        local_hit_abca1 += static_cast<double>(hit_abca1);
        local_hit_coding += static_cast<double>(hit_coding);
        local_hit_junk += static_cast<double>(hit_junk);

        size_t target_word = base_memory_address + target_word_offset;
        uint32_t bitmask = 1U << (Stochastic_Ray_Hash(seed + 1) % 32);
        atomicXor(&d_global_genome[target_word], bitmask);
    }

    if (mutation_count > 0) {
        atomicAdd(&(acc->epoch_junk_dna_strikes), local_hit_junk);
        atomicAdd(&(acc->epoch_coding_dna_strikes), local_hit_coding);
        atomicAdd(&(acc->epoch_actb_strikes), local_hit_actb);
        atomicAdd(&(acc->epoch_cd47_strikes), local_hit_cd47);
        atomicAdd(&(acc->epoch_cd47_repressor_strikes), local_hit_cd47r);
        atomicAdd(&(acc->epoch_sirpa_strikes), local_hit_sirpa);
        atomicAdd(&(acc->epoch_p2ry2_strikes), local_hit_p2ry2);
        atomicAdd(&(acc->epoch_abca1_strikes), local_hit_abca1);
    }
}

ThermodynamicMutagenesisEngine::ThermodynamicMutagenesisEngine(MacromolecularGenomicEnvironment* genome_env)
    : d_genome_environment(genome_env)
{
}

ThermodynamicMutagenesisEngine::~ThermodynamicMutagenesisEngine() {
}

void ThermodynamicMutagenesisEngine::InduceTissueGenotoxicity(int pop_size, int global_offset, const float* p_x_curr, const float* p_y_curr, const float* integrity_curr, const float* d_sasp_grid, unsigned long long sys_tick, cudaStream_t stream) {
    int threads = 256;
    int blocks = (pop_size + threads - 1) / threads;

    Tissue_Genotoxicity_Kernel << <blocks, threads, 0, stream >> > (
        d_genome_environment->d_global_genome_sequence,
        BiophysicalConstants::GENOMICS_WORDS_PER_AGENT,
        global_offset,
        pop_size,
        p_x_curr, p_y_curr, integrity_curr,
        d_sasp_grid, BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        sys_tick,
        g_active_device_accumulators
        );
}

void ThermodynamicMutagenesisEngine::InduceAgentGenotoxicity(int pop_size, int global_offset, const float* p_x_curr, const float* p_y_curr, const float* atp_curr, const float* lipid_curr, const float* d_sasp_grid, unsigned long long sys_tick, cudaStream_t stream) {
    int threads = 256;
    int blocks = (pop_size + threads - 1) / threads;

    Agent_Genotoxicity_Kernel << <blocks, threads, 0, stream >> > (
        d_genome_environment->d_global_genome_sequence,
        BiophysicalConstants::GENOMICS_WORDS_PER_AGENT,
        global_offset,
        pop_size,
        p_x_curr, p_y_curr, atp_curr, lipid_curr,
        d_sasp_grid, BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        sys_tick,
        g_active_device_accumulators
        );
}
// --- END OF FILE Stochastic.Mutagenesis.Kinematics.cu ---