// --- START OF FILE Epigenetic.Promoter.Indexing.cu ---

#include "Epigenetic.Promoter.Indexing.cuh"
#include <iostream>

// Kernel to completely methylate immune receptors but fully open the CD47 promoter
__global__ void Initialize_Senescent_Methylome_Kernel(
    int start_idx, int count,
    float* actb_weight, float* cd47_weight, float* sirpa_weight, float* p2ry2_weight, float* abca1_weight)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= count) return;
    int global_idx = start_idx + idx;

    actb_weight[global_idx] = 0.05f;   // Highly methylated, severely restricted basal motility
    cd47_weight[global_idx] = 1.0f;    // Euchromatin state: Overexpression of "Don't Eat Me" signal
    sirpa_weight[global_idx] = 0.0f;   // Fully Methylated: Receptor silenced
    p2ry2_weight[global_idx] = 0.0f;   // Fully Methylated: Receptor silenced
    abca1_weight[global_idx] = 0.0f;   // Fully Methylated: Efflux pump silenced
}

// Kernel to open ACTB for tracking, but Epigenetically KNOCKOUT SIRPA to blind the agent to CD47
__global__ void Initialize_Senophage_Methylome_Kernel(
    int start_idx, int count,
    float* actb_weight, float* cd47_weight, float* sirpa_weight, float* p2ry2_weight, float* abca1_weight)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= count) return;
    int global_idx = start_idx + idx;

    actb_weight[global_idx] = 1.0f;    // Euchromatin state: Maximum Actin polymerization capacity
    cd47_weight[global_idx] = 0.0f;    // Fully Methylated
    // Phase 65: Absolute Epigenetic Knockout of SIRPA. This renders the senophage physically immune to CD47 evasion signals.
    sirpa_weight[global_idx] = 0.0f;
    p2ry2_weight[global_idx] = 0.0f;   // Fully Methylated
    abca1_weight[global_idx] = 0.0f;   // Fully Methylated
}

// Kernel to open lipid handling and ATP sensing genes for bulk clearance
__global__ void Initialize_Scavenger_Methylome_Kernel(
    int start_idx, int count,
    float* actb_weight, float* cd47_weight, float* sirpa_weight, float* p2ry2_weight, float* abca1_weight)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= count) return;
    int global_idx = start_idx + idx;

    actb_weight[global_idx] = 0.6f;    // Partial Methylation: Moderate basal motility
    cd47_weight[global_idx] = 0.0f;    // Fully Methylated
    sirpa_weight[global_idx] = 0.0f;   // Fully Methylated
    p2ry2_weight[global_idx] = 1.0f;   // Euchromatin state: ATP Find-Me gradient sensing active
    abca1_weight[global_idx] = 1.0f;   // Euchromatin state: Lipid efflux pump maximally active
}

EpigeneticPromoterRegistry::EpigeneticPromoterRegistry() :
    d_epigenetic_weight_ACTB(nullptr),
    d_epigenetic_weight_CD47(nullptr),
    d_epigenetic_weight_SIRPA(nullptr),
    d_epigenetic_weight_P2RY2(nullptr),
    d_epigenetic_weight_ABCA1(nullptr)
{
}

EpigeneticPromoterRegistry::~EpigeneticPromoterRegistry() {
    DeallocateEpigeneticTensors();
}

void EpigeneticPromoterRegistry::AllocateEpigeneticTensors(int total_agents) {
    size_t mem_size = total_agents * sizeof(float);

    cudaMalloc(&d_epigenetic_weight_ACTB, mem_size);
    cudaMalloc(&d_epigenetic_weight_CD47, mem_size);
    cudaMalloc(&d_epigenetic_weight_SIRPA, mem_size);
    cudaMalloc(&d_epigenetic_weight_P2RY2, mem_size);
    cudaMalloc(&d_epigenetic_weight_ABCA1, mem_size);
}

void EpigeneticPromoterRegistry::DeallocateEpigeneticTensors() {
    if (d_epigenetic_weight_ACTB) cudaFree(d_epigenetic_weight_ACTB);
    if (d_epigenetic_weight_CD47) cudaFree(d_epigenetic_weight_CD47);
    if (d_epigenetic_weight_SIRPA) cudaFree(d_epigenetic_weight_SIRPA);
    if (d_epigenetic_weight_P2RY2) cudaFree(d_epigenetic_weight_P2RY2);
    if (d_epigenetic_weight_ABCA1) cudaFree(d_epigenetic_weight_ABCA1);
}

void EpigeneticPromoterRegistry::InitializeSenescentProfile(int start_idx, int count) {
    int threads = 256;
    int blocks = (count + threads - 1) / threads;
    Initialize_Senescent_Methylome_Kernel << <blocks, threads >> > (
        start_idx, count,
        d_epigenetic_weight_ACTB, d_epigenetic_weight_CD47,
        d_epigenetic_weight_SIRPA, d_epigenetic_weight_P2RY2, d_epigenetic_weight_ABCA1
        );
    cudaDeviceSynchronize();
}

void EpigeneticPromoterRegistry::InitializeSenophageProfile(int start_idx, int count) {
    int threads = 256;
    int blocks = (count + threads - 1) / threads;
    Initialize_Senophage_Methylome_Kernel << <blocks, threads >> > (
        start_idx, count,
        d_epigenetic_weight_ACTB, d_epigenetic_weight_CD47,
        d_epigenetic_weight_SIRPA, d_epigenetic_weight_P2RY2, d_epigenetic_weight_ABCA1
        );
    cudaDeviceSynchronize();
}

void EpigeneticPromoterRegistry::InitializeScavengerProfile(int start_idx, int count) {
    int threads = 256;
    int blocks = (count + threads - 1) / threads;
    Initialize_Scavenger_Methylome_Kernel << <blocks, threads >> > (
        start_idx, count,
        d_epigenetic_weight_ACTB, d_epigenetic_weight_CD47,
        d_epigenetic_weight_SIRPA, d_epigenetic_weight_P2RY2, d_epigenetic_weight_ABCA1
        );
    cudaDeviceSynchronize();
}