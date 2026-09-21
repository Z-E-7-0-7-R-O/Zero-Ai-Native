// --- START OF FILE Autonomous.Senolytic.Population.cu ---

#include "Autonomous.Senolytic.Population.cuh"
#include "Biochemical.Constants.h"
#include <iostream>
#include <iomanip>

__device__ float* d_global_agent_density_reference = nullptr;

__global__ void Bind_Agent_Density_Reference(float* target_grid) {
    d_global_agent_density_reference = target_grid;
}

// Phase 93: CD47-SIRPA Axis Calibration & True Digestion Volumetrics
// Phase 96: In-Situ Turnover - Edge respawn completely replaced with uniform continuous stochastic distribution
__global__ void Tissue_Secretion_Kernel(
    int size, const float* p_x_curr, const float* p_y_curr, const float* integrity_curr,
    float* p_x_next, float* p_y_next, float* integrity_next,
    float* sasp_grid, float* atp_grid,
    const float* d_senophage_density_curr, const float* d_scavenger_density_curr,
    int width, int height, int splat_radius, float sigma_sq, unsigned long long sys_tick,
    const float* cd47_protein_level_curr,
    const float* senophage_sirpa_tensor, const float* scavenger_sirpa_tensor,
    BiophysicalAccumulators* acc) {

    int agent_idx = blockIdx.x;
    if (agent_idx >= size) return;

    __shared__ float current_x;
    __shared__ float current_y;
    __shared__ float new_integrity;
    __shared__ float continuous_secretion;
    __shared__ float atp_secretion_base;

    float f_w = static_cast<float>(width);
    float f_h = static_cast<float>(height);

    if (threadIdx.x == 0) {
        current_x = p_x_curr[agent_idx];
        current_y = p_y_curr[agent_idx];

        float current_integrity = integrity_next[agent_idx];
        float is_already_dead = 1.0f - Mathematical_Smoothstep(0.0f, 1e-5f, current_integrity);

        int base_cx = static_cast<int>(floorf(current_x));
        int base_cy = static_cast<int>(floorf(current_y));
        int grid_x = (base_cx % width + width) % width;
        int grid_y = (base_cy % height + height) % height;

        float senophage_pressure = 0.0f;
        float scavenger_pressure_raw = 0.0f;

        for (int dy = -1; dy <= 1; ++dy) {
            for (int dx = -1; dx <= 1; ++dx) {
                int read_x = (grid_x + dx + width) % width;
                int read_y = (grid_y + dy + height) % height;
                int read_idx = read_y * width + read_x;
                senophage_pressure += d_senophage_density_curr[read_idx];
                scavenger_pressure_raw += d_scavenger_density_curr[read_idx];
            }
        }

        senophage_pressure /= 9.0f;
        scavenger_pressure_raw /= 9.0f;

        float ps_exposure = 1.0f - Mathematical_Smoothstep(0.0f, 0.3f, current_integrity);
        float base_cd47_shield = current_integrity * cd47_protein_level_curr[agent_idx];

        float local_senophage_sirpa = senophage_sirpa_tensor[agent_idx % 150];
        float local_scavenger_sirpa = scavenger_sirpa_tensor[agent_idx % 30];

        float cd47_inhibition_on_senophage = base_cd47_shield * local_senophage_sirpa;
        float cd47_inhibition_on_scavenger = base_cd47_shield * local_scavenger_sirpa;

        float senophage_inhibition_scalar = 1.0f - Mathematical_Smoothstep(0.0f, 1.0f, cd47_inhibition_on_senophage);
        float scavenger_inhibition_scalar = 1.0f - Mathematical_Smoothstep(0.0f, 1.0f, cd47_inhibition_on_scavenger);

        float scavenger_pressure = fmaxf(0.0f, scavenger_pressure_raw * scavenger_inhibition_scalar);

        float senophage_cooperation = 1.0f + Mathematical_Smoothstep(BiophysicalConstants::COOPERATIVE_SWARM_BASE_DENSITY, BiophysicalConstants::COOPERATIVE_SWARM_PEAK_DENSITY, senophage_pressure) * BiophysicalConstants::COOPERATIVE_SYNERGY_MULTIPLIER;
        float scavenger_cooperation = 1.0f + Mathematical_Smoothstep(BiophysicalConstants::COOPERATIVE_SWARM_BASE_DENSITY, BiophysicalConstants::COOPERATIVE_SWARM_PEAK_DENSITY, scavenger_pressure) * BiophysicalConstants::COOPERATIVE_SYNERGY_MULTIPLIER;

        float senophage_digestion = senophage_pressure * BiophysicalConstants::MACROPHAGE_DIGESTION_RATE * senophage_cooperation * senophage_inhibition_scalar;

        float scavenger_macropinocytosis = scavenger_pressure * ps_exposure * 0.05f * scavenger_cooperation;
        float trogocytosis_window = Mathematical_Smoothstep(0.10f, 0.30f, current_integrity) * (1.0f - Mathematical_Smoothstep(0.70f, 0.90f, current_integrity));
        float scavenger_trogocytosis = scavenger_pressure * trogocytosis_window * BiophysicalConstants::SCAVENGER_TROGOCYTOSIS_RATE;

        atomicAdd(&(acc->macropinocytosis_volume), static_cast<double>(senophage_digestion + scavenger_macropinocytosis));
        atomicAdd(&(acc->trogocytosis_volume), static_cast<double>(scavenger_trogocytosis));
        atomicAdd(&(acc->swarm_cooperation_density), static_cast<double>(senophage_pressure * senophage_cooperation));

        float scavenger_digestion = scavenger_macropinocytosis + scavenger_trogocytosis;
        float physical_degradation = (senophage_digestion + scavenger_digestion) * (1.0f - is_already_dead);

        float collapse_vulnerability = 1.0f - Mathematical_Smoothstep(0.10f, BiophysicalConstants::TROGOPTOSIS_ACTIVATION_THRESHOLD, current_integrity);
        float trogoptosis_acceleration = collapse_vulnerability * collapse_vulnerability * BiophysicalConstants::TROGOPTOSIS_COLLAPSE_RATE * (1.0f - is_already_dead);

        new_integrity = current_integrity - physical_degradation - trogoptosis_acceleration;
        float apoptotic_decay = Mathematical_Smoothstep(0.15f, 0.0f, current_integrity) * 0.00005f * (1.0f - is_already_dead);
        new_integrity -= apoptotic_decay;
        new_integrity = fmaxf(0.0f, new_integrity);

        atomicAdd(&(acc->collapse_events), static_cast<double>(trogoptosis_acceleration));

        // Phase 96: In-Situ Bystander Turnover. Uniformly distributing new senescent cells across the entire matrix.
        uint32_t base_seed_x = Generate_PCG_Hash(static_cast<uint32_t>(agent_idx * 777) ^ static_cast<uint32_t>(sys_tick));
        uint32_t base_seed_y = Generate_PCG_Hash(static_cast<uint32_t>(agent_idx * 888) ^ static_cast<uint32_t>(sys_tick));

        float reset_x = Generate_Stochastic_Float(base_seed_x) * f_w;
        float reset_y = Generate_Stochastic_Float(base_seed_y) * f_h;

        float trigger_reset = is_already_dead;

        p_x_next[agent_idx] = p_x_next[agent_idx] * (1.0f - trigger_reset) + reset_x * trigger_reset;
        p_y_next[agent_idx] = p_y_next[agent_idx] * (1.0f - trigger_reset) + reset_y * trigger_reset;
        integrity_next[agent_idx] = new_integrity * (1.0f - trigger_reset) + 1.0f * trigger_reset;

        float sasp_factor = Mathematical_Smoothstep(0.0f, 1.0f, new_integrity);
        continuous_secretion = sasp_factor * 0.025f;

        float damage_factor = 1.0f - new_integrity;
        float damps_burst = damage_factor * damage_factor * damage_factor;
        atp_secretion_base = damps_burst * 0.15f * 2.85f;
    }
    __syncthreads();

    float structural_footprint = BiophysicalConstants::STRUCTURAL_FOOTPRINT_MIN +
        (1.0f - BiophysicalConstants::STRUCTURAL_FOOTPRINT_MIN) * Mathematical_Smoothstep(0.05f, 0.40f, new_integrity);
    float effective_sigma_sq = sigma_sq * structural_footprint;

    int side = 2 * splat_radius + 1;
    int total_voxels = side * side;

    for (int i = threadIdx.x; i < total_voxels; i += blockDim.x) {
        int dy = i / side - splat_radius;
        int dx = i % side - splat_radius;

        float g_x = floorf(current_x) + static_cast<float>(dx);
        float g_y = floorf(current_y) + static_cast<float>(dy);
        float voxel_center_x = g_x + 0.5f;
        float voxel_center_y = g_y + 0.5f;

        float raw_dx = fabsf(current_x - voxel_center_x);
        float raw_dy = fabsf(current_y - voxel_center_y);
        float tor_dx = fminf(raw_dx, f_w - raw_dx);
        float tor_dy = fminf(raw_dy, f_h - raw_dy);
        float dist_sq = tor_dx * tor_dx + tor_dy * tor_dy;

        float spatial_weight = expf(-dist_sq / (2.0f * effective_sigma_sq));
        float val_sasp = continuous_secretion * spatial_weight;
        float val_atp = atp_secretion_base * spatial_weight;

        int base_wrap_x = static_cast<int>(floorf(g_x));
        int base_wrap_y = static_cast<int>(floorf(g_y));
        int wrap_x = (base_wrap_x % static_cast<int>(width) + static_cast<int>(width)) % static_cast<int>(width);
        int wrap_y = (base_wrap_y % static_cast<int>(height) + static_cast<int>(height)) % static_cast<int>(height);
        int local_grid_idx = wrap_y * static_cast<int>(width) + wrap_x;

        atomicAdd(&sasp_grid[local_grid_idx], val_sasp);
        atomicAdd(&atp_grid[local_grid_idx], val_atp);
    }
}

__global__ void Senescent_Tissue_Kinematics_Kernel(
    int size, const float* p_x_curr, const float* p_y_curr,
    float* p_x_next, float* p_y_next,
    const float* agent_density_curr,
    float width, float height, unsigned long long sys_tick)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= size) return;
    float current_x = p_x_curr[idx];
    float current_y = p_y_curr[idx];
    int i_w = static_cast<int>(width);
    int i_h = static_cast<int>(height);
    int base_cx = static_cast<int>(floorf(current_x));
    int base_cy = static_cast<int>(floorf(current_y));
    int cx = (base_cx % i_w + i_w) % i_w;
    int cy = (base_cy % i_h + i_h) % i_h;
    int center_idx = cy * i_w + cx;
    int n_idx = ((cy - 1 + i_h) % i_h) * i_w + cx;
    int s_idx = ((cy + 1) % i_h) * i_w + cx;
    int e_idx = cy * i_w + ((cx + 1) % i_w);
    int w_idx = cy * i_w + ((cx - 1 + i_w) % i_w);
    float a_dens_center = agent_density_curr[center_idx];
    float a_dens_n = agent_density_curr[n_idx];
    float a_dens_s = agent_density_curr[s_idx];
    float a_dens_e = agent_density_curr[e_idx];
    float a_dens_w = agent_density_curr[w_idx];
    float gradient_x = a_dens_e - a_dens_w;
    float gradient_y = a_dens_s - a_dens_n;
    float engulfment_pressure = Mathematical_Smoothstep(0.5f, 2.0f, a_dens_center);
    float evasion_multiplier = 1.0f - engulfment_pressure;
    float evasion_vx = -gradient_x * 0.01f * evasion_multiplier;
    float evasion_vy = -gradient_y * 0.01f * evasion_multiplier;
    uint32_t seed = Generate_PCG_Hash(static_cast<uint32_t>(idx * 1337) ^ static_cast<uint32_t>(sys_tick));
    float prw_vx = (Generate_Stochastic_Float(seed) - 0.5f) * 2.0f * BiophysicalConstants::SENESCENT_BASAL_MOTILITY * evasion_multiplier;
    float prw_vy = (Generate_Stochastic_Float(Generate_PCG_Hash(seed + 1)) - 0.5f) * 2.0f * BiophysicalConstants::SENESCENT_BASAL_MOTILITY * evasion_multiplier;
    float total_vx = evasion_vx + prw_vx;
    float total_vy = evasion_vy + prw_vy;
    current_x += total_vx;
    current_y += total_vy;

    current_x = fmodf(fmodf(current_x, width) + width, width);
    current_y = fmodf(fmodf(current_y, height) + height, height);

    p_x_next[idx] = current_x;
    p_y_next[idx] = current_y;
}

__global__ void Read_Olfactory_Sensors_Kernel(
    int size, const float* p_x_curr, const float* p_y_curr,
    float* sensors, const float* desensitization_curr, float* desensitization_next,
    const float* sasp_grid, const float* tissue_density_curr, int width, int height,
    float lateral_inhibition_scalar, const float* sirpa_protein_curr, const float* p2ry2_protein_curr)
{
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx >= size) return;
    int i_w = width;
    int i_h = height;
    int base_cx = static_cast<int>(floorf(p_x_curr[idx]));
    int base_cy = static_cast<int>(floorf(p_y_curr[idx]));
    int cx = (base_cx % i_w + i_w) % i_w;
    int cy = (base_cy % i_h + i_h) % i_h;

    int center_idx = cy * i_w + cx;
    int n_idx = ((cy - 1 + i_h) % i_h) * i_w + cx;
    int s_idx = ((cy + 1) % i_h) * i_w + cx;
    int e_idx = cy * i_w + ((cx + 1) % i_w);
    int w_idx = cy * i_w + ((cx - 1 + i_w) % i_w);
    int ne_idx = ((cy - 1 + i_h) % i_h) * i_w + ((cx + 1) % i_w);
    int nw_idx = ((cy - 1 + i_h) % i_h) * i_w + ((cx - 1 + i_w) % i_w);
    int se_idx = ((cy + 1) % i_h) * i_w + ((cx + 1) % i_w);
    int sw_idx = ((cy + 1) % i_h) * i_w + ((cx - 1 + i_w) % i_w);

    float sasp_n = sasp_grid[n_idx];
    float sasp_s = sasp_grid[s_idx];
    float sasp_e = sasp_grid[e_idx];
    float sasp_w = sasp_grid[w_idx];
    float sasp_ne = sasp_grid[ne_idx];
    float sasp_nw = sasp_grid[nw_idx];
    float sasp_se = sasp_grid[se_idx];
    float sasp_sw = sasp_grid[sw_idx];

    float local_avg_sasp = (sasp_n + sasp_s + sasp_e + sasp_w + sasp_ne + sasp_nw + sasp_se + sasp_sw) * 0.125f;
    float current_fatigue = desensitization_curr[idx];
    float local_senescent_density = tissue_density_curr[center_idx];
    float integrin_anchorage = Mathematical_Smoothstep(0.1f, 1.5f, local_senescent_density);
    float fatigue_influx = Mathematical_Smoothstep(0.0f, 5.0f, local_avg_sasp) * 0.1f * (1.0f - integrin_anchorage);
    float new_fatigue = current_fatigue * 0.98f + fatigue_influx;

    desensitization_next[idx] = new_fatigue;

    float is_scavenger = Mathematical_Smoothstep(0.2f, 0.8f, p2ry2_protein_curr[idx]);
    float ubiquitous_chemokine_receptor = 1.0f;
    float receptor_level = (1.0f - is_scavenger) * ubiquitous_chemokine_receptor + is_scavenger * p2ry2_protein_curr[idx];

    float raw_signal_attenuation = 1.0f / (1.0f + new_fatigue * 10.0f);
    float signal_attenuation = fmaxf(0.05f, raw_signal_attenuation) * receptor_level;

    uint32_t base_seed = Generate_PCG_Hash(static_cast<uint32_t>(idx * 112233) ^ static_cast<uint32_t>(cx * cy));
    float noise_n = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 1));
    float noise_s = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 2));
    float noise_e = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 3));
    float noise_w = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 4));
    float noise_ne = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 5));
    float noise_nw = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 6));
    float noise_se = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 7));
    float noise_sw = 0.8f + 0.4f * Generate_Stochastic_Float(Generate_PCG_Hash(base_seed + 8));

    float raw_s0 = sasp_n * noise_n * signal_attenuation;
    float raw_s1 = sasp_s * noise_s * signal_attenuation;
    float raw_s2 = sasp_e * noise_e * signal_attenuation;
    float raw_s3 = sasp_w * noise_w * signal_attenuation;
    float raw_s4 = sasp_ne * noise_ne * signal_attenuation;
    float raw_s5 = sasp_nw * noise_nw * signal_attenuation;
    float raw_s6 = sasp_se * noise_se * signal_attenuation;
    float raw_s7 = sasp_sw * noise_sw * signal_attenuation;

    float mean_signal = (raw_s0 + raw_s1 + raw_s2 + raw_s3 + raw_s4 + raw_s5 + raw_s6 + raw_s7) * 0.125f;

    float enhanced_s0 = powf(fmaxf(0.0f, raw_s0 - mean_signal * 0.5f), 2.0f);
    float enhanced_s1 = powf(fmaxf(0.0f, raw_s1 - mean_signal * 0.5f), 2.0f);
    float enhanced_s2 = powf(fmaxf(0.0f, raw_s2 - mean_signal * 0.5f), 2.0f);
    float enhanced_s3 = powf(fmaxf(0.0f, raw_s3 - mean_signal * 0.5f), 2.0f);
    float enhanced_s4 = powf(fmaxf(0.0f, raw_s4 - mean_signal * 0.5f), 2.0f);
    float enhanced_s5 = powf(fmaxf(0.0f, raw_s5 - mean_signal * 0.5f), 2.0f);
    float enhanced_s6 = powf(fmaxf(0.0f, raw_s6 - mean_signal * 0.5f), 2.0f);
    float enhanced_s7 = powf(fmaxf(0.0f, raw_s7 - mean_signal * 0.5f), 2.0f);

    sensors[0 * size + idx] = raw_s0 * (1.0f - lateral_inhibition_scalar) + enhanced_s0 * lateral_inhibition_scalar;
    sensors[1 * size + idx] = raw_s1 * (1.0f - lateral_inhibition_scalar) + enhanced_s1 * lateral_inhibition_scalar;
    sensors[2 * size + idx] = raw_s2 * (1.0f - lateral_inhibition_scalar) + enhanced_s2 * lateral_inhibition_scalar;
    sensors[3 * size + idx] = raw_s3 * (1.0f - lateral_inhibition_scalar) + enhanced_s3 * lateral_inhibition_scalar;
    sensors[4 * size + idx] = raw_s4 * (1.0f - lateral_inhibition_scalar) + enhanced_s4 * lateral_inhibition_scalar;
    sensors[5 * size + idx] = raw_s5 * (1.0f - lateral_inhibition_scalar) + enhanced_s5 * lateral_inhibition_scalar;
    sensors[6 * size + idx] = raw_s6 * (1.0f - lateral_inhibition_scalar) + enhanced_s6 * lateral_inhibition_scalar;
    sensors[7 * size + idx] = raw_s7 * (1.0f - lateral_inhibition_scalar) + enhanced_s7 * lateral_inhibition_scalar;
}

__global__ void Autonomous_Agent_Kinematics_Kernel(
    int size, const float* p_x_curr, const float* p_y_curr, const float* v_x_curr, const float* v_y_curr, const float* atp_curr, const float* lipid_curr, float* reward_signal,
    float* p_x_next, float* p_y_next, float* v_x_next, float* v_y_next, float* atp_next, float* lipid_next,
    const float* motors, const float* desensitization_curr, const float* agent_density_curr, float* ext_fx, float* ext_fy,
    const float* tissue_density_curr, const float* sasp_grid, const float* t_px_curr, const float* t_py_curr, const float* t_integrity_curr, const float* t_cd47_curr, int t_count,
    const float* a_px_curr, const float* a_py_curr, int a_count,
    float width, float height, float drag, float entropy, unsigned long long sys_tick,
    float inertia_constant, float basal_actin_thrust, float max_levy_jump,
    float basal_motility_scalar, float quiescence_scalar, float macropinocytosis_scalar, float learning_rate_scalar,
    const float* actb_protein_curr, const float* sirpa_protein_curr, const float* abca1_protein_curr, BiophysicalAccumulators* acc)
{
    int agent_idx = blockIdx.x;
    if (agent_idx >= size) return;

    __shared__ float s_steric_x[256];
    __shared__ float s_steric_y[256];
    __shared__ float s_current_x;
    __shared__ float s_current_y;
    __shared__ float s_directed_motor_x;
    __shared__ float s_directed_motor_y;
    __shared__ float s_available_energy;
    __shared__ float s_next_px;
    __shared__ float s_next_py;

    float f_w = static_cast<float>(width);
    float f_h = static_cast<float>(height);

    if (threadIdx.x == 0) {
        s_current_x = p_x_curr[agent_idx];
        s_current_y = p_y_curr[agent_idx];
    }
    __syncthreads();

    float local_steric_x = 0.0f;
    float local_steric_y = 0.0f;
    float c_x = s_current_x;
    float c_y = s_current_y;

    for (int j = threadIdx.x; j < a_count; j += blockDim.x) {
        float raw_dx = c_x - a_px_curr[j];
        float raw_dy = c_y - a_py_curr[j];

        float abs_dx = fabsf(raw_dx);
        float abs_dy = fabsf(raw_dy);

        float dx = copysignf(fminf(abs_dx, f_w - abs_dx), raw_dx);
        float dy = copysignf(fminf(abs_dy, f_h - abs_dy), raw_dy);

        float dist_sq = dx * dx + dy * dy;
        float is_other = 0.5f + 0.5f * copysignf(1.0f, dist_sq - 1e-4f);

        float safe_dist_sq = dist_sq + 0.05f;
        float inv_dist_sq = 1.0f / safe_dist_sq;
        float rep_mag = fminf(50.0f, 1.5f * inv_dist_sq * inv_dist_sq) * is_other;

        local_steric_x += dx * rep_mag;
        local_steric_y += dy * rep_mag;
    }
    s_steric_x[threadIdx.x] = local_steric_x;
    s_steric_y[threadIdx.x] = local_steric_y;
    __syncthreads();

    for (int offset = blockDim.x / 2; offset > 0; offset >>= 1) {
        if (threadIdx.x < offset) {
            s_steric_x[threadIdx.x] += s_steric_x[threadIdx.x + offset];
            s_steric_y[threadIdx.x] += s_steric_y[threadIdx.x + offset];
        }
        __syncthreads();
    }

    if (threadIdx.x == 0) {
        float current_atp = atp_curr[agent_idx];
        float safe_current_atp = fmaxf(0.0f, current_atp);
        float available_energy = fminf(1.0f, safe_current_atp);
        s_available_energy = available_energy;
        float actin_capacity = Mathematical_Smoothstep(0.0f, 10.0f, safe_current_atp);

        int i_w = static_cast<int>(width);
        int i_h = static_cast<int>(height);

        int base_cx = static_cast<int>(floorf(c_x));
        int base_cy = static_cast<int>(floorf(c_y));
        int cx = (base_cx % i_w + i_w) % i_w;
        int cy = (base_cy % i_h + i_h) % i_h;

        int center_idx = cy * i_w + cx;
        int n_idx = ((cy - 1 + i_h) % i_h) * i_w + cx;
        int s_idx = ((cy + 1) % i_h) * i_w + cx;
        int e_idx = cy * i_w + ((cx + 1) % i_w);
        int w_idx = cy * i_w + ((cx - 1 + i_w) % i_w);

        float nearest_dist_sq = 999999.0f;
        float nearest_integrity = 1.0f;
        float nearest_cd47 = 1.0f;

        for (int i = 0; i < t_count; ++i) {
            float raw_dx = fabsf(c_x - t_px_curr[i]);
            float raw_dy = fabsf(c_y - t_py_curr[i]);
            float dx = fminf(raw_dx, f_w - raw_dx);
            float dy = fminf(raw_dy, f_h - raw_dy);
            float dist_sq = dx * dx + dy * dy;

            float diff = dist_sq - nearest_dist_sq;
            float is_closer = 0.5f - 0.5f * copysignf(1.0f, diff);

            nearest_dist_sq = dist_sq * is_closer + nearest_dist_sq * (1.0f - is_closer);
            nearest_integrity = t_integrity_curr[i] * is_closer + nearest_integrity * (1.0f - is_closer);
            nearest_cd47 = t_cd47_curr[i] * is_closer + nearest_cd47 * (1.0f - is_closer);
        }

        float cd47_sirpa_inhibition = nearest_cd47 * sirpa_protein_curr[agent_idx];
        float local_target_ps_exposure = 1.0f - Mathematical_Smoothstep(0.0f, 0.3f, nearest_integrity);
        float local_senescent_density = tissue_density_curr[center_idx];

        float integrin_anchorage = Mathematical_Smoothstep(0.1f, 1.5f, local_senescent_density);
        float commitment_lock = Mathematical_Smoothstep(0.2f, 1.5f, local_senescent_density) * (1.0f - macropinocytosis_scalar);

        float baseline_affinity = (integrin_anchorage * (1.0f - macropinocytosis_scalar) + (integrin_anchorage * local_target_ps_exposure) * macropinocytosis_scalar) * actin_capacity;
        float effective_affinity = baseline_affinity * (1.0f - Mathematical_Smoothstep(0.0f, 1.0f, cd47_sirpa_inhibition)) + (1.0f - baseline_affinity) * commitment_lock;

        float t_dens_n = tissue_density_curr[n_idx];
        float t_dens_s = tissue_density_curr[s_idx];
        float t_dens_e = tissue_density_curr[e_idx];
        float t_dens_w = tissue_density_curr[w_idx];

        float dens_center = agent_density_curr[center_idx];
        float dens_n = agent_density_curr[n_idx];
        float dens_s = agent_density_curr[s_idx];
        float dens_e = agent_density_curr[e_idx];
        float dens_w = agent_density_curr[w_idx];

        float base_repulsion_x = (dens_w - dens_e) * 0.05f;
        float base_repulsion_y = (dens_n - dens_s) * 0.05f;

        float repulsion_suppression = powf(1.0f - effective_affinity, 4.0f);
        float repulsion_x = base_repulsion_x * repulsion_suppression;
        float repulsion_y = base_repulsion_y * repulsion_suppression;

        atomicAdd(&(acc->cil_suppression_index), static_cast<double>(1.0f - repulsion_suppression));

        float nn_f_x = motors[0 * size + agent_idx];
        float nn_f_y = motors[1 * size + agent_idx];

        float motor_magnitude_sq = (nn_f_x * nn_f_x) + (nn_f_y * nn_f_y);
        float neural_activation = fminf(1.0f, sqrtf(fmaxf(0.0f, motor_magnitude_sq)));

        uint32_t flight_duration = 50 + (Generate_PCG_Hash(agent_idx * 73821) % 350);
        uint32_t levy_phase = static_cast<uint32_t>(sys_tick / flight_duration);
        uint32_t levy_seed_u = Generate_PCG_Hash(static_cast<uint32_t>(agent_idx * 19283) ^ levy_phase);
        uint32_t levy_seed_v = Generate_PCG_Hash(levy_seed_u);
        float rand_u = Generate_Stochastic_Float(levy_seed_u);
        float rand_v = Generate_Stochastic_Float(levy_seed_v);
        float levy_angle = rand_u * 6.2831853f;
        float heavy_tail_step = powf(rand_v + 0.01f, -0.66f) * 0.5f;
        float clamped_levy = fminf(heavy_tail_step, max_levy_jump);

        float tumble_x = cosf(levy_angle) * clamped_levy;
        float tumble_y = sinf(levy_angle) * clamped_levy;

        float actin_thrust_mag = basal_actin_thrust * actb_protein_curr[agent_idx] * Mathematical_Smoothstep(0.0f, 0.2f, available_energy);
        float fatigue = desensitization_curr[agent_idx];
        float exploration_weight = (1.0f - Mathematical_Smoothstep(0.0f, 0.5f, fatigue)) * (1.0f - effective_affinity);

        atomicAdd(&(acc->levy_walk_magnitude), static_cast<double>(clamped_levy * exploration_weight));

        uint32_t thermodynamic_clock = __float_as_uint(safe_current_atp);
        uint32_t phase_seed = Generate_PCG_Hash(static_cast<uint32_t>(agent_idx * 84729) ^ thermodynamic_clock);
        float phase_probability = Generate_Stochastic_Float(phase_seed);
        float run_state_multiplier = Mathematical_Smoothstep(0.3f, 0.4f, phase_probability);

        float actin_gradient_x = (t_dens_e - t_dens_w) * 0.5f;
        float actin_gradient_y = (t_dens_s - t_dens_n) * 0.5f;
        float engulfment_force_x = actin_gradient_x * effective_affinity * 15.0f;
        float engulfment_force_y = actin_gradient_y * effective_affinity * 15.0f;

        float contact_inhibition_locomotion_factor = Mathematical_Smoothstep(2.0f, 6.0f, dens_center);
        float effective_cil_factor = contact_inhibition_locomotion_factor * (1.0f - effective_affinity);
        float chemotaxis_polarity = 1.0f - (2.0f * effective_cil_factor);

        uint32_t ssb_seed = Generate_PCG_Hash(static_cast<uint32_t>(agent_idx * 192837) ^ static_cast<uint32_t>(sys_tick));
        float ssb_noise_x = (Generate_Stochastic_Float(ssb_seed) - 0.5f) * 0.1f;
        float ssb_noise_y = (Generate_Stochastic_Float(Generate_PCG_Hash(ssb_seed)) - 0.5f) * 0.1f;

        float raw_polarity_x = (nn_f_x * run_state_multiplier * chemotaxis_polarity) + (tumble_x * exploration_weight) + ssb_noise_x;
        float raw_polarity_y = (nn_f_y * run_state_multiplier * chemotaxis_polarity) + (tumble_y * exploration_weight) + ssb_noise_y;

        float polarity_mag = sqrtf(fmaxf(0.0f, raw_polarity_x * raw_polarity_x + raw_polarity_y * raw_polarity_y + 1e-5f));
        float polarity_x = raw_polarity_x / polarity_mag;
        float polarity_y = raw_polarity_y / polarity_mag;

        float local_signal_gradient = sasp_grid[center_idx];
        float neural_arousal = Mathematical_Smoothstep(0.0f, 0.5f, local_signal_gradient);

        float hovering_state = integrin_anchorage * (1.0f - local_target_ps_exposure) * macropinocytosis_scalar;
        float active_kinematic_gate = quiescence_scalar + (1.0f - quiescence_scalar) * neural_arousal * (1.0f - hovering_state);

        float directed_motor_x = nn_f_x * (1.0f - exploration_weight) * run_state_multiplier * chemotaxis_polarity * actin_capacity * active_kinematic_gate;
        float directed_motor_y = nn_f_y * (1.0f - exploration_weight) * run_state_multiplier * chemotaxis_polarity * actin_capacity * active_kinematic_gate;

        s_directed_motor_x = directed_motor_x;
        s_directed_motor_y = directed_motor_y;

        float active_exploration_x = tumble_x * exploration_weight * available_energy * actin_capacity * active_kinematic_gate;
        float active_exploration_y = tumble_y * exploration_weight * available_energy * actin_capacity * active_kinematic_gate;

        float applied_actin_x = polarity_x * actin_thrust_mag * actin_capacity;
        float applied_actin_y = polarity_y * actin_thrust_mag * actin_capacity;

        float kinematic_target_x = (directed_motor_x * available_energy) + active_exploration_x + repulsion_x + s_steric_x[0] + (engulfment_force_x * actin_capacity) + applied_actin_x;
        float kinematic_target_y = (directed_motor_y * available_energy) + active_exploration_y + repulsion_y + s_steric_y[0] + (engulfment_force_y * actin_capacity) + applied_actin_y;

        float dynamic_burn_rate = quiescence_scalar + (1.0f - quiescence_scalar) * neural_arousal * (1.0f - hovering_state);

        float target_f_x = kinematic_target_x * basal_motility_scalar;
        float target_f_y = kinematic_target_y * basal_motility_scalar;

        float f_x = v_x_curr[agent_idx] * inertia_constant + target_f_x * (1.0f - inertia_constant);
        float f_y = v_y_curr[agent_idx] * inertia_constant + target_f_y * (1.0f - inertia_constant);

        float local_drag = drag * (1.0f - (effective_affinity * 0.95f));
        float next_vx = f_x * local_drag;
        float next_vy = f_y * local_drag;

        float vel_mag = sqrtf(fmaxf(0.0f, next_vx * next_vx + next_vy * next_vy));
        atomicAdd(&(acc->velocity_magnitude), static_cast<double>(vel_mag));

        float next_px = c_x + next_vx;
        float next_py = c_y + next_vy;

        next_px = fmodf(fmodf(next_px, width) + width, width);
        next_py = fmodf(fmodf(next_py, height) + height, height);

        s_next_px = next_px;
        s_next_py = next_py;

        float efferocytosis_efficiency = Mathematical_Smoothstep(0.2f, 0.6f, effective_affinity) * Mathematical_Smoothstep(0.05f, 0.2f, local_senescent_density);

        float digestion_lipid_yield = effective_affinity * local_senescent_density * 2.5f * efferocytosis_efficiency * (1.0f - Mathematical_Smoothstep(0.0f, 1.0f, cd47_sirpa_inhibition)) * (1.0f - macropinocytosis_scalar);
        float macropinocytosis_influx = effective_affinity * BiophysicalConstants::MACROPINOCYTOSIS_LIPID_YIELD * macropinocytosis_scalar;
        float trogocytosis_window = Mathematical_Smoothstep(0.10f, 0.30f, nearest_integrity) * (1.0f - Mathematical_Smoothstep(0.70f, 0.90f, nearest_integrity));
        float trogocytosis_lipid_yield = effective_affinity * trogocytosis_window * 15.0f * macropinocytosis_scalar;

        float lipid_influx = digestion_lipid_yield + macropinocytosis_influx + trogocytosis_lipid_yield;

        float current_lipid = lipid_curr[agent_idx];

        float abca1_vmax = BiophysicalConstants::ABCA1_CHOLESTEROL_EFFLUX_RATE * abca1_protein_curr[agent_idx];
        float abca1_km = 50.0f;
        float abca1_efflux = (abca1_vmax * current_lipid) / (abca1_km + current_lipid + 1e-6f);
        float abca1_atp_cost = abca1_efflux * BiophysicalConstants::ABCA1_ATP_COST;

        float max_er_stress_penalty = 15.0f;
        float er_km = BiophysicalConstants::LIPID_TOXICITY_THRESHOLD;
        float lipid_sq = current_lipid * current_lipid;
        float lipid_hill = lipid_sq * lipid_sq;
        float er_km_hill = er_km * er_km * er_km * er_km;
        float er_stress_penalty = (max_er_stress_penalty * lipid_hill) / (er_km_hill + lipid_hill + 1e-6f);

        float fao_vmax = BiophysicalConstants::MITOCHONDRIAL_FAO_RATE;
        float fao_km = 20.0f;
        float lipid_oxidation = (fao_vmax * current_lipid) / (fao_km + current_lipid + 1e-6f);
        float atp_from_fao = lipid_oxidation * BiophysicalConstants::MITOCHONDRIAL_FAO_ATP_YIELD;

        float delta_lipid = lipid_influx - abca1_efflux - lipid_oxidation;

        float endogenous_atp_regen = 0.05f * Mathematical_Smoothstep(0.0f, 0.5f, 1.0f - available_energy);
        float kinematic_expenditure = (f_x * f_x + f_y * f_y) * 0.015f * dynamic_burn_rate;

        float basal_metabolism = entropy * (1.0f + logf(1.0f + available_energy)) * dynamic_burn_rate;

        float cup_formation_effort = effective_affinity * (1.0f - effective_affinity) * 4.0f;
        float phagocytic_cup_cost = local_senescent_density * (BiophysicalConstants::PHAGOCYTIC_CUP_MAINTENANCE_TAX * effective_affinity + BiophysicalConstants::PHAGOCYTIC_CUP_BASE_ATP_TAX * cup_formation_effort) * dynamic_burn_rate;

        float expenditure = kinematic_expenditure + basal_metabolism + abca1_atp_cost + er_stress_penalty + phagocytic_cup_cost;

        float autophagy_vmax = expenditure * 0.8f;
        float autophagy_km = BiophysicalConstants::AUTOPHAGY_RESERVE_THRESHOLD;
        float autophagy_yield = (autophagy_vmax * autophagy_km) / (autophagy_km + safe_current_atp + 1e-6f);

        float delta_atp = -expenditure + atp_from_fao + endogenous_atp_regen + autophagy_yield;

        atomicAdd(&(acc->fao_atp_yield), static_cast<double>(atp_from_fao));
        atomicAdd(&(acc->hovering_count), static_cast<double>(hovering_state));
        atomicAdd(&(acc->autophagy_yield), static_cast<double>(autophagy_yield));

        float is_dead_mask = 1.0f - Mathematical_Smoothstep(0.0f, 0.1f, safe_current_atp);

        float lipo_death = is_dead_mask * Mathematical_Smoothstep(450.0f, 500.0f, current_lipid);
        float starve_death = is_dead_mask * (1.0f - Mathematical_Smoothstep(450.0f, 500.0f, current_lipid));
        atomicAdd(&(acc->death_by_lipotoxicity), static_cast<double>(lipo_death));
        atomicAdd(&(acc->death_by_starvation), static_cast<double>(starve_death));
        atomicAdd(&(acc->death_count), static_cast<double>(is_dead_mask));

        float recruit_prob = Mathematical_Smoothstep(2.0f, 15.0f, local_signal_gradient) * 0.05f;
        uint32_t rec_seed = Generate_PCG_Hash(static_cast<uint32_t>(sys_tick ^ agent_idx));
        float rand_val = Generate_Stochastic_Float(rec_seed);

        float spawn_chance = 0.5f + 0.5f * copysignf(1.0f, recruit_prob - rand_val);
        float rebirth_mask = is_dead_mask * spawn_chance;

        p_x_next[agent_idx] = next_px * (1.0f - rebirth_mask) + (Generate_Stochastic_Float(Generate_PCG_Hash(rec_seed + 1)) * width) * rebirth_mask;
        p_y_next[agent_idx] = next_py * (1.0f - rebirth_mask) + (0.0f) * rebirth_mask;
        v_x_next[agent_idx] = next_vx * (1.0f - rebirth_mask);
        v_y_next[agent_idx] = next_vy * (1.0f - rebirth_mask);

        float dummy_old_atp = atomicAdd(&atp_next[agent_idx], delta_atp);
        float dummy_old_lip = atomicAdd(&lipid_next[agent_idx], delta_lipid);

        if (rebirth_mask > 0.5f) {
            atp_next[agent_idx] = 100.0f;
            lipid_next[agent_idx] = 0.0f;
        }

        atomicAdd(&(acc->recruitment_count), static_cast<double>(rebirth_mask));

        reward_signal[agent_idx] = (atp_from_fao - expenditure) * learning_rate_scalar;
    }
    __syncthreads();

    float fluid_injection_x = (s_directed_motor_x * s_available_energy) * 0.13f;
    float fluid_injection_y = (s_directed_motor_y * s_available_energy) * 0.13f;

    for (int i = threadIdx.x; i < 25; i += blockDim.x) {
        int dy = i / 5 - 2;
        int dx = i % 5 - 2;

        float g_x = floorf(s_next_px) + static_cast<float>(dx);
        float g_y = floorf(s_next_py) + static_cast<float>(dy);
        float voxel_center_x = g_x + 0.5f;
        float voxel_center_y = g_y + 0.5f;

        float raw_dx_dist = fabsf(s_next_px - voxel_center_x);
        float raw_dy_dist = fabsf(s_next_py - voxel_center_y);
        float dist_x = fminf(raw_dx_dist, f_w - raw_dx_dist);
        float dist_y = fminf(raw_dy_dist, f_h - raw_dy_dist);

        float mask_x = 0.5f + 0.5f * copysignf(1.0f, 2.0f - dist_x);
        float mask_y = 0.5f + 0.5f * copysignf(1.0f, 2.0f - dist_y);

        float phi_x = 0.25f * (1.0f + cosf(1.57079632679f * dist_x)) * mask_x;
        float phi_y = 0.25f * (1.0f + cosf(1.57079632679f * dist_y)) * mask_y;
        float peskin_weight = phi_x * phi_y;

        int base_wrap_x = static_cast<int>(floorf(g_x));
        int base_wrap_y = static_cast<int>(floorf(g_y));
        int wrap_x = (base_wrap_x % static_cast<int>(width) + static_cast<int>(width)) % static_cast<int>(width);
        int wrap_y = (base_wrap_y % static_cast<int>(height) + static_cast<int>(height)) % static_cast<int>(height);
        int local_grid_idx = wrap_y * static_cast<int>(width) + wrap_x;

        float val_fx = fluid_injection_x * peskin_weight;
        float val_fy = fluid_injection_y * peskin_weight;

        atomicAdd(&ext_fx[local_grid_idx], val_fx);
        atomicAdd(&ext_fy[local_grid_idx], val_fy);
    }
}

SenescentCellPopulation::SenescentCellPopulation(int size, uint32_t temporal_seed) : population_size(size), global_genomic_offset(0) {
    size_t mem = size * sizeof(float);
    cudaMalloc(&d_pos_x_current, mem);
    cudaMalloc(&d_pos_y_current, mem);
    cudaMalloc(&d_membrane_integrity_current, mem);

    cudaMalloc(&d_pos_x_next, mem);
    cudaMalloc(&d_pos_y_next, mem);
    cudaMalloc(&d_membrane_integrity_next, mem);

    size_t grid_mem = BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * sizeof(float);
    cudaMalloc(&d_tissue_density_grid_current, grid_mem);
    cudaMalloc(&d_tissue_density_grid_next, grid_mem);

    float* h_px = new float[size];
    float* h_py = new float[size];
    float* h_mem = new float[size];

    for (int i = 0; i < size; i++) {
        uint32_t seed_x = Generate_PCG_Hash(static_cast<uint32_t>(i + 54321) ^ temporal_seed);
        uint32_t seed_y = Generate_PCG_Hash(static_cast<uint32_t>(i + 98765) ^ temporal_seed);

        h_px[i] = Generate_Stochastic_Float(seed_x) * static_cast<float>(BiophysicalConstants::ENVIRONMENT_WIDTH);
        h_py[i] = Generate_Stochastic_Float(seed_y) * static_cast<float>(BiophysicalConstants::ENVIRONMENT_HEIGHT);
        h_mem[i] = 1.0f;
    }

    cudaMemcpy(d_pos_x_current, h_px, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_pos_y_current, h_py, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_membrane_integrity_current, h_mem, mem, cudaMemcpyHostToDevice);

    cudaMemcpy(d_pos_x_next, h_px, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_pos_y_next, h_py, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_membrane_integrity_next, h_mem, mem, cudaMemcpyHostToDevice);

    delete[] h_px; delete[] h_py; delete[] h_mem;
}

SenescentCellPopulation::~SenescentCellPopulation() {
    cudaFree(d_pos_x_current); cudaFree(d_pos_y_current); cudaFree(d_membrane_integrity_current);
    cudaFree(d_pos_x_next); cudaFree(d_pos_y_next); cudaFree(d_membrane_integrity_next);
    cudaFree(d_tissue_density_grid_current); cudaFree(d_tissue_density_grid_next);
}

void SenescentCellPopulation::AssignGlobalGenomicOffset(int offset) {
    global_genomic_offset = offset;
}

void SenescentCellPopulation::SwapStates() {
    std::swap(d_pos_x_current, d_pos_x_next);
    std::swap(d_pos_y_current, d_pos_y_next);
    std::swap(d_membrane_integrity_current, d_membrane_integrity_next);
    std::swap(d_tissue_density_grid_current, d_tissue_density_grid_next);

    size_t mem = population_size * sizeof(float);
    cudaMemcpy(d_membrane_integrity_next, d_membrane_integrity_current, mem, cudaMemcpyDeviceToDevice);
}

void SenescentCellPopulation::ProjectTissueDensity(cudaStream_t stream) {
    cudaMemsetAsync(d_tissue_density_grid_current, 0, BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * sizeof(float), stream);

    ExecuteSpatialDensityProjection(
        population_size, d_pos_x_current, d_pos_y_current, d_membrane_integrity_current, d_tissue_density_grid_current,
        BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        BiophysicalConstants::SENESCENT_SPLAT_RADIUS, BiophysicalConstants::SENESCENT_GAUSSIAN_SIGMA_SQ, stream
    );
}

void SenescentCellPopulation::ExecuteMotilityPhase(const float* d_agent_density_curr, unsigned long long sys_tick, cudaStream_t stream) {
    int threads = 256;
    int blocks = (population_size + threads - 1) / threads;
    Senescent_Tissue_Kinematics_Kernel << <blocks, threads, 0, stream >> > (
        population_size, d_pos_x_current, d_pos_y_current,
        d_pos_x_next, d_pos_y_next,
        d_agent_density_curr,
        static_cast<float>(BiophysicalConstants::ENVIRONMENT_WIDTH),
        static_cast<float>(BiophysicalConstants::ENVIRONMENT_HEIGHT),
        sys_tick
        );
}

void SenescentCellPopulation::ExecuteSecretionPhase(float* d_sasp_grid, float* d_atp_grid, const float* d_senophage_density_curr, const float* d_scavenger_density_curr, unsigned long long sys_tick, const float* cd47_protein_level_curr, const float* senophage_sirpa_curr, const float* scavenger_sirpa_curr, cudaStream_t stream) {
    BiophysicalAccumulators* acc = g_active_device_accumulators;

    int blocks = population_size;
    int threads = BiophysicalConstants::BLOCK_PER_AGENT_THREADS;

    Tissue_Secretion_Kernel << <blocks, threads, 0, stream >> > (
        population_size, d_pos_x_current, d_pos_y_current, d_membrane_integrity_current,
        d_pos_x_next, d_pos_y_next, d_membrane_integrity_next,
        d_sasp_grid, d_atp_grid,
        d_senophage_density_curr, d_scavenger_density_curr,
        BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        BiophysicalConstants::SENESCENT_SPLAT_RADIUS, BiophysicalConstants::SENESCENT_GAUSSIAN_SIGMA_SQ, sys_tick,
        cd47_protein_level_curr,
        senophage_sirpa_curr, scavenger_sirpa_curr,
        acc
        );
}

AutonomousSenolyticAgentPopulation::AutonomousSenolyticAgentPopulation(int size, uint32_t temporal_seed) : population_size(size), global_genomic_offset(0) {
    size_t mem = size * sizeof(float);
    cudaMalloc(&d_pos_x_current, mem); cudaMalloc(&d_pos_x_next, mem);
    cudaMalloc(&d_pos_y_current, mem); cudaMalloc(&d_pos_y_next, mem);
    cudaMalloc(&d_vel_x_current, mem); cudaMalloc(&d_vel_x_next, mem);
    cudaMalloc(&d_vel_y_current, mem); cudaMalloc(&d_vel_y_next, mem);
    cudaMalloc(&d_atp_level_current, mem); cudaMalloc(&d_atp_level_next, mem);
    cudaMalloc(&d_lipid_burden_current, mem); cudaMalloc(&d_lipid_burden_next, mem);
    cudaMalloc(&d_olfactory_desensitization_current, mem); cudaMalloc(&d_olfactory_desensitization_next, mem);

    cudaMemset(d_vel_x_current, 0, mem); cudaMemset(d_vel_x_next, 0, mem);
    cudaMemset(d_vel_y_current, 0, mem); cudaMemset(d_vel_y_next, 0, mem);
    cudaMemset(d_lipid_burden_current, 0, mem); cudaMemset(d_lipid_burden_next, 0, mem);
    cudaMemset(d_olfactory_desensitization_current, 0, mem); cudaMemset(d_olfactory_desensitization_next, 0, mem);

    cudaMalloc(&d_sensors_batch, 8 * size * sizeof(float));
    cudaMemset(d_sensors_batch, 0, 8 * size * sizeof(float));
    cudaMalloc(&d_motors_batch, 2 * size * sizeof(float));
    cudaMemset(d_motors_batch, 0, 2 * size * sizeof(float));
    cudaMalloc(&d_reward_signal, mem);
    cudaMemset(d_reward_signal, 0, mem);

    size_t grid_mem = BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * sizeof(float);
    cudaMalloc(&d_agent_density_grid_current, grid_mem);
    cudaMalloc(&d_agent_density_grid_next, grid_mem);
    cudaMemset(d_agent_density_grid_current, 0, grid_mem);
    cudaMemset(d_agent_density_grid_next, 0, grid_mem);

    thermodynamic_neural_lattice = new ThermodynamicNeuralNetwork(8, 2);
    Bind_Agent_Density_Reference << <1, 1 >> > (d_agent_density_grid_current);

    float* h_px = new float[size];
    float* h_py = new float[size];
    float* h_atp = new float[size];

    for (int i = 0; i < size; i++) {
        uint32_t seed_x = Generate_PCG_Hash(static_cast<uint32_t>(i + 12345) ^ temporal_seed);
        uint32_t seed_y = Generate_PCG_Hash(static_cast<uint32_t>(i + 67890) ^ temporal_seed);

        h_px[i] = Generate_Stochastic_Float(seed_x) * static_cast<float>(BiophysicalConstants::ENVIRONMENT_WIDTH);
        h_py[i] = Generate_Stochastic_Float(seed_y) * static_cast<float>(BiophysicalConstants::ENVIRONMENT_HEIGHT);
        h_atp[i] = 100.0f;
    }

    cudaMemcpy(d_pos_x_current, h_px, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_pos_y_current, h_py, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_atp_level_current, h_atp, mem, cudaMemcpyHostToDevice);

    cudaMemcpy(d_pos_x_next, h_px, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_pos_y_next, h_py, mem, cudaMemcpyHostToDevice);
    cudaMemcpy(d_atp_level_next, h_atp, mem, cudaMemcpyHostToDevice);

    delete[] h_px; delete[] h_py; delete[] h_atp;
}

AutonomousSenolyticAgentPopulation::~AutonomousSenolyticAgentPopulation() {
    cudaFree(d_pos_x_current); cudaFree(d_pos_x_next);
    cudaFree(d_pos_y_current); cudaFree(d_pos_y_next);
    cudaFree(d_vel_x_current); cudaFree(d_vel_x_next);
    cudaFree(d_vel_y_current); cudaFree(d_vel_y_next);
    cudaFree(d_atp_level_current); cudaFree(d_atp_level_next);
    cudaFree(d_lipid_burden_current); cudaFree(d_lipid_burden_next);
    cudaFree(d_olfactory_desensitization_current); cudaFree(d_olfactory_desensitization_next);
    cudaFree(d_agent_density_grid_current); cudaFree(d_agent_density_grid_next);

    cudaFree(d_sensors_batch); cudaFree(d_motors_batch);
    cudaFree(d_reward_signal);
    delete thermodynamic_neural_lattice;
}

void AutonomousSenolyticAgentPopulation::AssignGlobalGenomicOffset(int offset) {
    global_genomic_offset = offset;
}

void AutonomousSenolyticAgentPopulation::SwapStates() {
    std::swap(d_pos_x_current, d_pos_x_next);
    std::swap(d_pos_y_current, d_pos_y_next);
    std::swap(d_vel_x_current, d_vel_x_next);
    std::swap(d_vel_y_current, d_vel_y_next);
    std::swap(d_atp_level_current, d_atp_level_next);
    std::swap(d_lipid_burden_current, d_lipid_burden_next);
    std::swap(d_olfactory_desensitization_current, d_olfactory_desensitization_next);
    std::swap(d_agent_density_grid_current, d_agent_density_grid_next);

    size_t mem = population_size * sizeof(float);
    cudaMemcpy(d_atp_level_next, d_atp_level_current, mem, cudaMemcpyDeviceToDevice);
    cudaMemcpy(d_lipid_burden_next, d_lipid_burden_current, mem, cudaMemcpyDeviceToDevice);
    cudaMemcpy(d_olfactory_desensitization_next, d_olfactory_desensitization_current, mem, cudaMemcpyDeviceToDevice);
}

void AutonomousSenolyticAgentPopulation::ProjectAgentDensity(cudaStream_t stream) {
    cudaMemsetAsync(d_agent_density_grid_current, 0, BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * sizeof(float), stream);

    ExecuteSpatialDensityProjection(
        population_size, d_pos_x_current, d_pos_y_current, nullptr, d_agent_density_grid_current,
        BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        BiophysicalConstants::MACROPHAGE_SPLAT_RADIUS, BiophysicalConstants::MACROPHAGE_GAUSSIAN_SIGMA_SQ, stream
    );
}

void AutonomousSenolyticAgentPopulation::ExecuteMetabolicPhase(float* d_sasp_grid, float* d_fluid_ext_fx, float* d_fluid_ext_fy,
    const float* d_tissue_density_curr, const float* t_pos_x_curr, const float* t_pos_y_curr, const float* t_integrity_curr, const float* t_cd47_level_curr, int t_count,
    const float* a_px_curr, const float* a_py_curr, int a_count,
    unsigned long long thermodynamic_tick, float basal_motility_scalar, float quiescence_scalar, float macropinocytosis_scalar,
    float learning_rate_scalar, float entropy_decay_scalar, float lateral_inhibition_scalar,
    const float* d_protein_actb_curr, const float* d_protein_cd47_curr, const float* d_protein_sirpa_curr, const float* d_protein_p2ry2_curr, const float* d_protein_abca1_curr,
    cudaStream_t stream) {

    int threads_sensor = 256;
    int blocks_sensor = (population_size + threads_sensor - 1) / threads_sensor;

    Read_Olfactory_Sensors_Kernel << <blocks_sensor, threads_sensor, 0, stream >> > (
        population_size, d_pos_x_current, d_pos_y_current, d_sensors_batch,
        d_olfactory_desensitization_current, d_olfactory_desensitization_next,
        d_sasp_grid, d_tissue_density_curr, BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT,
        lateral_inhibition_scalar, d_protein_sirpa_curr, d_protein_p2ry2_curr
        );

    thermodynamic_neural_lattice->ComputeMotorOutput(d_sensors_batch, d_motors_batch, population_size, stream);

    float f_width = static_cast<float>(BiophysicalConstants::ENVIRONMENT_WIDTH);
    float f_height = static_cast<float>(BiophysicalConstants::ENVIRONMENT_HEIGHT);

    int blocks_kinematics = population_size;
    int threads_kinematics = BiophysicalConstants::BLOCK_PER_AGENT_THREADS;

    Autonomous_Agent_Kinematics_Kernel << <blocks_kinematics, threads_kinematics, 0, stream >> > (
        population_size, d_pos_x_current, d_pos_y_current, d_vel_x_current, d_vel_y_current, d_atp_level_current, d_lipid_burden_current, d_reward_signal,
        d_pos_x_next, d_pos_y_next, d_vel_x_next, d_vel_y_next, d_atp_level_next, d_lipid_burden_next,
        d_motors_batch, d_olfactory_desensitization_current, d_agent_density_grid_current, d_fluid_ext_fx, d_fluid_ext_fy,
        d_tissue_density_curr, d_sasp_grid, t_pos_x_curr, t_pos_y_curr, t_integrity_curr, t_cd47_level_curr, t_count,
        a_px_curr, a_py_curr, a_count,
        f_width, f_height, BiophysicalConstants::KINEMATIC_DRAG, BiophysicalConstants::ATP_DECAY_ENTROPY, thermodynamic_tick,
        BiophysicalConstants::KINEMATIC_INERTIA, BiophysicalConstants::ACTIN_BASAL_THRUST, BiophysicalConstants::MAX_LEVY_JUMP,
        basal_motility_scalar, quiescence_scalar, macropinocytosis_scalar, learning_rate_scalar,
        d_protein_actb_curr, d_protein_sirpa_curr, d_protein_abca1_curr, g_active_device_accumulators
        );

    thermodynamic_neural_lattice->PhosphorylateSynapses(d_sensors_batch, d_motors_batch, d_reward_signal, population_size, thermodynamic_tick, stream);
    thermodynamic_neural_lattice->EntropyDecay(BiophysicalConstants::ATP_DECAY_ENTROPY * entropy_decay_scalar, thermodynamic_tick, stream);
}
// --- END OF FILE Autonomous.Senolytic.Population.cu ---