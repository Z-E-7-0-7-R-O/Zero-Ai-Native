// --- START OF FILE Shader.Payload.h ---

#ifndef SHADER_PAYLOAD_H
#define SHADER_PAYLOAD_H

// Embedded HLSL Code: True Physical Optics & Phase-Contrast Microscopy
// Phase 74.2: Absolute Sub-Pixel Geometry.
// Phase 87: Eradication of Moiré/Polynomial artifacts via Bitwise Permutation Hashing.
// Phase 88: Toroidal Optical Continuum. Eradication of linear spatial fault inhibitors.
// Phase 89: Optical Truncation Seal applied. Eradication of truncation singularities at zero-boundaries.
static const char MICROSCOPE_LENS_HLSL[] = R"(
cbuffer OpticalConstantBuffer : register(b0) {
    float biological_time;
    float resolution_x;
    float resolution_y;
    float padding_alignment;
};

Texture2D<float4> BiologicalDensityGrid : register(t0);
Texture2D<float4> BiochemicalStateGrid : register(t1);
SamplerState ContinuousSampler : register(s0);

struct VS_OUTPUT {
    float4 Pos : SV_POSITION;
    float2 UV : TEXCOORD0;
};

VS_OUTPUT VS_Main(uint id : SV_VertexID) {
    VS_OUTPUT output;
    output.UV = float2((id << 1) & 2, id & 2);
    output.Pos = float4(output.UV * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    return output;
}

float smax(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return lerp(a, b, h) + k * h * (1.0 - h);
}

float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

float evaluate_phase_contrast_scattering(float structural_gradient, float edge_thickness) {
    // Phase 87: Adjusted exponential falloff (25.0 -> 22.0) to provide natural refractive antialiasing 
    // against the newly sharpened pixel-perfect photon grain, preserving pristine membrane aesthetics.
    return smoothstep(0.0, edge_thickness, structural_gradient) * exp(-structural_gradient * 22.0);
}

float evaluate_beer_lambert_attenuation(float concentration, float molar_absorptivity) {
    return exp(-concentration * molar_absorptivity);
}

// Phase 87: Absolute Spatial Hash Function
// Replaces the unstable continuous polynomial hash with a deterministic bitwise permutation.
// Eradicates all diagonal interference waves and produces mathematically pure white photon noise.
float evaluate_photon_noise(uint2 pixel_coord, float time) {
    uint state = pixel_coord.x * 747796405u + pixel_coord.y * 2891336453u + (uint)(time * 60.0f) * 277803737u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    uint result = (word >> 22u) ^ word;
    return float(result) / 4294967295.0;
}

float4 PS_Main(VS_OUTPUT input) : SV_TARGET {
    int res_x = int(resolution_x);
    int res_y = int(resolution_y);
    
    int2 base_coord = int2(input.Pos.xy);
    float2 base_uv = input.Pos.xy / float2(resolution_x, resolution_y);
    
    int res_x_2 = res_x * 2;
    int res_y_2 = res_y * 2;
    
    int3 coord_center = int3((base_coord.x + res_x_2) % res_x, (base_coord.y + res_y_2) % res_y, 0);
    int3 coord_px = int3((base_coord.x + 1 + res_x_2) % res_x, (base_coord.y + res_y_2) % res_y, 0);
    int3 coord_nx = int3((base_coord.x - 1 + res_x_2) % res_x, (base_coord.y + res_y_2) % res_y, 0);
    int3 coord_py = int3((base_coord.x + res_x_2) % res_x, (base_coord.y + 1 + res_y_2) % res_y, 0);
    int3 coord_ny = int3((base_coord.x + res_x_2) % res_x, (base_coord.y - 1 + res_y_2) % res_y, 0);

    float4 physical_field = BiologicalDensityGrid.Load(coord_center);
    float4 biochem_field = BiochemicalStateGrid.Load(coord_center);
    
    float4 phys_px = BiologicalDensityGrid.Load(coord_px);
    float4 phys_nx = BiologicalDensityGrid.Load(coord_nx);
    float4 phys_py = BiologicalDensityGrid.Load(coord_py);
    float4 phys_ny = BiologicalDensityGrid.Load(coord_ny);
    
    float plasma_rho = 1.0 - exp(-physical_field.r * 1.5);
    float sasp_concentration = saturate(physical_field.g);
    float atp_concentration = saturate(-physical_field.g);
    float prey_density = physical_field.b;
    float agent_density = saturate(physical_field.a);
    float scavenger_density = saturate(-physical_field.a);

    float sdf_prey = 0.5 - prey_density;
    float sdf_agent = 0.5 - agent_density;
    float sdf_scavenger = 0.5 - scavenger_density;

    // Phase 88: Toroidal Optical Continuum 
    // Pure central difference spatial derivatives. Eradication of linear "step" limiters.
    // The underlying field is toroidally continuous, allowing seamless refractive gradients across absolute boundaries.
    float2 grad_prey = float2((phys_px.b - phys_nx.b) * 0.5, (phys_py.b - phys_ny.b) * 0.5);

    float agent_py_sat = saturate(phys_py.a);
    float agent_ny_sat = saturate(phys_ny.a);
    float2 grad_agent = float2((saturate(phys_px.a) - saturate(phys_nx.a)) * 0.5, (agent_py_sat - agent_ny_sat) * 0.5);

    float2 dir_to_prey = normalize(grad_prey + 1e-5);
    float2 dir_from_agent = normalize(-grad_agent + 1e-5);
    float structural_alignment = dot(dir_to_prey, dir_from_agent);

    float cavity_depth = 0.15;
    float k_cavity = 0.2;
    float sdf_agent_cavity = smax(sdf_agent, -(sdf_prey + cavity_depth), k_cavity);
    float pseudopod_extension = smoothstep(0.0, 1.0, structural_alignment) * prey_density * 0.35;
    float sdf_agent_final = sdf_agent_cavity - pseudopod_extension;

    float refined_macrophage_density = saturate(0.5 - sdf_agent_final);
    float refined_senescent_density = saturate(0.5 - sdf_prey);
    float refined_scavenger_density = saturate(0.5 - sdf_scavenger);

    float plasma_rho_px = 1.0 - exp(-phys_px.r * 1.5);
    float plasma_rho_nx = 1.0 - exp(-phys_nx.r * 1.5);
    float plasma_rho_py = 1.0 - exp(-phys_py.r * 1.5);
    float plasma_rho_ny = 1.0 - exp(-phys_ny.r * 1.5);
    
    // Phase 88: Pure unobstructed fluid mechanics gradient mapping.
    float2 grad_plasma_rho = float2((plasma_rho_px - plasma_rho_nx) * 0.5, (plasma_rho_py - plasma_rho_ny) * 0.5);
    
    float density_deviation = abs(plasma_rho - 1.0);
    
    // Phase 89: Optical Truncation Seal applied.
    // Utilizing floor() before cast to ensure continuous mathematical mapping across zero and negative coordinates.
    // Prevents dual-swallowing by the 0-th pixel.
    float2 refracted_uv = base_uv + grad_plasma_rho * 2.0;
    int2 ref_coord = int2(floor(refracted_uv.x * resolution_x), floor(refracted_uv.y * resolution_y));
    int3 ref_coord_center = int3((ref_coord.x + res_x_2) % res_x, (ref_coord.y + res_y_2) % res_y, 0);
    
    float4 refracted_field = BiologicalDensityGrid.Load(ref_coord_center);
    float ref_senescent = saturate(0.5 - (0.5 - refracted_field.b));
    float ref_macrophage = saturate(0.5 - (0.5 - saturate(refracted_field.a)));
    float ref_scavenger = saturate(0.5 - (0.5 - saturate(-refracted_field.a)));

    float cd47_expression = biochem_field.r;
    float mutational_burden = biochem_field.g;
    float acid_factor = biochem_field.b;

    float3 snarf_neutral = float3(0.15, 0.25, 0.40); 
    float3 snarf_acidic = float3(1.00, 0.50, 0.00);  
    float3 plasma_ph_color = lerp(snarf_neutral, snarf_acidic, smoothstep(0.0, 1.0, acid_factor));
    float3 plasma_scattering = plasma_ph_color * (density_deviation * 15.0);

    float sasp_px = saturate(phys_px.g);
    float sasp_nx = saturate(phys_nx.g);
    float sasp_py = saturate(phys_py.g);
    float sasp_ny = saturate(phys_ny.g);
    
    // Phase 88: Unobstructed biochemical gradient derivation for natural halo propagation.
    float2 grad_sasp = float2((sasp_px - sasp_nx) * 0.5, (sasp_py - sasp_ny) * 0.5);
    float phase_shift_magnitude = length(grad_sasp);
    
    float halo_intensity = smoothstep(0.0, 0.2, phase_shift_magnitude) * exp(-phase_shift_magnitude * 2.0);
    float3 inflammation_halo = float3(0.5, 0.6, 0.8) * halo_intensity * 0.2;

    float cancer_hypertrophy = smoothstep(1.0, 5.0, cd47_expression);
    float tumor_optical_attenuation = exp(-cancer_hypertrophy * 1.8);
    float tumor_refractive_edge_flare = evaluate_phase_contrast_scattering(ref_senescent, 0.03) * cancer_hypertrophy * 1.5;

    float structural_scattering = evaluate_phase_contrast_scattering(ref_senescent + ref_macrophage + ref_scavenger, 0.01);
    
    float3 spectral_cross_section = float3(2.5, 0.8, 0.2); 
    float3 chemical_attenuation = float3(
        evaluate_beer_lambert_attenuation(sasp_concentration, spectral_cross_section.r),
        evaluate_beer_lambert_attenuation(sasp_concentration, spectral_cross_section.g),
        evaluate_beer_lambert_attenuation(sasp_concentration, spectral_cross_section.b)
    );

    float3 transmitted_photons = float3(0.02, 0.03, 0.05) * tumor_optical_attenuation;
    float3 membrane_refraction = float3(0.85, 0.95, 1.0) * structural_scattering * tumor_optical_attenuation;
    membrane_refraction += float3(1.0, 1.0, 1.0) * tumor_refractive_edge_flare + inflammation_halo;

    float prey_visibility = smoothstep(0.0, 0.1, sdf_agent_final) * smoothstep(0.0, 0.1, sdf_scavenger);
    float3 basal_lipofuscin = float3(0.6, 0.9, 0.1); 
    
    float3 mutational_lipofuscin = float3(0.9, 0.7, 0.2); 
    float3 alexa488_fluorochrome = float3(0.1, 1.0, 0.4); 
    
    float mutational_severity = smoothstep(5.0, 30.0, mutational_burden);
    float3 mutation_color = lerp(mutational_lipofuscin, alexa488_fluorochrome, mutational_severity);
    
    float nuclear_mask = saturate(mutational_burden * 0.15);
    float3 mutation_fluorescence = mutation_color * nuclear_mask; 

    float3 cyan_fluorophore = float3(0.0, 0.8, 1.0);        
    float3 scavenger_fluorophore = float3(1.0, 0.2, 0.8); 
    
    float3 cellular_emission = (refined_senescent_density * basal_lipofuscin * 2.8 * prey_visibility) + 
                               (refined_macrophage_density * cyan_fluorophore * 3.5) +
                               (refined_scavenger_density * scavenger_fluorophore * 4.5);

    cellular_emission += refined_senescent_density * mutation_fluorescence * prey_visibility;

    float3 final_radiance = (transmitted_photons + membrane_refraction + plasma_scattering) * chemical_attenuation;
    
    float3 atp_mist = float3(0.8, 0.4, 1.0) * atp_concentration * 1.5;
    final_radiance += atp_mist;
    final_radiance += cellular_emission;

    float2 center_uv = base_uv * 2.0 - 1.0;
    float radial_distance_sq = dot(center_uv, center_uv);
    float optical_vignette = exp(-radial_distance_sq * 1.8);
    
    float3 attenuated_radiance = final_radiance * optical_vignette;
    
    // Phase 87: Passing discrete integer coordinates to the bitwise hash to ensure flawless photon noise mapping.
    float stochastic_dithering = (evaluate_photon_noise(uint2(base_coord), biological_time) - 0.5) * 0.03;

    return saturate(float4(attenuated_radiance + float3(stochastic_dithering, stochastic_dithering, stochastic_dithering), 1.0));
}
)";

#endif // SHADER_PAYLOAD_H
// --- END OF FILE Shader.Payload.h ---