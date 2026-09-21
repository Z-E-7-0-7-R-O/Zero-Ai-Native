#ifndef PROTEOMIC_EXPRESSION_STATE_CUH
#define PROTEOMIC_EXPRESSION_STATE_CUH

#include <cuda_runtime.h>

class ProteomicExpressionState {
public:
    ProteomicExpressionState();
    ~ProteomicExpressionState();

    void AllocateProteomicTensors(int total_agents, cudaStream_t stream = 0);
    void DeallocateProteomicTensors();

    // Phase 85: Zero-Cost Pointer Swapping
    void SwapStates();

    // Ping-Pong Buffer T (Current State - Read Only during tick)
    float* d_protein_level_ACTB_current;
    float* d_protein_level_CD47_current;
    float* d_protein_level_SIRPA_current;
    float* d_protein_level_P2RY2_current;
    float* d_protein_level_ABCA1_current;

    // Ping-Pong Buffer T+1 (Next State - Write Only during tick)
    float* d_protein_level_ACTB_next;
    float* d_protein_level_CD47_next;
    float* d_protein_level_SIRPA_next;
    float* d_protein_level_P2RY2_next;
    float* d_protein_level_ABCA1_next;
};

#endif // PROTEOMIC_EXPRESSION_STATE_CUH