#ifndef REACTION_DIFFUSION_SASP_CUH
#define REACTION_DIFFUSION_SASP_CUH

#include <cuda_runtime.h>
#include "Biochemical.Constants.h"

class ReactionDiffusionField {
public:
    ReactionDiffusionField();
    ~ReactionDiffusionField();

    void InitializeGradientField(cudaStream_t stream = 0);
    void EvolveChemicalState(const float* d_fluid_ux, const float* d_fluid_uy, const float* d_agent_density, const float* d_scavenger_density, cudaStream_t stream);

    float* d_sasp_concentration;
    float* d_atp_concentration;

private:
    float* d_sasp_next;
    float* d_atp_next;
};

#endif // REACTION_DIFFUSION_SASP_CUH