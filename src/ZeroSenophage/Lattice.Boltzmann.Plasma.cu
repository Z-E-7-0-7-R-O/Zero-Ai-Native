#include "Lattice.Boltzmann.Plasma.cuh"
#include "Autonomous.Senolytic.Population.cuh" 

__constant__ float d_w[9] = { 4.0f / 9.0f, 1.0f / 9.0f, 1.0f / 9.0f, 1.0f / 9.0f, 1.0f / 9.0f, 1.0f / 36.0f, 1.0f / 36.0f, 1.0f / 36.0f, 1.0f / 36.0f };
__constant__ int d_ex[9] = { 0, 1, 0, -1, 0, 1, -1, -1, 1 };
__constant__ int d_ey[9] = { 0, 0, 1, 0, -1, 1, 1, -1, -1 };

__device__ inline void LBM_Atomic_Max_Double(double* address, double value) {
    unsigned long long int* address_as_ull = (unsigned long long int*)address;
    unsigned long long int old = *address_as_ull, assumed;
    do {
        assumed = old;
        old = atomicCAS(address_as_ull, assumed, __double_as_longlong(fmax(value, __longlong_as_double(assumed))));
    } while (assumed != old);
}

__global__ void LBM_Equilibrium_Genesis_Kernel(
    float* f0, float* f1, float* f2, float* f3, float* f4, float* f5, float* f6, float* f7, float* f8,
    float* f0_n, float* f1_n, float* f2_n, float* f3_n, float* f4_n, float* f5_n, float* f6_n, float* f7_n, float* f8_n,
    float* rho, float* ux, float* uy, float* ext_fx, float* ext_fy, int width, int height)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    int is_valid = (x < width) * (y < height);
    if (!is_valid) return;

    int idx = y * width + x;

    rho[idx] = 1.0f;
    ux[idx] = 0.0f;
    uy[idx] = 0.0f;
    ext_fx[idx] = 0.0f;
    ext_fy[idx] = 0.0f;

    f0[idx] = d_w[0]; f0_n[idx] = d_w[0];
    f1[idx] = d_w[1]; f1_n[idx] = d_w[1];
    f2[idx] = d_w[2]; f2_n[idx] = d_w[2];
    f3[idx] = d_w[3]; f3_n[idx] = d_w[3];
    f4[idx] = d_w[4]; f4_n[idx] = d_w[4];
    f5[idx] = d_w[5]; f5_n[idx] = d_w[5];
    f6[idx] = d_w[6]; f6_n[idx] = d_w[6];
    f7[idx] = d_w[7]; f7_n[idx] = d_w[7];
    f8[idx] = d_w[8]; f8_n[idx] = d_w[8];
}

__global__ void LBM_Collide_Stream_Kernel(
    float* f0, float* f1, float* f2, float* f3, float* f4, float* f5, float* f6, float* f7, float* f8,
    float* f0_n, float* f1_n, float* f2_n, float* f3_n, float* f4_n, float* f5_n, float* f6_n, float* f7_n, float* f8_n,
    float* rho, float* ux, float* uy, float* ext_fx, float* ext_fy, float tau, int width, int height,
    unsigned long long tick, BiophysicalAccumulators* acc)
{
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    int is_valid = (x < width) * (y < height);
    if (!is_valid) return;

    int idx = y * width + x;

    float l_f0 = f0[idx]; float l_f1 = f1[idx]; float l_f2 = f2[idx];
    float l_f3 = f3[idx]; float l_f4 = f4[idx]; float l_f5 = f5[idx];
    float l_f6 = f6[idx]; float l_f7 = f7[idx]; float l_f8 = f8[idx];

    float local_rho_raw = l_f0 + l_f1 + l_f2 + l_f3 + l_f4 + l_f5 + l_f6 + l_f7 + l_f8;

    float density_fluctuation = local_rho_raw - 1.0f;
    float dampened_rho = 1.0f + density_fluctuation * 0.98f;

    float local_rho = fminf(2.0f, fmaxf(0.5f, dampened_rho));
    float inv_rho = 1.0f / local_rho;

    uint32_t brownian_seed_x = Generate_PCG_Hash(static_cast<uint32_t>(idx * 1337 + tick));
    uint32_t brownian_seed_y = Generate_PCG_Hash(static_cast<uint32_t>(idx * 9999 + tick));

    float brownian_fx = (Generate_Stochastic_Float(brownian_seed_x) - 0.5f) * 0.0015f;
    float brownian_fy = (Generate_Stochastic_Float(brownian_seed_y) - 0.5f) * 0.0015f;

    float force_x = ext_fx[idx] + brownian_fx;
    float force_y = ext_fy[idx] + brownian_fy;

    float raw_ux = ((l_f1 + l_f5 + l_f8 - l_f3 - l_f6 - l_f7) + force_x) * inv_rho;
    float raw_uy = ((l_f2 + l_f5 + l_f6 - l_f4 - l_f7 - l_f8) + force_y) * inv_rho;

    float raw_u_mag = sqrtf(raw_ux * raw_ux + raw_uy * raw_uy + 1e-9f);
    float speed_of_sound = 0.577350269f;
    float mach_limit = speed_of_sound * 0.3f;

    float velocity_scalar = (mach_limit * tanhf(raw_u_mag / mach_limit)) / raw_u_mag;

    float local_ux = raw_ux * velocity_scalar;
    float local_uy = raw_uy * velocity_scalar;

    float actual_u_mag = sqrtf(local_ux * local_ux + local_uy * local_uy);

    LBM_Atomic_Max_Double(&(acc->lbm_max_velocity), static_cast<double>(actual_u_mag));

    rho[idx] = local_rho;
    ux[idx] = local_ux;
    uy[idx] = local_uy;

    ext_fx[idx] = 0.0f;
    ext_fy[idx] = 0.0f;

    float u_sq = local_ux * local_ux + local_uy * local_uy;
    float omega = 1.0f / tau;

    float cu, feq;

    cu = d_ex[0] * local_ux + d_ey[0] * local_uy; feq = d_w[0] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f0 = l_f0 - omega * (l_f0 - feq);
    cu = d_ex[1] * local_ux + d_ey[1] * local_uy; feq = d_w[1] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f1 = l_f1 - omega * (l_f1 - feq);
    cu = d_ex[2] * local_ux + d_ey[2] * local_uy; feq = d_w[2] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f2 = l_f2 - omega * (l_f2 - feq);
    cu = d_ex[3] * local_ux + d_ey[3] * local_uy; feq = d_w[3] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f3 = l_f3 - omega * (l_f3 - feq);
    cu = d_ex[4] * local_ux + d_ey[4] * local_uy; feq = d_w[4] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f4 = l_f4 - omega * (l_f4 - feq);
    cu = d_ex[5] * local_ux + d_ey[5] * local_uy; feq = d_w[5] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f5 = l_f5 - omega * (l_f5 - feq);
    cu = d_ex[6] * local_ux + d_ey[6] * local_uy; feq = d_w[6] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f6 = l_f6 - omega * (l_f6 - feq);
    cu = d_ex[7] * local_ux + d_ey[7] * local_uy; feq = d_w[7] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f7 = l_f7 - omega * (l_f7 - feq);
    cu = d_ex[8] * local_ux + d_ey[8] * local_uy; feq = d_w[8] * local_rho * (1.0f + 3.0f * cu + 4.5f * cu * cu - 1.5f * u_sq); l_f8 = l_f8 - omega * (l_f8 - feq);

    f0_n[idx] = l_f0;
    f1_n[y * width + ((x + 1 + width) % width)] = l_f1;
    f2_n[((y + 1 + height) % height) * width + x] = l_f2;
    f3_n[y * width + ((x - 1 + width) % width)] = l_f3;
    f4_n[((y - 1 + height) % height) * width + x] = l_f4;
    f5_n[((y + 1 + height) % height) * width + ((x + 1 + width) % width)] = l_f5;
    f6_n[((y + 1 + height) % height) * width + ((x - 1 + width) % width)] = l_f6;
    f7_n[((y - 1 + height) % height) * width + ((x - 1 + width) % width)] = l_f7;
    f8_n[((y - 1 + height) % height) * width + ((x + 1 + width) % width)] = l_f8;
}

ComputationalFluidDynamicsEnvironment::ComputationalFluidDynamicsEnvironment() : thermodynamic_tick(0) {
    // Initialization deferred to Orchestrator call
}

ComputationalFluidDynamicsEnvironment::~ComputationalFluidDynamicsEnvironment() {
    cudaFree(d_f0); cudaFree(d_f1); cudaFree(d_f2); cudaFree(d_f3);
    cudaFree(d_f4); cudaFree(d_f5); cudaFree(d_f6); cudaFree(d_f7); cudaFree(d_f8);
    cudaFree(d_f0_next); cudaFree(d_f1_next); cudaFree(d_f2_next); cudaFree(d_f3_next);
    cudaFree(d_f4_next); cudaFree(d_f5_next); cudaFree(d_f6_next); cudaFree(d_f7_next); cudaFree(d_f8_next);
    cudaFree(d_density); cudaFree(d_velocity_x); cudaFree(d_velocity_y);
    cudaFree(d_external_force_x); cudaFree(d_external_force_y);
}

void ComputationalFluidDynamicsEnvironment::ExecuteThermodynamicGenesis(cudaStream_t stream) {
    dim3 threads(32, 32);
    dim3 blocks((BiophysicalConstants::ENVIRONMENT_WIDTH + threads.x - 1) / threads.x,
        (BiophysicalConstants::ENVIRONMENT_HEIGHT + threads.y - 1) / threads.y);

    LBM_Equilibrium_Genesis_Kernel << <blocks, threads, 0, stream >> > (
        d_f0, d_f1, d_f2, d_f3, d_f4, d_f5, d_f6, d_f7, d_f8,
        d_f0_next, d_f1_next, d_f2_next, d_f3_next, d_f4_next, d_f5_next, d_f6_next, d_f7_next, d_f8_next,
        d_density, d_velocity_x, d_velocity_y, d_external_force_x, d_external_force_y,
        BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT
        );
}

void ComputationalFluidDynamicsEnvironment::InitializePlasma(cudaStream_t stream) {
    size_t mem_size = BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * sizeof(float);
    cudaMalloc(&d_f0, mem_size); cudaMalloc(&d_f1, mem_size); cudaMalloc(&d_f2, mem_size);
    cudaMalloc(&d_f3, mem_size); cudaMalloc(&d_f4, mem_size); cudaMalloc(&d_f5, mem_size);
    cudaMalloc(&d_f6, mem_size); cudaMalloc(&d_f7, mem_size); cudaMalloc(&d_f8, mem_size);

    cudaMalloc(&d_f0_next, mem_size); cudaMalloc(&d_f1_next, mem_size); cudaMalloc(&d_f2_next, mem_size);
    cudaMalloc(&d_f3_next, mem_size); cudaMalloc(&d_f4_next, mem_size); cudaMalloc(&d_f5_next, mem_size);
    cudaMalloc(&d_f6_next, mem_size); cudaMalloc(&d_f7_next, mem_size); cudaMalloc(&d_f8_next, mem_size);

    cudaMalloc(&d_density, mem_size);
    cudaMalloc(&d_velocity_x, mem_size);
    cudaMalloc(&d_velocity_y, mem_size);

    cudaMalloc(&d_external_force_x, mem_size);
    cudaMalloc(&d_external_force_y, mem_size);

    ExecuteThermodynamicGenesis(stream);
}

void ComputationalFluidDynamicsEnvironment::CollideAndStream(cudaStream_t stream) {
    dim3 threads(32, 32);
    dim3 blocks((BiophysicalConstants::ENVIRONMENT_WIDTH + threads.x - 1) / threads.x,
        (BiophysicalConstants::ENVIRONMENT_HEIGHT + threads.y - 1) / threads.y);

    LBM_Collide_Stream_Kernel << <blocks, threads, 0, stream >> > (
        d_f0, d_f1, d_f2, d_f3, d_f4, d_f5, d_f6, d_f7, d_f8,
        d_f0_next, d_f1_next, d_f2_next, d_f3_next, d_f4_next, d_f5_next, d_f6_next, d_f7_next, d_f8_next,
        d_density, d_velocity_x, d_velocity_y, d_external_force_x, d_external_force_y,
        BiophysicalConstants::PLASMA_TAU, BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        thermodynamic_tick, g_active_device_accumulators
        );

    thermodynamic_tick++;

    float* temp_ptr;
    temp_ptr = d_f0; d_f0 = d_f0_next; d_f0_next = temp_ptr;
    temp_ptr = d_f1; d_f1 = d_f1_next; d_f1_next = temp_ptr;
    temp_ptr = d_f2; d_f2 = d_f2_next; d_f2_next = temp_ptr;
    temp_ptr = d_f3; d_f3 = d_f3_next; d_f3_next = temp_ptr;
    temp_ptr = d_f4; d_f4 = d_f4_next; d_f4_next = temp_ptr;
    temp_ptr = d_f5; d_f5 = d_f5_next; d_f5_next = temp_ptr;
    temp_ptr = d_f6; d_f6 = d_f6_next; d_f6_next = temp_ptr;
    temp_ptr = d_f7; d_f7 = d_f7_next; d_f7_next = temp_ptr;
    temp_ptr = d_f8; d_f8 = d_f8_next; d_f8_next = temp_ptr;
}