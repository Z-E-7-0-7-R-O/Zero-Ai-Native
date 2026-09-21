#ifndef STOCHASTIC_MUTAGENESIS_KINEMATICS_CUH
#define STOCHASTIC_MUTAGENESIS_KINEMATICS_CUH

#include <cuda_runtime.h>
#include "Macromolecular.Genomic.Allocation.cuh"

// Phase 85: Class decoupling preserves header compilation integrity
class ThermodynamicMutagenesisEngine {
public:
    ThermodynamicMutagenesisEngine(MacromolecularGenomicEnvironment* genome_env);
    ~ThermodynamicMutagenesisEngine();

    void InduceTissueGenotoxicity(int pop_size, int global_offset, const float* p_x_curr, const float* p_y_curr, const float* integrity_curr, const float* d_sasp_grid, unsigned long long sys_tick, cudaStream_t stream);

    void InduceAgentGenotoxicity(int pop_size, int global_offset, const float* p_x_curr, const float* p_y_curr, const float* atp_curr, const float* lipid_curr, const float* d_sasp_grid, unsigned long long sys_tick, cudaStream_t stream);

private:
    MacromolecularGenomicEnvironment* d_genome_environment;
};

#endif // STOCHASTIC_MUTAGENESIS_KINEMATICS_CUH