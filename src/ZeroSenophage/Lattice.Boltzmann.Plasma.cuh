#ifndef LATTICE_BOLTZMANN_PLASMA_CUH
#define LATTICE_BOLTZMANN_PLASMA_CUH

#include <cuda_runtime.h>
#include "Biochemical.Constants.h"

class ComputationalFluidDynamicsEnvironment {
public:
    ComputationalFluidDynamicsEnvironment();
    ~ComputationalFluidDynamicsEnvironment();

    void InitializePlasma(cudaStream_t stream = 0);
    void CollideAndStream(cudaStream_t stream);

    float* d_density;
    float* d_velocity_x;
    float* d_velocity_y;

    float* d_external_force_x;
    float* d_external_force_y;

private:
    float* d_f0; float* d_f1; float* d_f2; float* d_f3; float* d_f4;
    float* d_f5; float* d_f6; float* d_f7; float* d_f8;

    float* d_f0_next; float* d_f1_next; float* d_f2_next; float* d_f3_next;
    float* d_f4_next; float* d_f5_next; float* d_f6_next; float* d_f7_next; float* d_f8_next;

    unsigned long long thermodynamic_tick;

    void ExecuteThermodynamicGenesis(cudaStream_t stream);
};

#endif // LATTICE_BOLTZMANN_PLASMA_CUH