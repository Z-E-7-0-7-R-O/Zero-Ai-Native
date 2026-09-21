#ifndef SPATIAL_OPTICAL_INTEGRATION_CUH
#define SPATIAL_OPTICAL_INTEGRATION_CUH

#include <cuda_runtime.h>
#include <cstdint>

// Phase 85: Decoupled Spatial and Optical Projection Interfaces
// These wrappers allow the Orchestrator to project discrete biological data into continuous physical grids without invoking population class methods directly.

void ExecuteSpatialDensityProjection(
    int population_size, const float* p_x_curr, const float* p_y_curr, const float* mass_curr,
    float* density_grid, int width, int height, int splat_radius, float sigma_sq,
    cudaStream_t stream);

void SplatBiochemicalState(
    int population_size, const float* p_x_curr, const float* p_y_curr, const float* membrane_integrity_curr,
    const float* cd47_levels_curr, const uint32_t* global_genome, int global_offset,
    float* biochemical_grid, int width, int height, int splat_radius, float sigma_sq, unsigned long long sys_tick,
    cudaStream_t stream);

void IntegrateOpticalBiochemicalFields(
    float* d_linear_biochemical_buffer, const float* d_biochemical_grid,
    const float* d_sasp_grid, const float* d_tissue_density_curr, int total_voxels,
    cudaStream_t stream);

void IntegrateOpticalFields(
    float* d_linear_optical_buffer, const float* d_plasma_rho, const float* d_sasp, const float* d_atp,
    const float* d_tissue_curr, const float* d_agent_curr, const float* d_scavenger_curr,
    int total_voxels, cudaStream_t stream);

#endif // SPATIAL_OPTICAL_INTEGRATION_CUH