#ifndef GENOMIC_REPAIR_PARP_CUH
#define GENOMIC_REPAIR_PARP_CUH

#include <cuda_runtime.h>
#include "Macromolecular.Genomic.Allocation.cuh"

// Phase 85: Population classes uncoupled to prevent cross-header dependency loops
class ThermodynamicPARPRepairEngine {
public:
    ThermodynamicPARPRepairEngine(MacromolecularGenomicEnvironment* genome_env);
    ~ThermodynamicPARPRepairEngine();

    void ExecuteTissueRepair(int pop_size, int global_offset, const float* integrity_current, float* integrity_next, unsigned long long sys_tick, cudaStream_t stream);

    void ExecuteAgentRepair(int pop_size, int global_offset, const float* atp_current, float* atp_next, unsigned long long sys_tick, cudaStream_t stream);

private:
    MacromolecularGenomicEnvironment* d_genome_environment;
};

#endif // GENOMIC_REPAIR_PARP_CUH