// --- START OF FILE Matrix.Orchestrator.h ---
#ifndef BIOPHYSICAL_ORCHESTRATOR_H
#define BIOPHYSICAL_ORCHESTRATOR_H

#include <cuda_runtime_api.h>
#include <atomic> 
#include <chrono>
#include <nvml.h>

#include "Lattice.Boltzmann.Plasma.cuh"
#include "Reaction.Diffusion.SASP.cuh"
#include "Autonomous.Senolytic.Population.cuh"
#include "Macromolecular.Genomic.Allocation.cuh"
#include "Epigenetic.Promoter.Indexing.cuh"
#include "Proteomic.Expression.State.cuh"
#include "Central.Dogma.Transcription.cuh"
#include "Stochastic.Mutagenesis.Kinematics.cuh"
#include "Genomic.Repair.PARP.cuh"

// Phase 85: Included extracted subsystems for Data Spooling and Spatial Projection
#include "Biophysical.Telemetry.Spooler.cuh"
#include "Spatial.Optical.Integration.cuh"

struct BiophysicalRenderState {
    float* d_optical_buffer;
    float* d_biochemical_buffer;
    cudaEvent_t ready_event;
};

class BiophysicalSimulationOrchestrator {
public:
    BiophysicalSimulationOrchestrator();
    ~BiophysicalSimulationOrchestrator();

    void InitializeSimulation();
    void AdvanceThermodynamicTime();

    unsigned long long GetBiologicalTime() const;

    bool IsInitialized() const;

    void CommitRenderState();

    void FetchRenderState(cudaArray_t mapped_optical_array, cudaArray_t mapped_biochemical_array, size_t pitch, size_t height, cudaStream_t render_stream);

    void UpdateThermodynamicAccumulatorDebt(double debt);
    void UpdateOpticalTelemetry(double wddm_penalty, double wddm_exceeded, double interop_lat, double present_lat);

    // Phase 86: New protocol for transferring optical shutter telemetry
    void UpdateOpticalPacingMetrics(double fps, double idle_time_ms);

private:
    ComputationalFluidDynamicsEnvironment* plasma_environment;
    ReactionDiffusionField* biochemical_field;

    SenescentCellPopulation* tissue_population;
    AutonomousSenolyticAgentPopulation* agent_population;
    AutonomousSenolyticAgentPopulation* scavenger_population;

    MacromolecularGenomicEnvironment* genomic_environment;
    EpigeneticPromoterRegistry* epigenetic_registry;
    ProteomicExpressionState* proteomic_state;
    CentralDogmaEngine* central_dogma;
    ThermodynamicMutagenesisEngine* mutagenesis_engine;
    ThermodynamicPARPRepairEngine* parp_repair_engine;

    float* d_biochemical_state_grid;

    BiophysicalTelemetryLogger* telemetry_logger;

    unsigned long long entropy_ticks;

    std::atomic<bool> is_subsystem_initialized;

    BiophysicalRenderState state_pool[3];
    BiophysicalRenderState* compute_state_ptr;
    BiophysicalRenderState* front_state_ptr;
    std::atomic<BiophysicalRenderState*> atomic_back_state_ptr;

    std::atomic<double> thermodynamic_accumulator_debt_ms;
    std::atomic<double> opt_wddm_penalty;
    std::atomic<double> opt_wddm_exceeded;
    std::atomic<double> opt_interop_lat;
    std::atomic<double> opt_present_lat;

    // Phase 86: Thread-safe atomics for rendering pacing isolation metrics
    std::atomic<double> opt_fps;
    std::atomic<double> opt_vram_idle_ms;

    nvmlDevice_t nvml_device_handle;
    bool is_nvml_initialized;
    double cached_thermal_throttling_state;
    std::chrono::high_resolution_clock::time_point last_nvml_poll_time;

    cudaEvent_t compute_queue_events[256];
    unsigned long long submitted_compute_epochs;
    unsigned long long completed_compute_epochs;

    cudaStream_t compute_stream_fluidics;
    cudaStream_t compute_stream_biochemical;
    cudaStream_t compute_stream_kinematics;
    cudaStream_t compute_stream_genomics;
    cudaStream_t compute_stream_telemetry;

    cudaEvent_t event_fluidics_sync;
    cudaEvent_t event_kinematics_sync;
    cudaEvent_t event_density_sync;
    cudaEvent_t event_genomics_sync;
    cudaEvent_t event_biochemical_sync;
    cudaEvent_t event_telemetry_sync;
};

#endif // BIOPHYSICAL_ORCHESTRATOR_H
// --- END OF FILE Matrix.Orchestrator.h ---