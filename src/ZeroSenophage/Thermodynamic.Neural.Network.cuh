#ifndef THERMODYNAMIC_NEURAL_NETWORK_CUH
#define THERMODYNAMIC_NEURAL_NETWORK_CUH

#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <cstdint>

__host__ __device__ inline uint32_t Network_PCG_Hash(uint32_t input) {
    uint32_t state = input * 747796405u + 2891336453u;
    uint32_t word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

__host__ __device__ inline float Network_Stochastic_Float(uint32_t hash) {
    return (hash & 0x00FFFFFF) / static_cast<float>(0x01000000);
}

class ThermodynamicNeuralNetwork {
public:
    ThermodynamicNeuralNetwork(int num_sensors, int num_motors);
    ~ThermodynamicNeuralNetwork();

    void ComputeMotorOutput(const float* d_sensors_batch, float* d_motors_batch, int batch_size, cudaStream_t stream);

    void EntropyDecay(float base_energy_expended, unsigned long long sys_tick, cudaStream_t stream);

    void PhosphorylateSynapses(const float* d_sensors_batch, const float* d_motors_batch, const float* d_reward_signal, int batch_size, unsigned long long sys_tick, cudaStream_t stream);

private:
    cublasHandle_t cublas_handle;

    int input_size;
    int output_size;

    float* d_weights;
    float* d_eligibility_trace;

    void InitializeSynapses();
};

#endif // THERMODYNAMIC_NEURAL_NETWORK_CUH