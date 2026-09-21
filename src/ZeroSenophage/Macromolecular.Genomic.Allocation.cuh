#ifndef MACROMOLECULAR_GENOMIC_ALLOCATION_CUH
#define MACROMOLECULAR_GENOMIC_ALLOCATION_CUH

#include <cuda_runtime.h>
#include <cstdint>
#include <cstddef>

class MacromolecularGenomicEnvironment {
public:
    MacromolecularGenomicEnvironment();
    ~MacromolecularGenomicEnvironment();

    void InitializeGenomicSubsystem(int total_agents, cudaStream_t stream = 0);
    void DeallocateGenomicSubsystem();

    uint32_t* d_global_genome_sequence;

private:
    void ExecuteHeterochromatinSeeding(cudaStream_t stream);
    void ExecuteCodingSequenceImplantation(int total_agents, cudaStream_t stream);
};

#endif // MACROMOLECULAR_GENOMIC_ALLOCATION_CUH