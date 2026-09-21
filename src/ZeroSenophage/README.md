### ZeroSenophage: GPU-Accelerated Thermodynamic Kinematics & Genomic Senolytic Simulator

<div align="center">
<i>A CUDA C++ computational framework for simulating time-dependent cellular dynamics, macromolecular genomic damage, and tumor microenvironment equilibrium.</i>
<br><br>
<b>Developer:</b> Zero-AI-Native (Age 15, assisted by Google Gemini 3.1 Pro) <br>
<b>Architecture:</b> CUDA C++ / DirectX 11 / Computational Biophysics<br>
<b>Status:</b> Concept / Simulation Deployed
</div>

--------------------------------------------------------------------------------

## Overview
ZeroSenophage is a GPU-accelerated computational biophysics engine designed to model time-dependent cell kinetics, fluid dynamics, biochemical gradient transport, macromolecular genomic mutations, and autonomous senolytic phagocytosis within a simulated tissue microenvironment. The simulator operates on a 2D 1024 × 1024 continuum matrix domain (1 voxel = 1 μm) containing three distinct cellular populations: hypertrophic senescent cells ("zombie cells"), engineered senolytic agents ("senophages"), and resident scavenger macrophages.

Rather than utilizing pre-scripted state transitions, ZeroSenophage evaluates cellular dynamics via coupled physical solvers and stochastic CUDA kernels:
1. **Lattice Boltzmann Plasma Hydrodynamics (D2Q9 BGK Model):** Simulates interstitial fluid advection and kinematic viscosity (τ = 0.8) at 37°C.
2. **PDE Reaction-Diffusion Fields:** Solves 2D partial differential equations for Senescence-Associated Secretory Phenotype (SASP) cytokines and extracellular ATP gradients using 9-point Laplacian stencils and sub-pixel advection.
3. **Autonomous Kinematics & Efferotabolism:** Models agent motility via Lévy walk foraging trajectories, Hebbian neural drive, actin protrusive thrust, CD47-SIRPα signaling inhibition, trogoptosis, macropinocytosis, fatty acid β-oxidation, ABCA1 cholesterol efflux, and lipotoxicity ER stress.
4. **Macromolecular 64-Bit VRAM Genomics:** Allocates 8.59 GB of VRAM storing 34,359,738,368 total base pairs (104,120,416 bp per agent across 330 initial agents) using 2-bit nucleotide packing (16 bp per `uint32_t` word).
5. **Central Dogma & Epigenetics:** Simulates continuous promoter DNA methylation weights ([0.0, 1.0]) and Exponential Moving Average (EMA) protein translation/degradation kinetics for `ACTB`, `CD47`, `SIRPA`, `P2RY2`, and `ABCA1` loci.
6. **Thermodynamic Mutagenesis & PARP-1 Repair:** Evaluates Michaelis-Menten ROS oxidative bit-flipping and ATP-dependent PARP-1 single-base restoration, tracking exact locus mutation hits.
7. **DirectX 11 Raymarching Microscope:** Renders sub-pixel physical optics, phase-contrast halos, SNARF-4F ratiometric pH fluorophores, Alexa Fluor 488 8-oxo-dG damage emissions, and bitwise permutation spatial hashing to eliminate Moiré artifacts.

### Scale & Hardware Specifications
The simulation is engineered to process up to 34,359,738,368 base pairs across a 1024 × 1024 continuum matrix per tick. All chemical gradient evaluations, cellular kinetics, and genomic mutation scans are executed on the GPU. The architecture has been optimized to run within the constraints of consumer-grade hardware, specifically deployed and tested on an **NVIDIA GeForce RTX 3060 (12GB VRAM)**. Performance stability (60.0 FPS UI rendering) is maintained by 64-bit VRAM memory structures, 2-bit nucleotide bit-packing, and decoupling CUDA compute kernels from the DirectX 11 rendering thread using asynchronous streams (`cudaStreamCreateWithFlags`).

--------------------------------------------------------------------------------

## Technical Details / Architecture

All core mathematical models, CUDA execution kernels, biophysical solvers, and shader payloads are open for technical audit and verification.

### Senophage Dual Mechanism: Senolytic Clearance & Pre-Neoplastic Interception

The engineered senolytic agent ("senophage") operates via a dual-action therapeutic paradigm within the simulated continuum microenvironment:

1. **Senolytic Clearance (Senescence Elimination):** Senescent cells accumulate over time and persistently secrete Senescence-Associated Secretory Phenotype (SASP) factors—including pro-inflammatory cytokines, chemokines, and reactive oxygen species (ROS). Senophages utilize directed actin-driven propulsion, Hebbian-reinforcement chemotaxis, and surface receptor engagement to target hypertrophic senescent cells, initiating macropinocytosis, trogocytosis, and phagocytic engulfment to clear senescent tissue burden.

2. **Pre-Neoplastic Interception Barrier (Tumorigenesis Prevention):** Prolonged exposure to SASP-induced ROS and genotoxic bystander stress drives progressive DNA damage, somatic mutation accumulation, and oncogenic transformation in adjacent healthy cells. By executing an epigenetic/genetic knockout of the `SIRPA` inhibitory receptor locus (`sirpa_weight = 0.0f`), senophages bypass the `CD47` "don't eat me" evasion shield expressed by senescent and pre-malignant cells. Through early clearance of hypertrophic senescent cells before somatic mutation thresholds trigger neoplastic transition, senophages intercept paracrine oncogenesis at its root—depriving potential tumor-initiating foci of the chronic inflammatory driver required for tumorigenesis.

**Source Code Modules & Engine Components:**

* **[Zero.Nucleus.cpp](Zero.Nucleus.cpp)**
  * **Role:** Application Entry Point & High-Precision System Lifecycle Manager.
  * **Implementation:** Overrides OS display scaling using `SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)` to enforce 1:1 hardware pixel mapping and eradicate DWM bilinear stretching. Manages window creation (`AdjustWindowRect` for 1024 × 1024 client area) and spawns a dedicated high-priority physics thread (`ThermodynamicComputeThread`). Implements death-spiral accumulator clamping (`max_accumulator_threshold = 3 * dt`) to prevent physics stalls upon OS wake, and executes hybrid spin-yield pacing to lock optical rendering strictly to 60 Hz.

* **[Matrix.Orchestrator.h](Matrix.Orchestrator.h) | [Matrix.Orchestrator.cpp](Matrix.Orchestrator.cpp)**
  * **Role:** Asynchronous Subsystem Orchestrator & Multi-Stream CUDA Pipeline Manager.
  * **Implementation:** Instantiates and coordinates all CUDA compute environments (`ComputationalFluidDynamicsEnvironment`, `ReactionDiffusionField`, `MacromolecularGenomicEnvironment`, `EpigeneticPromoterRegistry`, `ProteomicExpressionState`, `CentralDogmaEngine`, `ThermodynamicMutagenesisEngine`, `ThermodynamicPARPRepairEngine`, and agent populations). Manages 5 non-blocking CUDA streams (`compute_stream_fluidics`, `compute_stream_biochemical`, `compute_stream_kinematics`, `compute_stream_genomics`, `compute_stream_telemetry`) with CUDA event cross-stream synchronization barriers. Manages triple-buffered render state pools (`BiophysicalRenderState state_pool[3]`) for lock-free compute-render exchange. Interrogates hardware status via NVML (`nvmlDeviceGetTemperature`, `nvmlDeviceGetClockInfo`).

* **[Autonomous.Senolytic.Population.cuh](Autonomous.Senolytic.Population.cuh) | [Autonomous.Senolytic.Population.cu](Autonomous.Senolytic.Population.cu)**
  * **Role:** Cellular Agent Kinematics, Phagocytic Synapse & Efferotabolism Engine.
  * **Implementation:** Defines `SenescentCellPopulation` and `AutonomousSenolyticAgentPopulation` using ping-pong double buffering (`d_pos_x_current`, `d_pos_x_next`, `d_atp_level_current`, `d_lipid_burden_current`, etc.). Executes four specialized CUDA kernels:
    * `Tissue_Secretion_Kernel`: Evaluates local senophage/scavenger densities, CD47-SIRPα inhibitory receptor shielding, cooperative swarming synergy, phagocytic cup formation, macropinocytosis, trogocytosis nibbling, trogoptosis secondary necrosis acceleration, and in-situ stochastic cell turnover using PCG hashing (`Generate_PCG_Hash`).
    * `Senescent_Tissue_Kinematics_Kernel`: Simulates senescent cell evasion vectors derived from density gradients and persistent random walk (PRW) motility.
    * `Read_Olfactory_Sensors_Kernel`: Processes 8-directional SASP concentration sampling with receptor desensitization (fatigue accumulation), lateral inhibition, and P2RY2 receptor expression scaling.
    * `Autonomous_Agent_Kinematics_Kernel`: Executes 256-thread-per-agent block reductions. Calculates steric inter-agent repulsion, Lévy walk heavy-tailed stochastic search steps (`clamped_levy`), actin protrusive thrust vectors scaled by `ACTB` protein levels, Hebbian motor drive, drag reduction upon integrin target commitment, fatty acid β-oxidation ATP regeneration, ABCA1 cholesterol efflux pumping, lipotoxicity ER stress (Hill function), starvation autophagy energy reserve, and Peskin immersed-boundary fluid force injection (`ext_fx`, `ext_fy`).

* **[Lattice.Boltzmann.Plasma.cuh](Lattice.Boltzmann.Plasma.cuh) | [Lattice.Boltzmann.Plasma.cu](Lattice.Boltzmann.Plasma.cu)**
  * **Role:** Interstitial Plasma Computational Fluid Dynamics (CFD) Environment.
  * **Implementation:** Implements a 2D D2Q9 Lattice Boltzmann Method (LBM) solver using the Bhatnagar-Gross-Krook (BGK) collision operator. Sets plasma relaxation time `PLASMA_TAU = 0.8f` to match blood plasma kinematic viscosity at 37°C. Calculates local density ρ and velocity vectors (`u_x, u_y`), applying hyperbolic tangent velocity clamping (`tanhf`) to enforce speed-of-sound Mach limits (< 0.3 c_s) and injecting Brownian stochastic forcing.

* **[Reaction.Diffusion.SASP.cuh](Reaction.Diffusion.SASP.cuh) | [Reaction.Diffusion.SASP.cu](Reaction.Diffusion.SASP.cu)**
  * **Role:** Biochemical Signaling Field & Partial Differential Equation Solver.
  * **Implementation:** Manages 2D grid fields (`d_sasp_concentration`, `d_atp_concentration`). Executes `PDE_Reaction_Diffusion_Kernel` to solve advection-diffusion-reaction equations using an 8-neighbor discrete 9-point Laplacian operator, sub-pixel bilinear interpolation from LBM fluid velocity vectors (`u_x, u_y`), toroidal boundary modulo wrapping, natural chemical decay, and cellular endocytosis clearance sinks.

* **[Macromolecular.Genomic.Allocation.cuh](Macromolecular.Genomic.Allocation.cuh) | [Macromolecular.Genomic.Allocation.cu](Macromolecular.Genomic.Allocation.cu)**
  * **Role:** 64-Bit VRAM Macromolecular Genomic Storage Manager.
  * **Implementation:** Allocates 2,147,483,580 `uint32_t` words (~8.59 GB VRAM) storing 34,359,738,368 total base pairs across the ecosystem (104,120,416 bp per agent across 330 initial agents). Employs 2-bit nucleotide bit-packing (16 base pairs per `uint32_t` word). Executes `Stochastic_Heterochromatin_Seeding_Kernel` for background heterochromatin initialization and `WildType_CodingSequence_Implantation_Kernel` to write wild-type stability patterns (`0xAAAAAAAA`) at specific loci (`ACTB`, `CD47`, `CD47_REPRESSOR`, `SIRPA`, `P2RY2`, `ABCA1`).

* **[Epigenetic.Promoter.Indexing.cuh](Epigenetic.Promoter.Indexing.cuh) | [Epigenetic.Promoter.Indexing.cu](Epigenetic.Promoter.Indexing.cu)**
  * **Role:** Epigenetic Methylome Indexing & Promoter Access Control.
  * **Implementation:** Maintains continuous float arrays (`d_epigenetic_weight_ACTB`, `d_epigenetic_weight_CD47`, `d_epigenetic_weight_SIRPA`, `d_epigenetic_weight_P2RY2`, `d_epigenetic_weight_ABCA1`) representing promoter access weights ([0.0, 1.0]). Initializes cell-type specific methylomes: fully opens `CD47` in senescent cells while methylating receptors; executes genetic/epigenetic knockout of `SIRPA` in senophages to prevent CD47-mediated evasion; and opens `P2RY2` and `ABCA1` euchromatin in scavenger macrophages.

* **[Proteomic.Expression.State.cuh](Proteomic.Expression.State.cuh) | [Proteomic.Expression.State.cu](Proteomic.Expression.State.cu)**
  * **Role:** Proteomic Expression Tensor Storage & Buffer Management.
  * **Implementation:** Manages double-buffered current (T) and next (T+1) float tensors for protein expression levels of `ACTB`, `CD47`, `SIRPA`, `P2RY2`, and `ABCA1`. Executes zero-cost GPU pointer swapping (`SwapStates`) to bypass VRAM copy bandwidth overhead.

* **[Central.Dogma.Transcription.cuh](Central.Dogma.Transcription.cuh) | [Central.Dogma.Transcription.cu](Central.Dogma.Transcription.cu)**
  * **Role:** Central Dogma Transcription & Translation Elongation Engine.
  * **Implementation:** Executes `Genomic_Translation_Kernel` using Exponential Moving Average (EMA) kinetics (translation elongation rate 0.05, proteasomal degradation 0.95). Calculates thermodynamic protein fitness (`Calculate_Thermodynamic_Protein_Fitness`) by evaluating Hamming distance bit-mismatches across locus words relative to wild-type anchors. Simulates oncogenic `CD47` overexpression when repressor locus mutations disrupt transcriptional silencing.

* **[Stochastic.Mutagenesis.Kinematics.cuh](Stochastic.Mutagenesis.Kinematics.cuh) | [Stochastic.Mutagenesis.Kinematics.cu](Stochastic.Mutagenesis.Kinematics.cu)**
  * **Role:** Thermodynamic Genotoxicity & Oxidative Mutagenesis Engine.
  * **Implementation:** Executes `Tissue_Genotoxicity_Kernel` and `Agent_Genotoxicity_Kernel`. Models oxidative DNA damage (bit-flipping via `atomicXor`) driven by Michaelis-Menten ROS saturation kinetics from SASP concentration, tissue structural collapse, agent starvation, and lipotoxicity. Uses continuous locus hit detection (`Detect_Locus_Hit`) to track mutation strikes across coding loci vs. junk DNA.

* **[Genomic.Repair.PARP.cuh](Genomic.Repair.PARP.cuh) | [Genomic.Repair.PARP.cu](Genomic.Repair.PARP.cu)**
  * **Role:** ATP-Dependent DNA Repair & PARP-1 Enzyme Engine.
  * **Implementation:** Executes `Tissue_PARP_Restoration_Kernel` and `Agent_PARP_Restoration_Kernel`. Simulates single-base repair capacity using non-linear Michaelis-Menten ATP kinetics (V_max = 256 bp/epoch, K_m = 30 ATP). Scans genomic loci and restores wild-type bits via `atomicXor`, deducting repair ATP taxes (0.5 ATP per repair) and scanning taxes (0.001 ATP), driving agents into bioenergetic catastrophe when ATP drops below survival thresholds (0.1f).

* **[Thermodynamic.Neural.Network.cuh](Thermodynamic.Neural.Network.cuh) | [Thermodynamic.Neural.Network.cu](Thermodynamic.Neural.Network.cu)**
  * **Role:** Sensorimotor Neural Lattice & Hebbian Plasticity Engine.
  * **Implementation:** Manages an 8 → 2 sensorimotor neural network evaluated via cuBLAS matrix multiplication (`cublasSgemm`) and hyperbolic tangent activation (`Activation_Tanh_Batch_Kernel`). Executes Hebbian synaptic learning (`Hebbian_Plasticity_Kernel`) reinforced by net ATP change gradients, homeostatic synaptic decay (`Entropy_Decay_Kernel`), and spontaneous mEPSP miniature vesicle release noise.

* **[Biophysical.Telemetry.Spooler.cuh](Biophysical.Telemetry.Spooler.cuh) | [Biophysical.Telemetry.Spooler.cu](Biophysical.Telemetry.Spooler.cu)**
  * **Role:** Asynchronous Telemetry Logger & Ring Buffer Disk Spooler.
  * **Implementation:** Performs GPU parallel reductions over populations and fields (`Telemetry_Agent_Reduction_Kernel`, `Telemetry_Tissue_Reduction_Kernel`, `Telemetry_SASP_ATP_Reduction_Kernel`, `Telemetry_Scavenger_Reduction_Kernel`, `Genomic_Proteomic_Reduction_Kernel`). Copies accumulator structures asynchronously to host pinned memory (`BiophysicalAccumulators`) and pushes 89-metric payloads to a lock-free ring buffer (`PreallocatedTelemetryRingBuffer`, capacity 4,194,304 records). A background worker thread spools the data to a dual-chronology CSV file.

* **[SDF.Raymarch.Microscope.h](SDF.Raymarch.Microscope.h) | [SDF.Raymarch.Microscope.cpp](SDF.Raymarch.Microscope.cpp) & [Shader.Payload.h](Shader.Payload.h)**
  * **Role:** DirectX 11 Optical Raymarching Microscope & HLSL Shader Subsystem.
  * **Implementation:** Shares CUDA state buffers with D3D11 textures via CUDA-DirectX interop (`cudaGraphicsMapResources`). Compiles and executes full-screen HLSL pixel shader (`MICROSCOPE_LENS_HLSL`). Calculates signed distance fields (SDF), metaball membrane blending, phase-contrast scattering, Beer-Lambert light attenuation, SNARF-4F ratiometric pH fluorophore color shifts, Alexa Fluor 488 8-oxo-dG damage emissions, and bitwise permutation spatial hashing (`evaluate_photon_noise`) to eliminate Moiré interference artifacts.

* **[Biochemical.Constants.h](Biochemical.Constants.h)**
  * **Role:** Central Biophysical Constants & Parameter Registry.
  * **Implementation:** Header file defining domain dimensions (1024 × 1024), plasma relaxation constants (`PLASMA_TAU = 0.8f`), drag coefficients, Gaussian morphological variances (σ = 3.5 μm for macrophages, σ = 4.5 μm for senescent cells), genomic locus offsets, central dogma epoch durations, Michaelis-Menten kinetic thresholds, and PARP repair constants.

* **[Spatial.Optical.Integration.cuh](Spatial.Optical.Integration.cuh) | [Spatial.Optical.Integration.cu](Spatial.Optical.Integration.cu)**
  * **Role:** Spatial Density Projection & Optical Field Rasterization.
  * **Implementation:** Provides GPU wrappers (`ExecuteSpatialDensityProjection`, `SplatBiochemicalState`, `IntegrateOpticalFields`, `IntegrateOpticalBiochemicalFields`) to project discrete agent positions, `CD47` protein expression, and genomic mutation counts onto continuous 2D spatial grids using Gaussian splatting algorithms.

--------------------------------------------------------------------------------

## Visual & Empirical Validation Portal

Comprehensive visual archives, empirical telemetry dictionaries, and peer-reviewed scientific literature foundations are available to verify the simulation engine:

* **[TelemetryGallery.md:](TelemetryGallery.md)** A visual repository documenting high-resolution captures of the DirectX 11 optical microscope interface, HLSL shader renderings, pH SNARF-4F ratiometric shifts, and 89-metric telemetry visualization dashboards.
* **[BiologicalTelemetryDataset.md:](BiologicalTelemetryDataset.md)** An analytical data dictionary for the 89-column telemetry output generated by the AsynchronousTelemetrySpooler, detailing physical, biological, genomic, and hardware performance metrics across simulation ticks.
* **[ScientificArticlesUsedInZeroSenophage-EN.md:](ScientificArticlesUsedInZeroSenophage-EN.md)** A foundational scientific literature mapping documenting the 86 peer-reviewed articles (indexed via PubMed, PMC, and DOI) that establish the empirical parameters, kinetic constants, and biological mechanisms implemented throughout the C++/CUDA simulation kernels.

--------------------------------------------------------------------------------

## Current Status

The ZeroSenophage simulation engine is operational and demonstrates the following functional capabilities:

* **Stable Dual-Thread Execution:** The physics compute loop and DirectX 11 optical rendering thread operate concurrently at 60 Hz without thread deadlocks or race conditions.
* **Asynchronous Multi-Stream Pipeline:** Executes 5 non-blocking CUDA streams (`compute_stream_fluidics`, `compute_stream_biochemical`, `compute_stream_kinematics`, `compute_stream_genomics`, `compute_stream_telemetry`) coordinated via hardware event synchronization barriers.
* **Decoupled Telemetry Recording:** Spools 89-column dual-chronology records to CSV at high frequency via lock-free ring buffer memory without inducing frame drops in the primary compute loop.
* **Memory Bounds Verification:** Allocates and manages ~8.59 GB VRAM for macromolecular genomic sequences (34,359,738,368 base pairs) within consumer GPU VRAM limits (tested on RTX 3060 12GB).

--------------------------------------------------------------------------------

## Assumptions & Limitations

1. **Spatial Dimension Abstraction:** The simulation matrix is restricted to a 2D 1024 × 1024 continuum domain (1 voxel = 1 μm). This simplifies 3D extracellular matrix architecture, tissue vascularization, and volumetric fluid transport.
2. **Temporal Discretization:** The simulation maps 1 compute epoch (tick) to 1 biological second (Δt = 1/60 s per physics frame). Real-world biological processes (e.g., cell division vs. receptor phosphorylation) span vastly different time scales, which are normalized here via parameterized scalars.
3. **2D Fluid Dynamics Approximations:** Fluid hydrodynamics are solved using a 2D D2Q9 Lattice Boltzmann Method with single-relaxation-time BGK approximation (τ = 0.8). This assumes incompressible plasma flow under low Mach number conditions (< 0.3 c_s).
4. **Genomic Bit-Packing Simplifications:** DNA sequences use 2-bit packing (16 base pairs per `uint32_t` word) compared against a static wild-type anchor (`0xAAAAAAAA`). Higher-order chromatin tertiary structure, histone acetylation, and complex RNA splicing are abstracted into continuous promoter access weights ([0.0, 1.0]).
5. **Heuristic Rate Constants:** Kinetic parameters (e.g., Michaelis-Menten V_max and K_m constants for ROS genotoxicity and PARP repair) are derived from scaled literature values rather than direct, real-time in-vitro measurements.
6. **Pseudo-Random Generator Entropy:** Stochastic events rely on PCG hash algorithms (`Generate_PCG_Hash`) and cuRAND pseudo-random generators. While efficient for parallel GPU execution, these do not represent true quantum or thermal biological entropy.

--------------------------------------------------------------------------------

## Usage / Requirements

**Hardware Requirements:**
* **GPU:** NVIDIA GPU with CUDA Compute Capability 7.0 or higher (e.g., RTX 3060 12GB VRAM or better).
* **RAM:** 16 GB System Memory.
* **Architecture:** x64 Processor.

**Software Dependencies:**
* **Operating System:** Windows 10 / Windows 11 (64-bit).
* **Compiler & IDE:** Microsoft Visual Studio 2026 Community Edition (MSVC C++20 / ISO C++20 Standard).
* **SDKs & Toolkits:** NVIDIA CUDA Toolkit v13.1 / v13.3, DirectX 11 SDK, Windows 10/11 SDK.
* **Libraries:** `d3d11.lib`, `d3dcompiler.lib`, `dxgi.lib`, `cublas.lib`, `curand.lib`, `nvml.lib`.

**Compilation & Build Instructions:**
The project is configured and compiled as a native Visual Studio Solution (`ZeroSenophage.vcxproj`).

1. **Open Solution:** Launch **Visual Studio 2026 Community Edition** and open `ZeroSenophage.sln` (or import `ZeroSenophage.vcxproj`).
2. **Set Target Configuration:** Set build configuration to **Release** and platform to **x64**.
3. **Rebuild Project:** Select **Build > Rebuild Solution** (or press `Ctrl+Shift+B`).
   * Visual Studio invokes `nvcc.exe` (NVIDIA CUDA Toolkit v13.1 / v13.3) targeting compute architecture `sm_86` with fast-math optimizations (`--use_fast_math`, `-Xptxas -dlcm=cg`, `-std=c++20`).
4. **Execution:** Run `ZeroSenophage.exe` generated in `x64/Release/ZeroSenophage.exe` or launch directly via **Local Windows Debugger** in Visual Studio.

--------------------------------------------------------------------------------
