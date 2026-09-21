#include "Genomic.Repair.PARP.cuh"
#include "Biochemical.Constants.h"
#include "Autonomous.Senolytic.Population.cuh" // For BiophysicalAccumulators structure

__device__ inline uint64_t PARP_Scanning_Hash(uint64_t input) {
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

__global__ void Tissue_PARP_Restoration_Kernel(
    uint32_t* d_global_genome,
    size_t words_per_agent,
    int base_global_offset,
    int population_size,
    const float* integrity_current,
    float* integrity_next,
    unsigned long long sys_tick,
    BiophysicalAccumulators* acc)
{
    int agent_idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (agent_idx >= population_size) return;

    float current_integrity = integrity_current[agent_idx];

    float repair_capacity = (BiophysicalConstants::PARP_VMAX_REPAIR * current_integrity) / (BiophysicalConstants::PARP_KM_INTEGRITY + current_integrity);
    int repair_rays = __float2int_ru(repair_capacity);

    double total_metabolic_tax = 0.0;
    double local_successful_repairs = 0.0;

    size_t base_memory_address = static_cast<size_t>(base_global_offset + agent_idx) * words_per_agent;

    size_t offsets[6] = { BiophysicalConstants::LOCUS_OFFSET_ACTB, BiophysicalConstants::LOCUS_OFFSET_CD47, BiophysicalConstants::LOCUS_OFFSET_SIRPA, BiophysicalConstants::LOCUS_OFFSET_P2RY2, BiophysicalConstants::LOCUS_OFFSET_ABCA1, BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR };
    size_t lengths[6] = { BiophysicalConstants::LOCUS_LENGTH_ACTB, BiophysicalConstants::LOCUS_LENGTH_CD47, BiophysicalConstants::LOCUS_LENGTH_SIRPA, BiophysicalConstants::LOCUS_LENGTH_P2RY2, BiophysicalConstants::LOCUS_LENGTH_ABCA1, BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR };

    for (int i = 0; i < repair_rays; ++i) {
        uint64_t seed = PARP_Scanning_Hash(sys_tick ^ static_cast<uint64_t>(agent_idx) ^ static_cast<uint64_t>(i));
        uint32_t locus_idx = seed % 6;

        size_t l_offset = offsets[locus_idx];
        size_t l_length = lengths[locus_idx];

        size_t target_word = base_memory_address + l_offset + (PARP_Scanning_Hash(seed + 1) % l_length);

        uint32_t read_word = d_global_genome[target_word];
        uint32_t wild_type_anchor = 0xAAAAAAAA;

        uint32_t mismatch = read_word ^ wild_type_anchor;

        uint32_t repair_mask = mismatch & (~mismatch + 1U);

        atomicXor(&d_global_genome[target_word], repair_mask);

        double is_repaired = (repair_mask > 0) ? 1.0 : 0.0;
        local_successful_repairs += is_repaired;
        total_metabolic_tax += (is_repaired * static_cast<double>(BiophysicalConstants::PARP_REPAIR_ATP_COST)) + ((1.0 - is_repaired) * static_cast<double>(BiophysicalConstants::PARP_SCANNING_ATP_COST));
    }

    atomicAdd(&(acc->parp_atp_tax), total_metabolic_tax);
    atomicAdd(&(acc->total_parp_repairs), local_successful_repairs);

    // Phase 85: Thermodynamic Delta is appended directly to T+1 State avoiding RAW hazards
    atomicAdd(&integrity_next[agent_idx], -static_cast<float>(total_metabolic_tax) * 0.001f);
}

__global__ void Agent_PARP_Restoration_Kernel(
    uint32_t* d_global_genome,
    size_t words_per_agent,
    int base_global_offset,
    int population_size,
    const float* atp_current,
    float* atp_next,
    unsigned long long sys_tick,
    BiophysicalAccumulators* acc)
{
    int agent_idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (agent_idx >= population_size) return;

    float current_atp = atp_current[agent_idx];

    float repair_capacity = (BiophysicalConstants::PARP_VMAX_REPAIR * current_atp) / (BiophysicalConstants::PARP_KM_ATP + current_atp);
    int repair_rays = __float2int_ru(repair_capacity);

    double total_atp_cost = 0.0;
    double local_successful_repairs = 0.0;

    size_t base_memory_address = static_cast<size_t>(base_global_offset + agent_idx) * words_per_agent;

    size_t offsets[6] = { BiophysicalConstants::LOCUS_OFFSET_ACTB, BiophysicalConstants::LOCUS_OFFSET_CD47, BiophysicalConstants::LOCUS_OFFSET_SIRPA, BiophysicalConstants::LOCUS_OFFSET_P2RY2, BiophysicalConstants::LOCUS_OFFSET_ABCA1, BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR };
    size_t lengths[6] = { BiophysicalConstants::LOCUS_LENGTH_ACTB, BiophysicalConstants::LOCUS_LENGTH_CD47, BiophysicalConstants::LOCUS_LENGTH_SIRPA, BiophysicalConstants::LOCUS_LENGTH_P2RY2, BiophysicalConstants::LOCUS_LENGTH_ABCA1, BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR };

    for (int i = 0; i < repair_rays; ++i) {
        uint64_t seed = PARP_Scanning_Hash(sys_tick ^ static_cast<uint64_t>(agent_idx) ^ static_cast<uint64_t>(i));
        uint32_t locus_idx = seed % 6;

        size_t l_offset = offsets[locus_idx];
        size_t l_length = lengths[locus_idx];

        size_t target_word = base_memory_address + l_offset + (PARP_Scanning_Hash(seed + 1) % l_length);

        uint32_t read_word = d_global_genome[target_word];
        uint32_t wild_type_anchor = 0xAAAAAAAA;

        uint32_t mismatch = read_word ^ wild_type_anchor;
        uint32_t repair_mask = mismatch & (~mismatch + 1U);

        atomicXor(&d_global_genome[target_word], repair_mask);

        double is_repaired = (repair_mask > 0) ? 1.0 : 0.0;
        local_successful_repairs += is_repaired;

        total_atp_cost += (is_repaired * static_cast<double>(BiophysicalConstants::PARP_REPAIR_ATP_COST)) + ((1.0 - is_repaired) * static_cast<double>(BiophysicalConstants::PARP_SCANNING_ATP_COST));
    }

    atomicAdd(&(acc->parp_atp_tax), total_atp_cost);
    atomicAdd(&(acc->total_parp_repairs), local_successful_repairs);

    // Phase 85: Thermodynamic Delta is appended directly to T+1 State avoiding RAW hazards
    atomicAdd(&atp_next[agent_idx], -static_cast<float>(total_atp_cost));
}

ThermodynamicPARPRepairEngine::ThermodynamicPARPRepairEngine(MacromolecularGenomicEnvironment* genome_env)
    : d_genome_environment(genome_env)
{
}

ThermodynamicPARPRepairEngine::~ThermodynamicPARPRepairEngine() {
}

void ThermodynamicPARPRepairEngine::ExecuteTissueRepair(int pop_size, int global_offset, const float* integrity_current, float* integrity_next, unsigned long long sys_tick, cudaStream_t stream) {
    int threads = 256;
    int blocks = (pop_size + threads - 1) / threads;

    Tissue_PARP_Restoration_Kernel << <blocks, threads, 0, stream >> > (
        d_genome_environment->d_global_genome_sequence,
        BiophysicalConstants::GENOMICS_WORDS_PER_AGENT,
        global_offset,
        pop_size,
        integrity_current,
        integrity_next,
        sys_tick,
        g_active_device_accumulators
        );
}

void ThermodynamicPARPRepairEngine::ExecuteAgentRepair(int pop_size, int global_offset, const float* atp_current, float* atp_next, unsigned long long sys_tick, cudaStream_t stream) {
    int threads = 256;
    int blocks = (pop_size + threads - 1) / threads;

    Agent_PARP_Restoration_Kernel << <blocks, threads, 0, stream >> > (
        d_genome_environment->d_global_genome_sequence,
        BiophysicalConstants::GENOMICS_WORDS_PER_AGENT,
        global_offset,
        pop_size,
        atp_current,
        atp_next,
        sys_tick,
        g_active_device_accumulators
        );
}