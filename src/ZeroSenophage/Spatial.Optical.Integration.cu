// --- START OF FILE Spatial.Optical.Integration.cu ---

#include "Spatial.Optical.Integration.cuh"
#include "Biochemical.Constants.h"
#include <math.h>

__host__ __device__ inline float Mathematical_Smoothstep(float edge0, float edge1, float x) {
    float t = fminf(1.0f, fmaxf(0.0f, (x - edge0) / (edge1 - edge0)));
    return t * t * (3.0f - 2.0f * t);
}

// Phase 85: Extracted Continuous Field Projection Kernel
// Converts discrete positional points into distributed Gaussian fields representing biological biomass
__global__ void Splat_Density_Kernel(int size, const float* p_x_curr, const float* p_y_curr, const float* mass_curr, float* density_grid, int width, int height, int splat_radius, float sigma_sq) {
    int agent_idx = blockIdx.x;
    if (agent_idx >= size) return;

    __shared__ float center_x;
    __shared__ float center_y;
    __shared__ float current_integrity;

    if (threadIdx.x == 0) {
        center_x = p_x_curr[agent_idx];
        center_y = p_y_curr[agent_idx];
        current_integrity = (mass_curr != nullptr) ? mass_curr[agent_idx] : 1.0f;
    }
    __syncthreads();

    float structural_footprint = BiophysicalConstants::STRUCTURAL_FOOTPRINT_MIN +
        (1.0f - BiophysicalConstants::STRUCTURAL_FOOTPRINT_MIN) * Mathematical_Smoothstep(0.05f, 0.40f, current_integrity);
    float effective_sigma_sq = sigma_sq * structural_footprint;

    int side = 2 * splat_radius + 1;
    int total_voxels = side * side;
    float f_w = static_cast<float>(width);
    float f_h = static_cast<float>(height);

    for (int i = threadIdx.x; i < total_voxels; i += blockDim.x) {
        int dy = i / side - splat_radius;
        int dx = i % side - splat_radius;

        float grid_x = floorf(center_x) + static_cast<float>(dx);
        float grid_y = floorf(center_y) + static_cast<float>(dy);
        float voxel_center_x = grid_x + 0.5f;
        float voxel_center_y = grid_y + 0.5f;

        float raw_dx = fabsf(center_x - voxel_center_x);
        float raw_dy = fabsf(center_y - voxel_center_y);
        float tor_dx = fminf(raw_dx, f_w - raw_dx);
        float tor_dy = fminf(raw_dy, f_h - raw_dy);
        float dist_sq = tor_dx * tor_dx + tor_dy * tor_dy;

        float spatial_weight = expf(-dist_sq / (2.0f * effective_sigma_sq));
        float value = current_integrity * spatial_weight;

        int base_wrap_x = static_cast<int>(floorf(grid_x));
        int base_wrap_y = static_cast<int>(floorf(grid_y));
        int wrap_x = (base_wrap_x % width + width) % width;
        int wrap_y = (base_wrap_y % height + height) % height;
        int grid_idx = wrap_y * width + wrap_x;

        atomicAdd(&density_grid[grid_idx], value);
    }
}

// Phase 85: Extracted Biochemical Signal Splatting
// Distributes genetic/proteomic states (CD47 overexpression and mutational burden) into a visual and chemical field
__global__ void Splat_Biochemical_State_Kernel(
    int size, const float* p_x_curr, const float* p_y_curr, const float* integrity_curr,
    const float* cd47_levels_curr, const uint32_t* genome, size_t words_per_agent, int global_offset,
    float* biochem_grid, int width, int height, int splat_radius, float sigma_sq, unsigned long long sys_tick)
{
    int agent_idx = blockIdx.x;
    if (agent_idx >= size) return;

    __shared__ float center_x;
    __shared__ float center_y;
    __shared__ float current_integrity;
    __shared__ float agent_cd47;
    __shared__ float mutational_burden;

    if (threadIdx.x == 0) {
        center_x = p_x_curr[agent_idx];
        center_y = p_y_curr[agent_idx];
        current_integrity = (integrity_curr != nullptr) ? integrity_curr[agent_idx] : 1.0f;
        agent_cd47 = (cd47_levels_curr != nullptr) ? cd47_levels_curr[agent_idx] : 0.0f;

        float epoch = static_cast<float>(BiophysicalConstants::CENTRAL_DOGMA_EPOCH);
        unsigned long long shift = sys_tick + static_cast<unsigned long long>(global_offset + agent_idx);
        float remainder = static_cast<float>(shift % BiophysicalConstants::CENTRAL_DOGMA_EPOCH);
        float scan_mask = 1.0f - ceilf(remainder / epoch);

        size_t base_address = static_cast<size_t>(global_offset + agent_idx) * words_per_agent;
        size_t total_mutations = 0;
        uint32_t wild_type = 0xAAAAAAAA;

        size_t offsets[6] = { BiophysicalConstants::LOCUS_OFFSET_ACTB, BiophysicalConstants::LOCUS_OFFSET_CD47, BiophysicalConstants::LOCUS_OFFSET_SIRPA, BiophysicalConstants::LOCUS_OFFSET_P2RY2, BiophysicalConstants::LOCUS_OFFSET_ABCA1, BiophysicalConstants::LOCUS_OFFSET_CD47_REPRESSOR };
        size_t lengths[6] = { BiophysicalConstants::LOCUS_LENGTH_ACTB, BiophysicalConstants::LOCUS_LENGTH_CD47, BiophysicalConstants::LOCUS_LENGTH_SIRPA, BiophysicalConstants::LOCUS_LENGTH_P2RY2, BiophysicalConstants::LOCUS_LENGTH_ABCA1, BiophysicalConstants::LOCUS_LENGTH_CD47_REPRESSOR };

        for (int k = 0; k < 6; ++k) {
            size_t effective_length = lengths[k] * static_cast<size_t>(scan_mask);
            for (size_t i = 0; i < effective_length; ++i) {
                uint32_t read_sequence = genome[base_address + offsets[k] + i];
                total_mutations += __popc(read_sequence ^ wild_type);
            }
        }
        mutational_burden = static_cast<float>(total_mutations) * epoch;
    }
    __syncthreads();

    float structural_footprint = BiophysicalConstants::STRUCTURAL_FOOTPRINT_MIN +
        (1.0f - BiophysicalConstants::STRUCTURAL_FOOTPRINT_MIN) * Mathematical_Smoothstep(0.05f, 0.40f, current_integrity);

    float effective_sigma_sq = sigma_sq * structural_footprint;
    float nuclear_sigma_sq = effective_sigma_sq * 0.15f;

    int side = 2 * splat_radius + 1;
    int total_voxels = side * side;
    float f_w = static_cast<float>(width);
    float f_h = static_cast<float>(height);

    for (int i = threadIdx.x; i < total_voxels; i += blockDim.x) {
        int dy = i / side - splat_radius;
        int dx = i % side - splat_radius;

        float grid_x = floorf(center_x) + static_cast<float>(dx);
        float grid_y = floorf(center_y) + static_cast<float>(dy);
        float voxel_center_x = grid_x + 0.5f;
        float voxel_center_y = grid_y + 0.5f;

        float raw_dx = fabsf(center_x - voxel_center_x);
        float raw_dy = fabsf(center_y - voxel_center_y);
        float tor_dx = fminf(raw_dx, f_w - raw_dx);
        float tor_dy = fminf(raw_dy, f_h - raw_dy);
        float dist_sq = tor_dx * tor_dx + tor_dy * tor_dy;

        float general_weight = expf(-dist_sq / (2.0f * effective_sigma_sq));
        float nuclear_weight = expf(-dist_sq / (2.0f * nuclear_sigma_sq));

        float val_0 = agent_cd47 * general_weight;
        float val_1 = mutational_burden * nuclear_weight;

        int base_wrap_x = static_cast<int>(floorf(grid_x));
        int base_wrap_y = static_cast<int>(floorf(grid_y));
        int wrap_x = (base_wrap_x % width + width) % width;
        int wrap_y = (base_wrap_y % height + height) % height;

        int grid_idx = wrap_y * width + wrap_x;
        int cell_idx = grid_idx * 4;

        atomicAdd(&biochem_grid[cell_idx + 0], val_0);
        atomicAdd(&biochem_grid[cell_idx + 1], val_1);
    }
}

// Phase 85: Extracted Optical Preparation Kernel
__global__ void Optical_Integration_Kernel(float* linear_buffer, const float* rho, const float* sasp, const float* atp, const float* tissue, const float* agent, const float* scavenger, int total_voxels) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= total_voxels) return;

    float norm_rho = rho[idx];

    float norm_sasp = 1.0f - expf(-sasp[idx] * 0.5f);
    float norm_atp = 1.0f - expf(-atp[idx] * 0.5f);
    float combined_chemical = norm_sasp - norm_atp;

    float norm_tissue = 1.0f - expf(-tissue[idx] * 1.5f);

    float norm_senophage_val = 1.0f - expf(-agent[idx] * 1.5f);
    float norm_scavenger_val = 1.0f - expf(-scavenger[idx] * 1.5f);
    float combined_agent = norm_senophage_val - norm_scavenger_val;

    int base_idx = idx * 4;
    linear_buffer[base_idx + 0] = norm_rho;
    linear_buffer[base_idx + 1] = combined_chemical;
    linear_buffer[base_idx + 2] = norm_tissue;
    linear_buffer[base_idx + 3] = combined_agent;
}

__global__ void Optical_Biochemical_Integration_Kernel(
    float* linear_biochemical_buffer, const float* biochem_grid,
    const float* sasp_grid, const float* tissue_density, int total_voxels)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= total_voxels) return;

    float cd47_expression = biochem_grid[idx * 4 + 0];
    float mutation_density = biochem_grid[idx * 4 + 1];

    float local_sasp = sasp_grid[idx];
    float local_tissue = tissue_density[idx];

    float acid_factor = (local_sasp * 0.6f) + (1.0f - expf(-local_tissue * 2.0f)) * 0.4f;

    int base_idx = idx * 4;
    linear_biochemical_buffer[base_idx + 0] = cd47_expression;
    linear_biochemical_buffer[base_idx + 1] = mutation_density;
    linear_biochemical_buffer[base_idx + 2] = acid_factor;
    linear_biochemical_buffer[base_idx + 3] = 0.0f;
}

// ==============================================================================
// Host Wrapper Implementations
// ==============================================================================

void ExecuteSpatialDensityProjection(
    int population_size, const float* p_x_curr, const float* p_y_curr, const float* mass_curr,
    float* density_grid, int width, int height, int splat_radius, float sigma_sq,
    cudaStream_t stream)
{
    int blocks = population_size;
    int threads = BiophysicalConstants::BLOCK_PER_AGENT_THREADS;

    Splat_Density_Kernel << <blocks, threads, 0, stream >> > (
        population_size, p_x_curr, p_y_curr, mass_curr, density_grid,
        width, height, splat_radius, sigma_sq
        );
}

void SplatBiochemicalState(
    int population_size, const float* p_x_curr, const float* p_y_curr, const float* membrane_integrity_curr,
    const float* cd47_levels_curr, const uint32_t* global_genome, int global_offset,
    float* biochemical_grid, int width, int height, int splat_radius, float sigma_sq, unsigned long long sys_tick,
    cudaStream_t stream)
{
    int blocks = population_size;
    int threads = BiophysicalConstants::BLOCK_PER_AGENT_THREADS;

    Splat_Biochemical_State_Kernel << <blocks, threads, 0, stream >> > (
        population_size, p_x_curr, p_y_curr, membrane_integrity_curr, cd47_levels_curr, global_genome,
        BiophysicalConstants::GENOMICS_WORDS_PER_AGENT, global_offset,
        biochemical_grid, width, height, splat_radius, sigma_sq, sys_tick
        );
}

void IntegrateOpticalBiochemicalFields(
    float* d_linear_biochemical_buffer, const float* d_biochemical_grid,
    const float* d_sasp_grid, const float* d_tissue_density_curr, int total_voxels,
    cudaStream_t stream)
{
    int threads = 256;
    int blocks = (total_voxels + threads - 1) / threads;

    Optical_Biochemical_Integration_Kernel << <blocks, threads, 0, stream >> > (
        d_linear_biochemical_buffer, d_biochemical_grid, d_sasp_grid, d_tissue_density_curr, total_voxels
        );
}

void IntegrateOpticalFields(float* d_linear_optical_buffer, const float* d_plasma_rho, const float* d_sasp, const float* d_atp, const float* d_tissue_curr, const float* d_agent_curr, const float* d_scavenger_curr, int total_voxels, cudaStream_t stream) {
    int threads = 256;
    int blocks = (total_voxels + threads - 1) / threads;
    Optical_Integration_Kernel << <blocks, threads, 0, stream >> > (d_linear_optical_buffer, d_plasma_rho, d_sasp, d_atp, d_tissue_curr, d_agent_curr, d_scavenger_curr, total_voxels);
}
// --- END OF FILE Spatial.Optical.Integration.cu ---