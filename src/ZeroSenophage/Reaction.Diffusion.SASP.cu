// --- START OF FILE Reaction.Diffusion.SASP.cu ---

#include "Reaction.Diffusion.SASP.cuh"

__global__ void PDE_Reaction_Diffusion_Kernel(
    const float* sasp_current, float* sasp_next,
    const float* ux, const float* uy, const float* agent_density,
    int width, int height, float diffusion_rate, float decay_rate, float endocytosis_rate)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    int idx = y * width + x;

    int x_left = (x - 1 + width) % width;
    int x_right = (x + 1) % width;
    int y_up = (y - 1 + height) % height;
    int y_down = (y + 1) % height;

    float c_center = sasp_current[idx];
    float c_left = sasp_current[y * width + x_left];
    float c_right = sasp_current[y * width + x_right];
    float c_up = sasp_current[y_up * width + x];
    float c_down = sasp_current[y_down * width + x];

    float c_nw = sasp_current[y_up * width + x_left];
    float c_ne = sasp_current[y_up * width + x_right];
    float c_sw = sasp_current[y_down * width + x_left];
    float c_se = sasp_current[y_down * width + x_right];

    float laplacian = (4.0f * (c_up + c_down + c_left + c_right) + 1.0f * (c_nw + c_ne + c_sw + c_se) - 20.0f * c_center) / 6.0f;

    float fluid_u = ux[idx];
    float fluid_v = uy[idx];

    float back_x = static_cast<float>(x) - fluid_u;
    float back_y = static_cast<float>(y) - fluid_v;

    float f_width = static_cast<float>(width);
    float f_height = static_cast<float>(height);

    // Floating point domain wrapping (initial shift)
    back_x = back_x - floorf(back_x / f_width) * f_width;
    back_y = back_y - floorf(back_y / f_height) * f_height;

    // Phase 89: Absolute Integer Modulo Sealing
    // Eradicating IEEE 754 precision singularities that caused Out-Of-Bounds (OOB) memory reads at edge coordinates.
    // Forces absolute mathematical confinement within the 0 to (width-1) and 0 to (height-1) tensor boundaries.
    int raw_x0 = static_cast<int>(floorf(back_x));
    int raw_y0 = static_cast<int>(floorf(back_y));

    int x0 = (raw_x0 % width + width) % width;
    int y0 = (raw_y0 % height + height) % height;
    int x1 = (x0 + 1) % width;
    int y1 = (y0 + 1) % height;

    // Phase 89: Sub-pixel interpolation factors mathematically secured
    float tx = back_x - floorf(back_x);
    float ty = back_y - floorf(back_y);

    float c00 = sasp_current[y0 * width + x0];
    float c10 = sasp_current[y0 * width + x1];
    float c01 = sasp_current[y1 * width + x0];
    float c11 = sasp_current[y1 * width + x1];

    float lerp_x0 = c00 * (1.0f - tx) + c10 * tx;
    float lerp_x1 = c01 * (1.0f - tx) + c11 * tx;
    float advected_c = lerp_x0 * (1.0f - ty) + lerp_x1 * ty;

    float local_agent_density = agent_density[idx];
    float clearance = endocytosis_rate * c_center * local_agent_density;

    float next_concentration = advected_c + (diffusion_rate * laplacian) - (decay_rate * c_center) - clearance;

    sasp_next[idx] = fmaxf(0.0f, next_concentration);
}

ReactionDiffusionField::ReactionDiffusionField() : d_sasp_concentration(nullptr), d_sasp_next(nullptr), d_atp_concentration(nullptr), d_atp_next(nullptr) {
}

ReactionDiffusionField::~ReactionDiffusionField() {
    cudaFree(d_sasp_concentration);
    cudaFree(d_sasp_next);
    cudaFree(d_atp_concentration);
    cudaFree(d_atp_next);
}

void ReactionDiffusionField::InitializeGradientField(cudaStream_t stream) {
    size_t mem_size = BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * sizeof(float);
    cudaMalloc(&d_sasp_concentration, mem_size);
    cudaMalloc(&d_sasp_next, mem_size);
    cudaMalloc(&d_atp_concentration, mem_size);
    cudaMalloc(&d_atp_next, mem_size);

    cudaMemsetAsync(d_sasp_concentration, 0, mem_size, stream);
    cudaMemsetAsync(d_sasp_next, 0, mem_size, stream);
    cudaMemsetAsync(d_atp_concentration, 0, mem_size, stream);
    cudaMemsetAsync(d_atp_next, 0, mem_size, stream);
}

void ReactionDiffusionField::EvolveChemicalState(const float* d_fluid_ux, const float* d_fluid_uy, const float* d_agent_density, const float* d_scavenger_density, cudaStream_t stream) {
    dim3 threads(32, 32);
    dim3 blocks((BiophysicalConstants::ENVIRONMENT_WIDTH + threads.x - 1) / threads.x,
        (BiophysicalConstants::ENVIRONMENT_HEIGHT + threads.y - 1) / threads.y);

    float natural_decay = 0.005f;
    float endocytosis_rate = 0.15f;

    PDE_Reaction_Diffusion_Kernel << <blocks, threads, 0, stream >> > (
        d_sasp_concentration, d_sasp_next,
        d_fluid_ux, d_fluid_uy, d_agent_density,
        BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        BiophysicalConstants::SASP_DIFFUSION_RATE, natural_decay, endocytosis_rate
        );

    float atp_decay = 0.01f;
    float atp_endocytosis = 0.20f;
    float atp_diffusion = 0.25f;

    PDE_Reaction_Diffusion_Kernel << <blocks, threads, 0, stream >> > (
        d_atp_concentration, d_atp_next,
        d_fluid_ux, d_fluid_uy, d_scavenger_density,
        BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        atp_diffusion, atp_decay, atp_endocytosis
        );

    float* temp_ptr = d_sasp_concentration;
    d_sasp_concentration = d_sasp_next;
    d_sasp_next = temp_ptr;

    temp_ptr = d_atp_concentration;
    d_atp_concentration = d_atp_next;
    d_atp_next = temp_ptr;
}