// --- START OF FILE Epigenetic.Promoter.Indexing.cuh ---

#ifndef EPIGENETIC_PROMOTER_INDEXING_CUH
#define EPIGENETIC_PROMOTER_INDEXING_CUH

#include <cuda_runtime.h>

class EpigeneticPromoterRegistry {
public:
    EpigeneticPromoterRegistry();
    ~EpigeneticPromoterRegistry();

    // Allocates continuous tensor arrays for the entire ecosystem population
    void AllocateEpigeneticTensors(int total_agents);
    void DeallocateEpigeneticTensors();

    // Initializes epigenetic methylation profiles based on spatial block offsets
    void InitializeSenescentProfile(int start_idx, int count);
    void InitializeSenophageProfile(int start_idx, int count);
    void InitializeScavengerProfile(int start_idx, int count);

    // Epigenetic Access Weights (Float 0.0 to 1.0) for Continuous Transcription Scaling
    float* d_epigenetic_weight_ACTB;
    float* d_epigenetic_weight_CD47;
    float* d_epigenetic_weight_SIRPA;
    float* d_epigenetic_weight_P2RY2;
    float* d_epigenetic_weight_ABCA1;
};

#endif // EPIGENETIC_PROMOTER_INDEXING_CUH