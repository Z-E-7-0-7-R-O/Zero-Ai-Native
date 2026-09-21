// --- START OF FILE Autonomous.Senolytic.Population.cuh ---

#ifndef AUTONOMOUS_SENOLYTIC_POPULATION_CUH
#define AUTONOMOUS_SENOLYTIC_POPULATION_CUH

#include <cuda_runtime.h>
#include <cstdint>
#include "Thermodynamic.Neural.Network.cuh"
#include "Biophysical.Telemetry.Spooler.cuh"
#include "Spatial.Optical.Integration.cuh"

__host__ __device__ inline uint32_t Generate_PCG_Hash(uint32_t input) {
    uint32_t state = input * 747796405u + 2891336453u;
    uint32_t word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

__host__ __device__ inline float Generate_Stochastic_Float(uint32_t hash) {
    return (hash & 0x00FFFFFF) / static_cast<float>(0x01000000);
}

__host__ __device__ inline float Mathematical_Smoothstep(float edge0, float edge1, float x) {
    float t = fminf(1.0f, fmaxf(0.0f, (x - edge0) / (edge1 - edge0)));
    return t * t * (3.0f - 2.0f * t);
}

class SenescentCellPopulation {
public:
    int population_size;
    int global_genomic_offset;

    // Phase 85: Ping-Pong Architecture for Spatiotemporal Concurrency
    float* d_pos_x_current;
    float* d_pos_y_current;
    float* d_membrane_integrity_current;
    float* d_tissue_density_grid_current;

    float* d_pos_x_next;
    float* d_pos_y_next;
    float* d_membrane_integrity_next;
    float* d_tissue_density_grid_next;

    SenescentCellPopulation(int size, uint32_t temporal_seed);
    ~SenescentCellPopulation();

    void AssignGlobalGenomicOffset(int offset);
    void SwapStates();

    void ExecuteMotilityPhase(const float* d_agent_density_current, unsigned long long sys_tick, cudaStream_t stream);

    // Phase 93 Fix: Signature updated to receive full SIRPA protein tensors directly from Orchestrator
    void ExecuteSecretionPhase(float* d_sasp_grid, float* d_atp_grid, const float* d_senophage_density_current, const float* d_scavenger_density_current, unsigned long long sys_tick, const float* cd47_protein_level_current, const float* senophage_sirpa_curr, const float* scavenger_sirpa_curr, cudaStream_t stream);

    void ProjectTissueDensity(cudaStream_t stream);
};

class AutonomousSenolyticAgentPopulation {
public:
    int population_size;
    int global_genomic_offset;

    // Phase 85: Ping-Pong Architecture for Hazard-Free Execution
    float* d_pos_x_current;
    float* d_pos_y_current;
    float* d_vel_x_current;
    float* d_vel_y_current;
    float* d_atp_level_current;
    float* d_lipid_burden_current;
    float* d_olfactory_desensitization_current;
    float* d_agent_density_grid_current;

    float* d_pos_x_next;
    float* d_pos_y_next;
    float* d_vel_x_next;
    float* d_vel_y_next;
    float* d_atp_level_next;
    float* d_lipid_burden_next;
    float* d_olfactory_desensitization_next;
    float* d_agent_density_grid_next;

    // Network & batches can be single buffer as they are processed sequentially within the same stream
    float* d_sensors_batch;
    float* d_motors_batch;
    float* d_reward_signal;

    ThermodynamicNeuralNetwork* thermodynamic_neural_lattice;

    AutonomousSenolyticAgentPopulation(int size, uint32_t temporal_seed);
    ~AutonomousSenolyticAgentPopulation();

    void AssignGlobalGenomicOffset(int offset);
    void SwapStates();

    void ExecuteMetabolicPhase(float* d_sasp_grid, float* d_fluid_ext_fx, float* d_fluid_ext_fy,
        const float* d_tissue_density_current, const float* t_pos_x_curr, const float* t_pos_y_curr, const float* t_integrity_curr, const float* t_cd47_level_curr, int t_count,
        const float* a_px_curr, const float* a_py_curr, int a_count,
        unsigned long long thermodynamic_tick, float basal_motility_scalar, float quiescence_scalar, float macropinocytosis_scalar,
        float learning_rate_scalar, float entropy_decay_scalar, float lateral_inhibition_scalar,
        const float* d_protein_actb_curr, const float* d_protein_cd47_curr, const float* d_protein_sirpa_curr, const float* d_protein_p2ry2_curr, const float* d_protein_abca1_curr,
        cudaStream_t stream);

    void ProjectAgentDensity(cudaStream_t stream);
};

#endif // AUTONOMOUS_SENOLYTIC_POPULATION_CUH
// --- END OF FILE Autonomous.Senolytic.Population.cuh ---