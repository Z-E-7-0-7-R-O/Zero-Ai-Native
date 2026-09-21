// --- START OF FILE Matrix.Orchestrator.cpp ---

#include "Matrix.Orchestrator.h"
#include "Biochemical.Constants.h"
#include <cuda_runtime.h>
#include <chrono>
#include <string>
#include <utility>

#pragma comment(lib, "nvml.lib")

BiophysicalSimulationOrchestrator::BiophysicalSimulationOrchestrator() : plasma_environment(nullptr), biochemical_field(nullptr),
tissue_population(nullptr), agent_population(nullptr), scavenger_population(nullptr),
genomic_environment(nullptr), epigenetic_registry(nullptr), proteomic_state(nullptr), central_dogma(nullptr), mutagenesis_engine(nullptr),
parp_repair_engine(nullptr), d_biochemical_state_grid(nullptr),
compute_state_ptr(nullptr), front_state_ptr(nullptr),
telemetry_logger(nullptr), entropy_ticks(0),
thermodynamic_accumulator_debt_ms(0.0), opt_wddm_penalty(0.0), opt_wddm_exceeded(0.0), opt_interop_lat(0.0), opt_present_lat(0.0),
opt_fps(0.0), opt_vram_idle_ms(0.0),
is_nvml_initialized(false), cached_thermal_throttling_state(0.0),
submitted_compute_epochs(0), completed_compute_epochs(0),
compute_stream_fluidics(nullptr), compute_stream_biochemical(nullptr), compute_stream_kinematics(nullptr), compute_stream_genomics(nullptr), compute_stream_telemetry(nullptr),
event_fluidics_sync(nullptr), event_kinematics_sync(nullptr), event_density_sync(nullptr), event_genomics_sync(nullptr), event_biochemical_sync(nullptr), event_telemetry_sync(nullptr)
{
    is_subsystem_initialized.store(false, std::memory_order_relaxed);

    for (int i = 0; i < 3; ++i) {
        state_pool[i].d_optical_buffer = nullptr;
        state_pool[i].d_biochemical_buffer = nullptr;
        state_pool[i].ready_event = nullptr;
    }
}

BiophysicalSimulationOrchestrator::~BiophysicalSimulationOrchestrator() {
    for (int i = 0; i < 3; ++i) {
        if (state_pool[i].d_optical_buffer) cudaFree(state_pool[i].d_optical_buffer);
        if (state_pool[i].d_biochemical_buffer) cudaFree(state_pool[i].d_biochemical_buffer);
        if (state_pool[i].ready_event) cudaEventDestroy(state_pool[i].ready_event);
    }

    if (is_nvml_initialized) {
        nvmlShutdown();
    }
    for (int i = 0; i < 256; ++i) {
        cudaEventDestroy(compute_queue_events[i]);
    }

    if (compute_stream_fluidics) cudaStreamDestroy(compute_stream_fluidics);
    if (compute_stream_biochemical) cudaStreamDestroy(compute_stream_biochemical);
    if (compute_stream_kinematics) cudaStreamDestroy(compute_stream_kinematics);
    if (compute_stream_genomics) cudaStreamDestroy(compute_stream_genomics);
    if (compute_stream_telemetry) cudaStreamDestroy(compute_stream_telemetry);

    if (event_fluidics_sync) cudaEventDestroy(event_fluidics_sync);
    if (event_kinematics_sync) cudaEventDestroy(event_kinematics_sync);
    if (event_density_sync) cudaEventDestroy(event_density_sync);
    if (event_genomics_sync) cudaEventDestroy(event_genomics_sync);
    if (event_biochemical_sync) cudaEventDestroy(event_biochemical_sync);
    if (event_telemetry_sync) cudaEventDestroy(event_telemetry_sync);

    if (d_biochemical_state_grid) cudaFree(d_biochemical_state_grid);
    if (telemetry_logger) {
        telemetry_logger->FlushPendingTelemetry();
        delete telemetry_logger;
    }
    if (parp_repair_engine) delete parp_repair_engine;
    if (mutagenesis_engine) delete mutagenesis_engine;
    if (central_dogma) delete central_dogma;
    if (proteomic_state) delete proteomic_state;
    if (epigenetic_registry) delete epigenetic_registry;
    if (genomic_environment) delete genomic_environment;
    if (scavenger_population) delete scavenger_population;
    if (agent_population) delete agent_population;
    if (tissue_population) delete tissue_population;
    if (biochemical_field) delete biochemical_field;
    if (plasma_environment) delete plasma_environment;
}

bool BiophysicalSimulationOrchestrator::IsInitialized() const {
    return is_subsystem_initialized.load(std::memory_order_acquire);
}

void BiophysicalSimulationOrchestrator::UpdateThermodynamicAccumulatorDebt(double debt) {
    thermodynamic_accumulator_debt_ms.store(debt, std::memory_order_relaxed);
}

void BiophysicalSimulationOrchestrator::UpdateOpticalTelemetry(double wddm_penalty, double wddm_exceeded, double interop_lat, double present_lat) {
    opt_wddm_penalty.store(wddm_penalty, std::memory_order_relaxed);
    opt_wddm_exceeded.store(wddm_exceeded, std::memory_order_relaxed);
    opt_interop_lat.store(interop_lat, std::memory_order_relaxed);
    opt_present_lat.store(present_lat, std::memory_order_relaxed);
}

void BiophysicalSimulationOrchestrator::UpdateOpticalPacingMetrics(double fps, double idle_time_ms) {
    opt_fps.store(fps, std::memory_order_relaxed);
    opt_vram_idle_ms.store(idle_time_ms, std::memory_order_relaxed);
}

void BiophysicalSimulationOrchestrator::InitializeSimulation() {

    cudaStreamCreateWithFlags(&compute_stream_fluidics, cudaStreamNonBlocking);
    cudaStreamCreateWithFlags(&compute_stream_biochemical, cudaStreamNonBlocking);
    cudaStreamCreateWithFlags(&compute_stream_kinematics, cudaStreamNonBlocking);
    cudaStreamCreateWithFlags(&compute_stream_genomics, cudaStreamNonBlocking);
    cudaStreamCreateWithFlags(&compute_stream_telemetry, cudaStreamNonBlocking);

    cudaEventCreateWithFlags(&event_fluidics_sync, cudaEventDisableTiming);
    cudaEventCreateWithFlags(&event_kinematics_sync, cudaEventDisableTiming);
    cudaEventCreateWithFlags(&event_density_sync, cudaEventDisableTiming);
    cudaEventCreateWithFlags(&event_genomics_sync, cudaEventDisableTiming);
    cudaEventCreateWithFlags(&event_biochemical_sync, cudaEventDisableTiming);
    cudaEventCreateWithFlags(&event_telemetry_sync, cudaEventDisableTiming);

    plasma_environment = new ComputationalFluidDynamicsEnvironment();
    plasma_environment->InitializePlasma(compute_stream_fluidics);

    biochemical_field = new ReactionDiffusionField();
    biochemical_field->InitializeGradientField(compute_stream_biochemical);

    auto current_time_seed = std::chrono::high_resolution_clock::now().time_since_epoch().count();
    uint32_t biological_entropy_seed = static_cast<uint32_t>(current_time_seed);

    tissue_population = new SenescentCellPopulation(150, biological_entropy_seed);

    agent_population = new AutonomousSenolyticAgentPopulation(150, biological_entropy_seed ^ 0x1A2B3C4D);
    scavenger_population = new AutonomousSenolyticAgentPopulation(30, biological_entropy_seed ^ 0x5E6F7A8B);

    tissue_population->AssignGlobalGenomicOffset(0);
    agent_population->AssignGlobalGenomicOffset(tissue_population->population_size);
    scavenger_population->AssignGlobalGenomicOffset(tissue_population->population_size + agent_population->population_size);

    int total_ecosystem_agents = tissue_population->population_size + agent_population->population_size + scavenger_population->population_size;

    genomic_environment = new MacromolecularGenomicEnvironment();
    genomic_environment->InitializeGenomicSubsystem(total_ecosystem_agents, compute_stream_genomics);

    epigenetic_registry = new EpigeneticPromoterRegistry();
    epigenetic_registry->AllocateEpigeneticTensors(total_ecosystem_agents);

    epigenetic_registry->InitializeSenescentProfile(tissue_population->global_genomic_offset, tissue_population->population_size);
    epigenetic_registry->InitializeSenophageProfile(agent_population->global_genomic_offset, agent_population->population_size);
    epigenetic_registry->InitializeScavengerProfile(scavenger_population->global_genomic_offset, scavenger_population->population_size);

    proteomic_state = new ProteomicExpressionState();
    proteomic_state->AllocateProteomicTensors(total_ecosystem_agents, compute_stream_genomics);

    central_dogma = new CentralDogmaEngine(genomic_environment, epigenetic_registry, proteomic_state);
    central_dogma->ExecuteTranscription(0, total_ecosystem_agents, compute_stream_genomics);

    mutagenesis_engine = new ThermodynamicMutagenesisEngine(genomic_environment);
    parp_repair_engine = new ThermodynamicPARPRepairEngine(genomic_environment);

    size_t biochemical_grid_size = BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * 4 * sizeof(float);
    cudaMalloc(&d_biochemical_state_grid, biochemical_grid_size);
    cudaMemsetAsync(d_biochemical_state_grid, 0, biochemical_grid_size, compute_stream_biochemical);

    for (int i = 0; i < 3; ++i) {
        cudaMalloc(&state_pool[i].d_optical_buffer, biochemical_grid_size);
        cudaMalloc(&state_pool[i].d_biochemical_buffer, biochemical_grid_size);
        cudaMemsetAsync(state_pool[i].d_optical_buffer, 0, biochemical_grid_size, compute_stream_biochemical);
        cudaMemsetAsync(state_pool[i].d_biochemical_buffer, 0, biochemical_grid_size, compute_stream_biochemical);
        cudaEventCreateWithFlags(&state_pool[i].ready_event, cudaEventDisableTiming);

        cudaEventRecord(state_pool[i].ready_event, compute_stream_biochemical);
    }

    for (int i = 0; i < 256; ++i) {
        cudaEventCreateWithFlags(&compute_queue_events[i], cudaEventDisableTiming);
    }

    if (nvmlInit_v2() == NVML_SUCCESS) {
        if (nvmlDeviceGetHandleByIndex_v2(0, &nvml_device_handle) == NVML_SUCCESS) {
            is_nvml_initialized = true;
            last_nvml_poll_time = std::chrono::high_resolution_clock::now();
        }
    }

    compute_state_ptr = &state_pool[0];
    front_state_ptr = &state_pool[1];
    atomic_back_state_ptr.store(&state_pool[2], std::memory_order_relaxed);

    auto now = std::chrono::system_clock::now();
    auto epoch_seconds = std::chrono::duration_cast<std::chrono::seconds>(now.time_since_epoch()).count();
    std::string dynamic_filename = "Biophysical_MegaTelemetry_Report_" + std::to_string(epoch_seconds) + ".csv";

    telemetry_logger = new BiophysicalTelemetryLogger(dynamic_filename);
    entropy_ticks = 0;

    cudaDeviceSynchronize();

    is_subsystem_initialized.store(true, std::memory_order_release);
}

void BiophysicalSimulationOrchestrator::AdvanceThermodynamicTime() {

    auto now = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double, std::milli> nvml_elapsed = now - last_nvml_poll_time;
    if (nvml_elapsed.count() > 500.0 && is_nvml_initialized) {
        unsigned int gpu_temp = 0;
        unsigned int gpu_clock = 0;

#pragma warning(push)
#pragma warning(disable: 4996)
        nvmlDeviceGetTemperature(nvml_device_handle, NVML_TEMPERATURE_GPU, &gpu_temp);
#pragma warning(pop)

        nvmlDeviceGetClockInfo(nvml_device_handle, NVML_CLOCK_GRAPHICS, &gpu_clock);

        cached_thermal_throttling_state = static_cast<double>(gpu_temp) + (static_cast<double>(gpu_clock) * 0.0001);
        last_nvml_poll_time = now;
    }

    cudaMemsetAsync(g_active_device_accumulators, 0, sizeof(BiophysicalAccumulators), compute_stream_telemetry);

    if (entropy_ticks > 0) {
        cudaStreamWaitEvent(compute_stream_fluidics, event_kinematics_sync, 0);
        cudaStreamWaitEvent(compute_stream_fluidics, event_genomics_sync, 0);
        cudaStreamWaitEvent(compute_stream_fluidics, event_biochemical_sync, 0);
        cudaStreamWaitEvent(compute_stream_fluidics, event_telemetry_sync, 0);

        cudaStreamWaitEvent(compute_stream_kinematics, event_fluidics_sync, 0);
        cudaStreamWaitEvent(compute_stream_kinematics, event_genomics_sync, 0);
        cudaStreamWaitEvent(compute_stream_kinematics, event_biochemical_sync, 0);
        cudaStreamWaitEvent(compute_stream_kinematics, event_telemetry_sync, 0);

        cudaStreamWaitEvent(compute_stream_genomics, event_fluidics_sync, 0);
        cudaStreamWaitEvent(compute_stream_genomics, event_kinematics_sync, 0);
        cudaStreamWaitEvent(compute_stream_genomics, event_biochemical_sync, 0);
        cudaStreamWaitEvent(compute_stream_genomics, event_telemetry_sync, 0);

        cudaStreamWaitEvent(compute_stream_biochemical, event_fluidics_sync, 0);
        cudaStreamWaitEvent(compute_stream_biochemical, event_kinematics_sync, 0);
        cudaStreamWaitEvent(compute_stream_biochemical, event_genomics_sync, 0);
        cudaStreamWaitEvent(compute_stream_biochemical, event_telemetry_sync, 0);
    }

    // Branch A: Genomics & Mutation Processing
    if (entropy_ticks > 0) {
        unsigned long long mut_epoch = entropy_ticks % BiophysicalConstants::MUTAGENESIS_EPOCH;
        if (mut_epoch == 0) {
            mutagenesis_engine->InduceTissueGenotoxicity(tissue_population->population_size, tissue_population->global_genomic_offset, tissue_population->d_pos_x_current, tissue_population->d_pos_y_current, tissue_population->d_membrane_integrity_current, biochemical_field->d_sasp_concentration, entropy_ticks, compute_stream_genomics);
        }
        else if (mut_epoch == 1) {
            mutagenesis_engine->InduceAgentGenotoxicity(agent_population->population_size, agent_population->global_genomic_offset, agent_population->d_pos_x_current, agent_population->d_pos_y_current, agent_population->d_atp_level_current, agent_population->d_lipid_burden_current, biochemical_field->d_sasp_concentration, entropy_ticks, compute_stream_genomics);
        }
        else if (mut_epoch == 2) {
            mutagenesis_engine->InduceAgentGenotoxicity(scavenger_population->population_size, scavenger_population->global_genomic_offset, scavenger_population->d_pos_x_current, scavenger_population->d_pos_y_current, scavenger_population->d_atp_level_current, scavenger_population->d_lipid_burden_current, biochemical_field->d_sasp_concentration, entropy_ticks, compute_stream_genomics);
        }

        unsigned long long parp_epoch = entropy_ticks % BiophysicalConstants::PARP_REPAIR_EPOCH;
        if (parp_epoch == 25) {
            parp_repair_engine->ExecuteTissueRepair(tissue_population->population_size, tissue_population->global_genomic_offset, tissue_population->d_membrane_integrity_current, tissue_population->d_membrane_integrity_next, entropy_ticks, compute_stream_genomics);
        }
        else if (parp_epoch == 26) {
            parp_repair_engine->ExecuteAgentRepair(agent_population->population_size, agent_population->global_genomic_offset, agent_population->d_atp_level_current, agent_population->d_atp_level_next, entropy_ticks, compute_stream_genomics);
        }
        else if (parp_epoch == 27) {
            parp_repair_engine->ExecuteAgentRepair(scavenger_population->population_size, scavenger_population->global_genomic_offset, scavenger_population->d_atp_level_current, scavenger_population->d_atp_level_next, entropy_ticks, compute_stream_genomics);
        }
    }

    // Phase 93: Continuous Exponential Moving Average Translation Execution
    int total_ecosystem_agents = tissue_population->population_size + agent_population->population_size + scavenger_population->population_size;
    central_dogma->ExecuteTranscription(entropy_ticks, total_ecosystem_agents, compute_stream_genomics);
    cudaEventRecord(event_genomics_sync, compute_stream_genomics);

    // Branch B: Fluidics & Plasma Advection
    plasma_environment->CollideAndStream(compute_stream_fluidics);
    cudaEventRecord(event_fluidics_sync, compute_stream_fluidics);

    // Branch C: Cell Kinematics & Neural Network Forward Propagation
    tissue_population->ExecuteMotilityPhase(agent_population->d_agent_density_grid_current, entropy_ticks, compute_stream_kinematics);

    agent_population->ExecuteMetabolicPhase(
        biochemical_field->d_sasp_concentration,
        plasma_environment->d_external_force_x,
        plasma_environment->d_external_force_y,
        tissue_population->d_tissue_density_grid_current,
        tissue_population->d_pos_x_current,
        tissue_population->d_pos_y_current,
        tissue_population->d_membrane_integrity_current,
        proteomic_state->d_protein_level_CD47_current + tissue_population->global_genomic_offset,
        tissue_population->population_size,
        agent_population->d_pos_x_current,
        agent_population->d_pos_y_current,
        agent_population->population_size,
        entropy_ticks,
        BiophysicalConstants::SENOPHAGE_MOTILITY_SPEED,
        1.0f, 0.0f, 1.0f, 1.0f, 0.0f,
        proteomic_state->d_protein_level_ACTB_current + agent_population->global_genomic_offset,
        proteomic_state->d_protein_level_CD47_current + agent_population->global_genomic_offset,
        proteomic_state->d_protein_level_SIRPA_current + agent_population->global_genomic_offset,
        proteomic_state->d_protein_level_P2RY2_current + agent_population->global_genomic_offset,
        proteomic_state->d_protein_level_ABCA1_current + agent_population->global_genomic_offset,
        compute_stream_kinematics
    );

    scavenger_population->ExecuteMetabolicPhase(
        biochemical_field->d_atp_concentration,
        plasma_environment->d_external_force_x,
        plasma_environment->d_external_force_y,
        tissue_population->d_tissue_density_grid_current,
        tissue_population->d_pos_x_current,
        tissue_population->d_pos_y_current,
        tissue_population->d_membrane_integrity_current,
        proteomic_state->d_protein_level_CD47_current + tissue_population->global_genomic_offset,
        tissue_population->population_size,
        scavenger_population->d_pos_x_current,
        scavenger_population->d_pos_y_current,
        scavenger_population->population_size,
        entropy_ticks ^ 0xDEADBEEF,
        BiophysicalConstants::MACROPHAGE_SCAVENGER_MOTILITY_SPEED,
        0.1f, 1.0f, 5.0f, 5.0f, 1.0f,
        proteomic_state->d_protein_level_ACTB_current + scavenger_population->global_genomic_offset,
        proteomic_state->d_protein_level_CD47_current + scavenger_population->global_genomic_offset,
        proteomic_state->d_protein_level_SIRPA_current + scavenger_population->global_genomic_offset,
        proteomic_state->d_protein_level_P2RY2_current + scavenger_population->global_genomic_offset,
        proteomic_state->d_protein_level_ABCA1_current + scavenger_population->global_genomic_offset,
        compute_stream_kinematics
    );

    tissue_population->ProjectTissueDensity(compute_stream_kinematics);
    agent_population->ProjectAgentDensity(compute_stream_kinematics);
    scavenger_population->ProjectAgentDensity(compute_stream_kinematics);

    cudaEventRecord(event_kinematics_sync, compute_stream_kinematics);

    // Branch D: Biochemical Secretion & PDE
    cudaStreamWaitEvent(compute_stream_biochemical, event_kinematics_sync, 0);

    // Phase 93: CD47-SIRPA Axis Calibration
    // SIRPA expression levels from Central Dogma are injected to dynamically compute physical resistance and blindness.
    tissue_population->ExecuteSecretionPhase(
        biochemical_field->d_sasp_concentration,
        biochemical_field->d_atp_concentration,
        agent_population->d_agent_density_grid_current,
        scavenger_population->d_agent_density_grid_current,
        entropy_ticks,
        proteomic_state->d_protein_level_CD47_current + tissue_population->global_genomic_offset,
        proteomic_state->d_protein_level_SIRPA_current + agent_population->global_genomic_offset,
        proteomic_state->d_protein_level_SIRPA_current + scavenger_population->global_genomic_offset,
        compute_stream_biochemical
    );

    biochemical_field->EvolveChemicalState(
        plasma_environment->d_velocity_x,
        plasma_environment->d_velocity_y,
        agent_population->d_agent_density_grid_current,
        scavenger_population->d_agent_density_grid_current,
        compute_stream_biochemical
    );

    cudaEventRecord(event_biochemical_sync, compute_stream_biochemical);

    cudaEventRecord(compute_queue_events[submitted_compute_epochs % 256], compute_stream_biochemical);
    submitted_compute_epochs++;

    while (completed_compute_epochs < submitted_compute_epochs) {
        if (cudaEventQuery(compute_queue_events[completed_compute_epochs % 256]) == cudaSuccess) {
            completed_compute_epochs++;
        }
        else {
            break;
        }
    }
    double current_queue_depth = static_cast<double>(submitted_compute_epochs - completed_compute_epochs);

    size_t free_byte = 0;
    size_t total_byte = 0;
    cudaMemGetInfo(&free_byte, &total_byte);
    float vram_total = static_cast<float>(total_byte);
    float vram_used = static_cast<float>(total_byte - free_byte);

    double wddm_penalty = opt_wddm_penalty.load(std::memory_order_relaxed);
    double wddm_exceeded = opt_wddm_exceeded.load(std::memory_order_relaxed);
    double interop_latency = opt_interop_lat.load(std::memory_order_relaxed);
    double present_latency = opt_present_lat.load(std::memory_order_relaxed);
    double accumulator_debt = thermodynamic_accumulator_debt_ms.load(std::memory_order_relaxed);

    double current_optical_fps = opt_fps.load(std::memory_order_relaxed);
    double current_vram_idle_ms = opt_vram_idle_ms.load(std::memory_order_relaxed);

    cudaStreamWaitEvent(compute_stream_telemetry, event_biochemical_sync, 0);

    bool trigger_telemetry_scan = true;
    telemetry_logger->LogState(
        entropy_ticks, vram_total, vram_used, trigger_telemetry_scan,
        agent_population->population_size, agent_population->d_atp_level_current, agent_population->d_olfactory_desensitization_current, agent_population->d_motors_batch,
        tissue_population->population_size, tissue_population->d_membrane_integrity_current, proteomic_state->d_protein_level_CD47_current + tissue_population->global_genomic_offset,
        biochemical_field->d_sasp_concentration, biochemical_field->d_atp_concentration, BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS,
        scavenger_population->population_size, scavenger_population->d_atp_level_current, scavenger_population->d_motors_batch, scavenger_population->d_olfactory_desensitization_current, scavenger_population->d_lipid_burden_current,
        genomic_environment->d_global_genome_sequence,
        proteomic_state->d_protein_level_ACTB_current, proteomic_state->d_protein_level_CD47_current, proteomic_state->d_protein_level_SIRPA_current, proteomic_state->d_protein_level_P2RY2_current, proteomic_state->d_protein_level_ABCA1_current,
        wddm_penalty, wddm_exceeded, current_queue_depth,
        interop_latency, present_latency, accumulator_debt, cached_thermal_throttling_state,
        current_optical_fps, current_vram_idle_ms,
        compute_stream_telemetry
    );

    cudaEventRecord(event_telemetry_sync, compute_stream_telemetry);

    proteomic_state->SwapStates();
    tissue_population->SwapStates();
    agent_population->SwapStates();
    scavenger_population->SwapStates();

    entropy_ticks++;
}

void BiophysicalSimulationOrchestrator::CommitRenderState() {

    IntegrateOpticalFields(
        compute_state_ptr->d_optical_buffer,
        plasma_environment->d_density,
        biochemical_field->d_sasp_concentration,
        biochemical_field->d_atp_concentration,
        tissue_population->d_tissue_density_grid_current,
        agent_population->d_agent_density_grid_current,
        scavenger_population->d_agent_density_grid_current,
        BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS,
        compute_stream_biochemical
    );

    cudaMemsetAsync(d_biochemical_state_grid, 0, BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS * 4 * sizeof(float), compute_stream_biochemical);

    int w = BiophysicalConstants::ENVIRONMENT_WIDTH;
    int h = BiophysicalConstants::ENVIRONMENT_HEIGHT;
    float cell_sigma = BiophysicalConstants::SENESCENT_GAUSSIAN_SIGMA_SQ;
    float agent_sigma = BiophysicalConstants::MACROPHAGE_GAUSSIAN_SIGMA_SQ;

    SplatBiochemicalState(
        tissue_population->population_size, tissue_population->d_pos_x_current, tissue_population->d_pos_y_current, tissue_population->d_membrane_integrity_current,
        proteomic_state->d_protein_level_CD47_current + tissue_population->global_genomic_offset,
        genomic_environment->d_global_genome_sequence, tissue_population->global_genomic_offset,
        d_biochemical_state_grid, w, h, BiophysicalConstants::SENESCENT_SPLAT_RADIUS, cell_sigma, entropy_ticks,
        compute_stream_biochemical
    );

    SplatBiochemicalState(
        agent_population->population_size, agent_population->d_pos_x_current, agent_population->d_pos_y_current, nullptr,
        proteomic_state->d_protein_level_CD47_current + agent_population->global_genomic_offset,
        genomic_environment->d_global_genome_sequence, agent_population->global_genomic_offset,
        d_biochemical_state_grid, w, h, BiophysicalConstants::MACROPHAGE_SPLAT_RADIUS, agent_sigma, entropy_ticks,
        compute_stream_biochemical
    );

    SplatBiochemicalState(
        scavenger_population->population_size, scavenger_population->d_pos_x_current, scavenger_population->d_pos_y_current, nullptr,
        proteomic_state->d_protein_level_CD47_current + scavenger_population->global_genomic_offset,
        genomic_environment->d_global_genome_sequence, scavenger_population->global_genomic_offset,
        d_biochemical_state_grid, w, h, BiophysicalConstants::MACROPHAGE_SPLAT_RADIUS, agent_sigma, entropy_ticks,
        compute_stream_biochemical
    );

    IntegrateOpticalBiochemicalFields(
        compute_state_ptr->d_biochemical_buffer, d_biochemical_state_grid,
        biochemical_field->d_sasp_concentration, tissue_population->d_tissue_density_grid_current,
        BiophysicalConstants::ENVIRONMENT_TOTAL_VOXELS, compute_stream_biochemical
    );

    cudaEventRecord(compute_state_ptr->ready_event, compute_stream_biochemical);

    compute_state_ptr = atomic_back_state_ptr.exchange(compute_state_ptr, std::memory_order_acq_rel);
}

void BiophysicalSimulationOrchestrator::FetchRenderState(cudaArray_t mapped_optical_array, cudaArray_t mapped_biochemical_array, size_t pitch, size_t height, cudaStream_t render_stream) {

    front_state_ptr = atomic_back_state_ptr.exchange(front_state_ptr, std::memory_order_acq_rel);

    cudaStreamWaitEvent(render_stream, front_state_ptr->ready_event, 0);

    cudaMemcpy2DToArrayAsync(
        mapped_optical_array, 0, 0,
        front_state_ptr->d_optical_buffer, pitch, pitch,
        height, cudaMemcpyDeviceToDevice, render_stream
    );

    cudaMemcpy2DToArrayAsync(
        mapped_biochemical_array, 0, 0,
        front_state_ptr->d_biochemical_buffer, pitch, pitch,
        height, cudaMemcpyDeviceToDevice, render_stream
    );
}

unsigned long long BiophysicalSimulationOrchestrator::GetBiologicalTime() const {
    return entropy_ticks;
}
// --- END OF FILE Matrix.Orchestrator.cpp ---