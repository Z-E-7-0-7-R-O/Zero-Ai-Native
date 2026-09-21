#ifndef CENTRAL_DOGMA_TRANSCRIPTION_CUH
#define CENTRAL_DOGMA_TRANSCRIPTION_CUH

#include <cuda_runtime.h>
#include "Macromolecular.Genomic.Allocation.cuh"
#include "Epigenetic.Promoter.Indexing.cuh"
#include "Proteomic.Expression.State.cuh"

class CentralDogmaEngine {
public:
    CentralDogmaEngine(MacromolecularGenomicEnvironment* genome_env,
        EpigeneticPromoterRegistry* epigenetic_reg,
        ProteomicExpressionState* proteomic_state);
    ~CentralDogmaEngine();

    void ExecuteTranscription(unsigned long long current_tick, int total_agents, cudaStream_t stream);

private:
    MacromolecularGenomicEnvironment* d_genome_environment;
    EpigeneticPromoterRegistry* d_epigenetic_registry;
    ProteomicExpressionState* d_proteomic_state;
};

#endif // CENTRAL_DOGMA_TRANSCRIPTION_CUH