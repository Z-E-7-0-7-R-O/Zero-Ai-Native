// --- START OF FILE Central.Dogma.Transcription.cu ---

#include "Central.Dogma.Transcription.cuh"
#include "Biochemical.Constants.h"
#include <iostream>

__device__ float Calculate_Thermodynamic_Protein_Fitness(
    uint32_t* d_global_genome,
    size_t base_address,
    size_t locus_offset,
    size_t locus_length_words,
    float sensitivity_scalar,
    float scan_mask)
{
    size_t total_bit_mismatches = 0;
    uint32_t wild_type_anchor = 0xAAAAAAAA;

    size_t effective_length = locus_length_words * static_cast<size_t>(scan_mask);

    for (size_t i = 0; i < effective_length; ++i) {
        uint32_t read_sequence = d_global_genome[base_address + locus_offset + i];
        total_bit_mismatches += __popc(read_sequence ^ wild_type_anchor);
    }

    float max_possible_mismatches = static_cast<float>(locus_length_words * 32ULL);
    float mutational_burden = static_cast<float>(total_bit_mismatches) / max_possible_mismatches;

    return expf(-sensitivity_scalar * mutational_burden);
}

// Phase 92: Continuous Translation Dynamics via Exponential Moving Average (EMA)
// Absolute eradication of the modulo-based scan_mask that caused 99% translation failure (ACTB paralysis).
// Transcription now models realistic Translation Elongation Rates and Proteasomal Degradation.
__global__ void Genomic_Translation_Kernel(
    uint32_t* d_genome,
    size_t words_per_agent,
    int total_agents,
    float sensitivity,
    unsigned long long sys_tick,
    unsigned long long epoch_duration,
    const float* epi_actb, const float* epi_cd47, const float* epi_sirpa, const float* epi_p2ry2, const float* epi_abca1,
    const float* prot_actb_curr, const float* prot_cd47_curr, const float* prot_sirpa_curr, const float* prot_p2ry2_curr, const float* prot_abca1_curr,
    float* prot_actb_next, float* prot_cd47_next, float* prot_sirpa_next, float* prot_p2ry2_next, float* prot_abca1_next)
{
    int agent_id = blockIdx.x * blockDim.x + threadIdx.x;
    if (agent_id >= total_agents) return;

    size_t base_address = static_cast<size_t>(agent_id) * words_per_agent;

    // Phase 92: Biologically accurate synthesis vs degradation kinetics
    float translation_elongation_rate = 0.05f;
    float proteasomal_degradation_rate = 1.0f - translation_elongation_rate;

    // ACTB Processing
    float actb_fitness = Calculate_Thermodynamic_Protein_Fitness(d_genome, base_address, BiophysicalConstants::LOCUS_OFFSET_ACTB, BiophysicalConstants::LOCUS_LENGTH_ACTB, sensitivity, 1.0f);
    prot_actb_next[agent_id] = (prot_actb_curr[agent_id] * proteasomal_degradation_rate) + (actb_fitness * epi_actb[agent_id] * translation_elongation_rate);

    // CD47 Processing with Repressor logic
    float cd47_base_fitness = Calculate_Thermodynamic_Protein_Fitness(d_genome, base_address, BiophysicalConstants::LOCUS_OFFSET_CD47, BiophysicalConstants::LOCUS_LENGTH_CD47, sensitivity, 1.0f);
    float cd47_repressor_fitness = Calculate_Thermodynamic_Protein_Fitness(d_genome, base_address, BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR, BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR, sensitivity, 1.0f);

    float max_overexpression = BiophysicalConstants::MAX_ONCOGENIC_OVEREXPRESSION;
    float amplified_cd47_fitness = cd47_base_fitness * (max_overexpression / (1.0f + (max_overexpression - 1.0f) * cd47_repressor_fitness));
    prot_cd47_next[agent_id] = (prot_cd47_curr[agent_id] * proteasomal_degradation_rate) + (amplified_cd47_fitness * epi_cd47[agent_id] * translation_elongation_rate);

    // SIRPA Processing
    float sirpa_fitness = Calculate_Thermodynamic_Protein_Fitness(d_genome, base_address, BiophysicalConstants::LOCUS_OFFSET_SIRPA, BiophysicalConstants::LOCUS_LENGTH_SIRPA, sensitivity, 1.0f);
    prot_sirpa_next[agent_id] = (prot_sirpa_curr[agent_id] * proteasomal_degradation_rate) + (sirpa_fitness * epi_sirpa[agent_id] * translation_elongation_rate);

    // P2RY2 Processing
    float p2ry2_fitness = Calculate_Thermodynamic_Protein_Fitness(d_genome, base_address, BiophysicalConstants::LOCUS_OFFSET_P2RY2, BiophysicalConstants::LOCUS_LENGTH_P2RY2, sensitivity, 1.0f);
    prot_p2ry2_next[agent_id] = (prot_p2ry2_curr[agent_id] * proteasomal_degradation_rate) + (p2ry2_fitness * epi_p2ry2[agent_id] * translation_elongation_rate);

    // ABCA1 Processing
    float abca1_fitness = Calculate_Thermodynamic_Protein_Fitness(d_genome, base_address, BiophysicalConstants::LOCUS_OFFSET_ABCA1, BiophysicalConstants::LOCUS_LENGTH_ABCA1, sensitivity, 1.0f);
    prot_abca1_next[agent_id] = (prot_abca1_curr[agent_id] * proteasomal_degradation_rate) + (abca1_fitness * epi_abca1[agent_id] * translation_elongation_rate);
}

CentralDogmaEngine::CentralDogmaEngine(MacromolecularGenomicEnvironment* genome_env,
    EpigeneticPromoterRegistry* epigenetic_reg,
    ProteomicExpressionState* proteomic_state)
    : d_genome_environment(genome_env), d_epigenetic_registry(epigenetic_reg), d_proteomic_state(proteomic_state)
{
}

CentralDogmaEngine::~CentralDogmaEngine() {
}

void CentralDogmaEngine::ExecuteTranscription(unsigned long long current_tick, int total_agents, cudaStream_t stream) {
    int threads = 256;
    int blocks = (total_agents + threads - 1) / threads;

    Genomic_Translation_Kernel << <blocks, threads, 0, stream >> > (
        d_genome_environment->d_global_genome_sequence,
        BiophysicalConstants::GENOMICS_WORDS_PER_AGENT,
        total_agents,
        BiophysicalConstants::MUTATION_SENSITIVITY_SCALAR,
        current_tick,
        BiophysicalConstants::CENTRAL_DOGMA_EPOCH,
        d_epigenetic_registry->d_epigenetic_weight_ACTB,
        d_epigenetic_registry->d_epigenetic_weight_CD47,
        d_epigenetic_registry->d_epigenetic_weight_SIRPA,
        d_epigenetic_registry->d_epigenetic_weight_P2RY2,
        d_epigenetic_registry->d_epigenetic_weight_ABCA1,
        d_proteomic_state->d_protein_level_ACTB_current,
        d_proteomic_state->d_protein_level_CD47_current,
        d_proteomic_state->d_protein_level_SIRPA_current,
        d_proteomic_state->d_protein_level_P2RY2_current,
        d_proteomic_state->d_protein_level_ABCA1_current,
        d_proteomic_state->d_protein_level_ACTB_next,
        d_proteomic_state->d_protein_level_CD47_next,
        d_proteomic_state->d_protein_level_SIRPA_next,
        d_proteomic_state->d_protein_level_P2RY2_next,
        d_proteomic_state->d_protein_level_ABCA1_next
        );
}
// --- END OF FILE Central.Dogma.Transcription.cu ---