#include "Macromolecular.Genomic.Allocation.cuh"
#include "Biochemical.Constants.h"
#include <iostream>

__device__ inline uint32_t Genomic_PCG_Hash(uint64_t input) {
    uint64_t state = input * 6364136223846793005ULL + 1442695040888963407ULL;
    uint32_t xorshifted = ((state >> 18u) ^ state) >> 27u;
    uint32_t rot = state >> 59u;
    return (xorshifted >> rot) | (xorshifted << ((-rot) & 31));
}

__global__ void Stochastic_Heterochromatin_Seeding_Kernel(uint32_t* d_genome, size_t total_words) {
    size_t global_idx = static_cast<size_t>(blockIdx.x) * blockDim.x + threadIdx.x;

    if (global_idx >= total_words) return;

    uint64_t physical_seed = static_cast<uint64_t>(global_idx) ^ 0x9E3779B97F4A7C15ULL;
    d_genome[global_idx] = Genomic_PCG_Hash(physical_seed);
}

__global__ void WildType_CodingSequence_Implantation_Kernel(uint32_t* d_genome, int total_agents, size_t words_per_agent) {
    int agent_id = blockIdx.x * blockDim.x + threadIdx.x;

    if (agent_id >= total_agents) return;

    size_t base_address = static_cast<size_t>(agent_id) * words_per_agent;
    uint32_t wild_type_stability_pattern = 0xAAAAAAAA;

    for (size_t i = 0; i < BiophysicalConstants::LOCUS_LENGTH_ACTB; ++i) {
        d_genome[base_address + BiophysicalConstants::LOCUS_OFFSET_ACTB + i] = wild_type_stability_pattern;
    }

    for (size_t i = 0; i < BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR; ++i) {
        d_genome[base_address + BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR + i] = wild_type_stability_pattern;
    }

    for (size_t i = 0; i < BiophysicalConstants::LOCUS_LENGTH_CD47; ++i) {
        d_genome[base_address + BiophysicalConstants::LOCUS_OFFSET_CD47 + i] = wild_type_stability_pattern;
    }

    for (size_t i = 0; i < BiophysicalConstants::LOCUS_LENGTH_SIRPA; ++i) {
        d_genome[base_address + BiophysicalConstants::LOCUS_OFFSET_SIRPA + i] = wild_type_stability_pattern;
    }

    for (size_t i = 0; i < BiophysicalConstants::LOCUS_LENGTH_P2RY2; ++i) {
        d_genome[base_address + BiophysicalConstants::LOCUS_OFFSET_P2RY2 + i] = wild_type_stability_pattern;
    }

    for (size_t i = 0; i < BiophysicalConstants::LOCUS_LENGTH_ABCA1; ++i) {
        d_genome[base_address + BiophysicalConstants::LOCUS_OFFSET_ABCA1 + i] = wild_type_stability_pattern;
    }
}

MacromolecularGenomicEnvironment::MacromolecularGenomicEnvironment() : d_global_genome_sequence(nullptr) {
}

MacromolecularGenomicEnvironment::~MacromolecularGenomicEnvironment() {
    DeallocateGenomicSubsystem();
}

void MacromolecularGenomicEnvironment::InitializeGenomicSubsystem(int total_agents, cudaStream_t stream) {
    size_t memory_bytes = BiophysicalConstants::GENOMICS_TOTAL_WORDS * sizeof(uint32_t);
    cudaError_t alloc_status = cudaMalloc(reinterpret_cast<void**>(&d_global_genome_sequence), memory_bytes);

    if (alloc_status != cudaSuccess) {
        std::cerr << "[SYSTEM HALT] Terminal VRAM Allocation Failure: Genomic Architecture Exceeds Physical Bounds." << std::endl;
        return;
    }

    ExecuteHeterochromatinSeeding(stream);
    ExecuteCodingSequenceImplantation(total_agents, stream);
}

void MacromolecularGenomicEnvironment::ExecuteHeterochromatinSeeding(cudaStream_t stream) {
    int threads = 256;
    size_t total_blocks = (BiophysicalConstants::GENOMICS_TOTAL_WORDS + threads - 1) / threads;

    Stochastic_Heterochromatin_Seeding_Kernel << <static_cast<unsigned int>(total_blocks), threads, 0, stream >> > (
        d_global_genome_sequence,
        BiophysicalConstants::GENOMICS_TOTAL_WORDS
        );
}

void MacromolecularGenomicEnvironment::ExecuteCodingSequenceImplantation(int total_agents, cudaStream_t stream) {
    int threads = 256;
    int total_blocks = (total_agents + threads - 1) / threads;

    WildType_CodingSequence_Implantation_Kernel << <total_blocks, threads, 0, stream >> > (
        d_global_genome_sequence,
        total_agents,
        BiophysicalConstants::GENOMICS_WORDS_PER_AGENT
        );
}

void MacromolecularGenomicEnvironment::DeallocateGenomicSubsystem() {
    if (d_global_genome_sequence) {
        cudaFree(d_global_genome_sequence);
        d_global_genome_sequence = nullptr;
    }
}