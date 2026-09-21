// --- START OF FILE Thermodynamic.Neural.Network.cu ---

#include "Thermodynamic.Neural.Network.cuh"
#include "Biochemical.Constants.h" 
#include <curand.h>

__global__ void Activation_Tanh_Batch_Kernel(float* vector, int total_elements) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < total_elements) {
        vector[idx] = tanhf(vector[idx]);
    }
}

// Phase 93: Homeostatic Synaptic Downscaling & Spontaneous Vesicle Release
__global__ void Entropy_Decay_Kernel(float* weights, int size, float raw_decay_factor, unsigned long long sys_tick) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < size) {
        // Thermodynamic Clamping: Prevents synaptic obliteration from massive ATP flux
        float clamped_decay = fminf(0.05f, raw_decay_factor);

        uint32_t seed = Network_PCG_Hash(static_cast<uint32_t>(idx * 918273) ^ static_cast<uint32_t>(sys_tick));
        float spontaneous_noise = (Network_Stochastic_Float(seed) - 0.5f) * 0.02f;

        // Homeostatic Baseline (L2 Regularization equivalent):
        // Synapses decay toward a basal exploratory state, not absolute zero
        weights[idx] = weights[idx] * (1.0f - clamped_decay) + (spontaneous_noise * clamped_decay);
    }
}

__global__ void Hebbian_Plasticity_Kernel(float* d_weights, const float* d_sensors, const float* d_motors, const float* d_reward, int input_size, int output_size, int batch_size, unsigned long long sys_tick) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= batch_size) return;

    float raw_reward = d_reward[idx];
    float clamped_reward = fmaxf(-1.0f, fminf(5.0f, raw_reward));
    float learning_rate = 0.001f / static_cast<float>(batch_size);
    float max_weight = 10.0f;

    for (int m = 0; m < output_size; ++m) {
        float motor_activation = d_motors[m * batch_size + idx];

        // Phase 93: mEPSPs (Miniature Excitatory Postsynaptic Potentials)
        // Ensures learning can be reignited even if the network was temporarily silenced
        uint32_t seed = Network_PCG_Hash(static_cast<uint32_t>(idx * 1337 + m) ^ static_cast<uint32_t>(sys_tick));
        float spontaneous_release = (Network_Stochastic_Float(seed) - 0.5f) * 0.01f;

        for (int s = 0; s < input_size; ++s) {
            float sensor_activation = d_sensors[s * batch_size + idx];

            float synaptic_delta = learning_rate * clamped_reward * sensor_activation * (motor_activation + spontaneous_release);

            int w_idx = m * input_size + s;
            float old_w = atomicAdd(&d_weights[w_idx], synaptic_delta);

            d_weights[w_idx] = fmaxf(-max_weight, fminf(max_weight, d_weights[w_idx] * 0.999f));
        }
    }
}

ThermodynamicNeuralNetwork::ThermodynamicNeuralNetwork(int num_sensors, int num_motors)
    : input_size(num_sensors), output_size(num_motors)
{
    cublasCreate(&cublas_handle);
    int total_synapses = input_size * output_size;

    cudaMalloc(&d_weights, total_synapses * sizeof(float));
    cudaMalloc(&d_eligibility_trace, input_size * sizeof(float));

    InitializeSynapses();
}

ThermodynamicNeuralNetwork::~ThermodynamicNeuralNetwork() {
    cudaFree(d_weights);
    cudaFree(d_eligibility_trace);
    cublasDestroy(cublas_handle);
}

void ThermodynamicNeuralNetwork::InitializeSynapses() {
    curandGenerator_t gen;
    curandCreateGenerator(&gen, CURAND_RNG_PSEUDO_DEFAULT);
    curandSetPseudoRandomGeneratorSeed(gen, 1234ULL);
    curandGenerateNormal(gen, d_weights, input_size * output_size, 0.0f, 0.1f);
    curandDestroyGenerator(gen);
}

void ThermodynamicNeuralNetwork::ComputeMotorOutput(const float* d_sensors_batch, float* d_motors_batch, int batch_size, cudaStream_t stream) {
    float alpha = 1.0f;
    float beta = 0.0f;

    cublasSetStream(cublas_handle, stream);

    cublasSgemm(cublas_handle, CUBLAS_OP_N, CUBLAS_OP_N,
        batch_size, output_size, input_size,
        &alpha,
        d_sensors_batch, batch_size,
        d_weights, input_size,
        &beta,
        d_motors_batch, batch_size);

    int total_elements = output_size * batch_size;
    int threads = 256;
    int blocks = (total_elements + threads - 1) / threads;

    Activation_Tanh_Batch_Kernel << <blocks, threads, 0, stream >> > (d_motors_batch, total_elements);
}

void ThermodynamicNeuralNetwork::EntropyDecay(float base_energy_expended, unsigned long long sys_tick, cudaStream_t stream) {
    int total_synapses = input_size * output_size;
    int threads = 256;
    int blocks = (total_synapses + threads - 1) / threads;

    float decay_factor = base_energy_expended * BiophysicalConstants::ATP_DECAY_ENTROPY;
    Entropy_Decay_Kernel << <blocks, threads, 0, stream >> > (d_weights, total_synapses, decay_factor, sys_tick);
}

void ThermodynamicNeuralNetwork::PhosphorylateSynapses(const float* d_sensors_batch, const float* d_motors_batch, const float* d_reward_signal, int batch_size, unsigned long long sys_tick, cudaStream_t stream) {
    int threads = 256;
    int blocks = (batch_size + threads - 1) / threads;

    Hebbian_Plasticity_Kernel << <blocks, threads, 0, stream >> > (d_weights, d_sensors_batch, d_motors_batch, d_reward_signal, input_size, output_size, batch_size, sys_tick);
}
// --- END OF FILE Thermodynamic.Neural.Network.cu ---