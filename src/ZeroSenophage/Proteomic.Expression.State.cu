#include "Proteomic.Expression.State.cuh"
#include <iostream>
#include <utility>

ProteomicExpressionState::ProteomicExpressionState() :
    d_protein_level_ACTB_current(nullptr),
    d_protein_level_CD47_current(nullptr),
    d_protein_level_SIRPA_current(nullptr),
    d_protein_level_P2RY2_current(nullptr),
    d_protein_level_ABCA1_current(nullptr),
    d_protein_level_ACTB_next(nullptr),
    d_protein_level_CD47_next(nullptr),
    d_protein_level_SIRPA_next(nullptr),
    d_protein_level_P2RY2_next(nullptr),
    d_protein_level_ABCA1_next(nullptr)
{
}

ProteomicExpressionState::~ProteomicExpressionState() {
    DeallocateProteomicTensors();
}

void ProteomicExpressionState::AllocateProteomicTensors(int total_agents, cudaStream_t stream) {
    size_t mem_size = total_agents * sizeof(float);

    // Allocate Current Buffers
    cudaMalloc(&d_protein_level_ACTB_current, mem_size);
    cudaMalloc(&d_protein_level_CD47_current, mem_size);
    cudaMalloc(&d_protein_level_SIRPA_current, mem_size);
    cudaMalloc(&d_protein_level_P2RY2_current, mem_size);
    cudaMalloc(&d_protein_level_ABCA1_current, mem_size);

    // Allocate Next Buffers
    cudaMalloc(&d_protein_level_ACTB_next, mem_size);
    cudaMalloc(&d_protein_level_CD47_next, mem_size);
    cudaMalloc(&d_protein_level_SIRPA_next, mem_size);
    cudaMalloc(&d_protein_level_P2RY2_next, mem_size);
    cudaMalloc(&d_protein_level_ABCA1_next, mem_size);

    // Asynchronous Initialization
    cudaMemsetAsync(d_protein_level_ACTB_current, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_CD47_current, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_SIRPA_current, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_P2RY2_current, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_ABCA1_current, 0, mem_size, stream);

    cudaMemsetAsync(d_protein_level_ACTB_next, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_CD47_next, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_SIRPA_next, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_P2RY2_next, 0, mem_size, stream);
    cudaMemsetAsync(d_protein_level_ABCA1_next, 0, mem_size, stream);
}

void ProteomicExpressionState::DeallocateProteomicTensors() {
    if (d_protein_level_ACTB_current) cudaFree(d_protein_level_ACTB_current);
    if (d_protein_level_CD47_current) cudaFree(d_protein_level_CD47_current);
    if (d_protein_level_SIRPA_current) cudaFree(d_protein_level_SIRPA_current);
    if (d_protein_level_P2RY2_current) cudaFree(d_protein_level_P2RY2_current);
    if (d_protein_level_ABCA1_current) cudaFree(d_protein_level_ABCA1_current);

    if (d_protein_level_ACTB_next) cudaFree(d_protein_level_ACTB_next);
    if (d_protein_level_CD47_next) cudaFree(d_protein_level_CD47_next);
    if (d_protein_level_SIRPA_next) cudaFree(d_protein_level_SIRPA_next);
    if (d_protein_level_P2RY2_next) cudaFree(d_protein_level_P2RY2_next);
    if (d_protein_level_ABCA1_next) cudaFree(d_protein_level_ABCA1_next);
}

// Phase 85: Zero-Cost hardware pointer swapping
// Bypasses the VRAM bandwidth exhaustion associated with cudaMemcpy
void ProteomicExpressionState::SwapStates() {
    std::swap(d_protein_level_ACTB_current, d_protein_level_ACTB_next);
    std::swap(d_protein_level_CD47_current, d_protein_level_CD47_next);
    std::swap(d_protein_level_SIRPA_current, d_protein_level_SIRPA_next);
    std::swap(d_protein_level_P2RY2_current, d_protein_level_P2RY2_next);
    std::swap(d_protein_level_ABCA1_current, d_protein_level_ABCA1_next);
}