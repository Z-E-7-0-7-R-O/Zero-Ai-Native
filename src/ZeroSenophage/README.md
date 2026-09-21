### ZeroSenophage: GPU-Accelerated Thermodynamic Kinematics & Genomic Senolytic Simulator
<div align="center">
  <i>A computational framework for simulating time-dependent cellular dynamics and tumor microenvironment equilibrium.</i>
  <br><br>
  <b>Developer:</b> Zero-AI-Native (Age 15, assisted by Google Gemini 3.1 Pro) <br>
  <b>Architecture:</b> CUDA C++ / DirectX 11 / Computational Biophysics<br>
  <b>Status:</b> Concept / Simulation Deployed
</div>

--------------------------------------------------------------------------------

#### Overview

ZeroSenophage is a GPU-accelerated computational biophysics engine designed to model time-dependent cell kinetics, fluid dynamics, biochemical gradient transport, macromolecular genomic mutations, and autonomous senolytic phagocytosis within a simulated tissue microenvironment. The simulator operates on a 2D $1024 \times 1024$ continuum matrix domain ($1\ \text{voxel} = 1\ \mu\text{m}$) containing three distinct cellular populations: hypertrophic senescent cells ("zombie cells"), engineered senolytic agents ("senophages"), and resident scavenger macrophages.

Rather than utilizing pre-scripted state transitions, ZeroSenophage evaluates cellular dynamics via coupled physical solvers and stochastic CUDA kernels:
1. **Lattice Boltzmann Plasma Hydrodynamics (D2Q9 BGK Model):** Simulates interstitial fluid advection and kinematic viscosity ($\tau = 0.8$) at $37^\circ\text{C}$.
2. **PDE Reaction-Diffusion Fields:** Solves 2D partial differential equations for Senescence-Associated Secretory Phenotype (SASP) cytokines and extracellular ATP gradients using 9-point Laplacian stencils and sub-pixel advection.
3. **Autonomous Kinematics & Efferotabolism:** Models agent motility via Lévy walk foraging trajectories, Hebbian neural drive, actin protrusive thrust, CD47-SIRPα signaling inhibition, trogoptosis, macropinocytosis, fatty acid $\beta$-oxidation, ABCA1 cholesterol efflux, and lipotoxicity ER stress.
4. **Macromolecular 64-Bit VRAM Genomics:** Allocates 8.59 GB of VRAM storing $34,359,738,368$ total base pairs ($104,120,416$ bp per agent across 330 initial agents) using 2-bit nucleotide packing (16 bp per `uint32_t` word).
5. **Central Dogma & Epigenetics:** Simulates continuous promoter DNA methylation weights ($[0.0, 1.0]$) and Exponential Moving Average (EMA) protein translation/degradation kinetics for $ACTB$, $CD47$, $SIRPA$, $P2RY2$, and $ABCA1$ loci.
6. **Thermodynamic Mutagenesis & PARP-1 Repair:** Evaluates Michaelis-Menten ROS oxidative bit-flipping and ATP-dependent PARP-1 single-base restoration, tracking exact locus mutation hits.
7. **DirectX 11 Raymarching Microscope:** Renders sub-pixel physical optics, phase-contrast halos, SNARF-4F ratiometric pH fluorophores, Alexa Fluor 488 $8\text{-oxo-dG}$ damage emissions, and bitwise permutation spatial hashing to eliminate Moiré artifacts.

--------------------------------------------------------------------------------

#### Senophage Dual Mechanism & Pre-Neoplastic Interception Barrier

In computational oncology and biophysics, senescent cells are recognized not merely as inert, non-dividing "zombie cells," but as active drivers of tissue microenvironment degradation. Persistent senescent cells continuously secrete a complex cocktail of pro-inflammatory cytokines, chemokines, extracellular matrix-degrading proteases, and reactive oxygen species (ROS)—collectively termed the Senescence-Associated Secretory Phenotype (SASP). 

Chronic SASP exposure induces paracrine senescence (bystander senescence) in healthy adjacent cells and creates a highly genotoxic microenvironment. The sustained ROS bombardment induces double-strand DNA breaks, base modifications, and oncogenic mutation accumulation (such as mutations in $CD47$ repressor loci), eventually driving pre-neoplastic cellular transformation and tumorigenesis.

The engineered **Senophage** agents in ZeroSenophage operate through a dual therapeutic mechanism:

1. **Senolytic Clearance & Phagocytic Engagement:**
   Under baseline physiological conditions, senescent cells upregulate the CD47 "don't eat me" surface protein, which binds the SIRPα receptor on wild-type macrophages and inhibits actomyosin cup formation. Engineered Senophages feature an absolute epigenetic knockout of the $SIRPA$ gene (`sirpa_weight = 0.0f`), rendering them immune to CD47 evasion signals. Upon locating senescent targets via SASP gradient sensing, Senophages execute cooperative swarming, trogocytosis membrane nibbling, and trogoptosis acceleration to clear senescent tissue mass.

2. **Pre-Neoplastic Interception Barrier:**
   By aggressively engulfing senescent cells early in their hypertrophic phase, Senophages eliminate the primary biochemical source of paracrine SASP and ROS bombardment. By suppressing the local ROS flux below the Michaelis-Menten genotoxicity saturation threshold ($K_m = 2500.0$), Senophages prevent bystander DNA mutation accumulation in neighboring healthy cells. This intercepts tumorigenesis at the pre-neoplastic stage, neutralizing the microenvironmental driver of cancer before neoplastic transformation occurs.

--------------------------------------------------------------------------------

#### Technical Details / Architecture

All core mathematical models, CUDA execution kernels, biophysical solvers, and shader payloads are open for technical audit and verification.

**Source Code Modules & Engine Components:**

* **[Zero.Nucleus.cpp](Zero.Nucleus.cpp)**
  * **Role:** Application Entry Point & High-Precision System Lifecycle Manager.
  * **Implementation:** Overrides OS display scaling using `SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)` to enforce 1:1 hardware pixel mapping and eradicate DWM bilinear stretching. Manages window creation (`AdjustWindowRect` for $1024 \times 1024$ client area) and spawns a dedicated high-priority physics thread (`ThermodynamicComputeThread`). Implements death-spiral accumulator clamping (`max_accumulator_threshold = 3 * dt`) to prevent physics stalls upon OS wake, and executes hybrid spin-yield pacing to lock optical rendering strictly to 60 Hz.

* **[Matrix.Orchestrator.h](Matrix.Orchestrator.h) | [Matrix.Orchestrator.cpp](Matrix.Orchestrator.cpp)**
  * **Role:** Asynchronous Subsystem Orchestrator & Multi-Stream CUDA Pipeline Manager.
  * **Implementation:** Instantiates and coordinates all CUDA compute environments (`ComputationalFluidDynamicsEnvironment`, `ReactionDiffusionField`, `MacromolecularGenomicEnvironment`, `EpigeneticPromoterRegistry`, `ProteomicExpressionState`, `CentralDogmaEngine`, `ThermodynamicMutagenesisEngine`, `ThermodynamicPARPRepairEngine`, and agent populations). Manages 5 non-blocking CUDA streams (`compute_stream_fluidics`, `compute_stream_biochemical`, `compute_stream_kinematics`, `compute_stream_genomics`, `compute_stream_telemetry`) with CUDA event cross-stream synchronization barriers. Manages triple-buffered render state pools (`BiophysicalRenderState state_pool[3]`) for lock-free compute-render exchange. Interrogates hardware status via NVML (`nvmlDeviceGetTemperature`, `nvmlDeviceGetClockInfo`).

* **[Autonomous.Senolytic.Population.cuh](Autonomous.Senolytic.Population.cuh) | [Autonomous.Senolytic.Population.cu](Autonomous.Senolytic.Population.cu)**
  * **Role:** Cellular Agent Kinematics, Phagocytic Synapse & Efferotabolism Engine.
  * **Implementation:** Defines `SenescentCellPopulation` and `AutonomousSenolyticAgentPopulation` using ping-pong double buffering (`d_pos_x_current`, `d_pos_x_next`, `d_atp_level_current`, `d_lipid_burden_current`, etc.). Executes four specialized CUDA kernels:
    * `Tissue_Secretion_Kernel`: Evaluates local senophage/scavenger densities, CD47-SIRPα inhibitory receptor shielding, cooperative swarming synergy, phagocytic cup formation, macropinocytosis, trogocytosis nibbling, trogoptosis secondary necrosis acceleration, and in-situ stochastic cell turnover using PCG hashing (`Generate_PCG_Hash`).
    * `Senescent_Tissue_Kinematics_Kernel`: Simulates senescent cell evasion vectors derived from density gradients and persistent random walk (PRW) motility.
    * `Read_Olfactory_Sensors_Kernel`: Processes 8-directional SASP concentration sampling with receptor desensitization (fatigue accumulation), lateral inhibition, and P2RY2 receptor expression scaling.
    * `Autonomous_Agent_Kinematics_Kernel`: Executes 256-thread-per-agent block reductions. Calculates steric inter-agent repulsion, Lévy walk heavy-tailed stochastic search steps (`clamped_levy`), actin protrusive thrust vectors scaled by $ACTB$ protein levels, Hebbian motor drive, drag reduction upon integrin target commitment, fatty acid $\beta$-oxidation ATP regeneration, ABCA1 cholesterol efflux pumping, lipotoxicity ER stress (Hill function), starvation autophagy energy reserve, and Peskin immersed-boundary fluid force injection (`ext_fx`, `ext_fy`).

* **[Lattice.Boltzmann.Plasma.cuh](Lattice.Boltzmann.Plasma.cuh) | [Lattice.Boltzmann.Plasma.cu](Lattice.Boltzmann.Plasma.cu)**
  * **Role:** Interstitial Plasma Computational Fluid Dynamics (CFD) Environment.
  * **Implementation:** Implements a 2D D2Q9 Lattice Boltzmann Method (LBM) solver using the Bhatnagar-Gross-Krook (BGK) collision operator. Sets plasma relaxation time `PLASMA_TAU = 0.8f` to match blood plasma kinematic viscosity at $37^\circ\text{C}$. Calculates local density $\rho$ and velocity vectors ($u_x, u_y$), applying hyperbolic tangent velocity clamping (`tanhf`) to enforce speed-of-sound Mach limits ($< 0.3 c_s$) and injecting Brownian stochastic forcing.

* **[Reaction.Diffusion.SASP.cuh](Reaction.Diffusion.SASP.cuh) | [Reaction.Diffusion.SASP.cu](Reaction.Diffusion.SASP.cu)**
  * **Role:** Biochemical Signaling Field & Partial Differential Equation Solver.
  * **Implementation:** Manages 2D grid fields (`d_sasp_concentration`, `d_atp_concentration`). Executes `PDE_Reaction_Diffusion_Kernel` to solve advection-diffusion-reaction equations using an 8-neighbor discrete 9-point Laplacian operator, sub-pixel bilinear interpolation from LBM fluid velocity vectors ($u_x, u_y$), toroidal boundary modulo wrapping, natural chemical decay, and cellular endocytosis clearance sinks.

* **[Macromolecular.Genomic.Allocation.cuh](Macromolecular.Genomic.Allocation.cuh) | [Macromolecular.Genomic.Allocation.cu](Macromolecular.Genomic.Allocation.cu)**
  * **Role:** 64-Bit VRAM Macromolecular Genomic Storage Manager.
  * **Implementation:** Allocates $2,147,483,580$ `uint32_t` words (~8.59 GB VRAM) storing $34,359,738,368$ total base pairs across the ecosystem ($104,120,416$ bp per agent across 330 initial agents). Employs 2-bit nucleotide bit-packing (16 base pairs per `uint32_t` word). Executes `Stochastic_Heterochromatin_Seeding_Kernel` for background heterochromatin initialization and `WildType_CodingSequence_Implantation_Kernel` to write wild-type stability patterns (`0xAAAAAAAA`) at specific loci ($ACTB$, $CD47$, $CD47\text{\_REPRESSOR}$, $SIRPA$, $P2RY2$, $ABCA1$).

* **[Epigenetic.Promoter.Indexing.cuh](Epigenetic.Promoter.Indexing.cuh) | [Epigenetic.Promoter.Indexing.cu](Epigenetic.Promoter.Indexing.cu)**
  * **Role:** Epigenetic Methylome Indexing & Promoter Access Control.
  * **Implementation:** Maintains continuous float arrays (`d_epigenetic_weight_ACTB`, `d_epigenetic_weight_CD47`, `d_epigenetic_weight_SIRPA`, `d_epigenetic_weight_P2RY2`, `d_epigenetic_weight_ABCA1`) representing promoter access weights ($[0.0, 1.0]$). Initializes cell-type specific methylomes: fully opens $CD47$ in senescent cells while methylating receptors; executes genetic/epigenetic knockout of $SIRPA$ in senophages to prevent CD47-mediated evasion; and opens $P2RY2$ and $ABCA1$ euchromatin in scavenger macrophages.

* **[Proteomic.Expression.State.cuh](Proteomic.Expression.State.cuh) | [Proteomic.Expression.State.cu](Proteomic.Expression.State.cu)**
  * **Role:** Proteomic Expression Tensor Storage & Buffer Management.
  * **Implementation:** Manages double-buffered current ($T$) and next ($T+1$) float tensors for protein expression levels of $ACTB$, $CD47$, $SIRPA$, $P2RY2$, and $ABCA1$. Executes zero-cost GPU pointer swapping (`SwapStates`) to bypass VRAM copy bandwidth overhead.

* **[Central.Dogma.Transcription.cuh](Central.Dogma.Transcription.cuh) | [Central.Dogma.Transcription.cu](Central.Dogma.Transcription.cu)**
  * **Role:** Central Dogma Transcription & Translation Elongation Engine.
  * **Implementation:** Executes `Genomic_Translation_Kernel` using Exponential Moving Average (EMA) kinetics (translation elongation rate $0.05$, proteasomal degradation $0.95$). Calculates thermodynamic protein fitness (`Calculate_Thermodynamic_Protein_Fitness`) by evaluating Hamming distance bit-mismatches across locus words relative to wild-type anchors. Simulates oncogenic $CD47$ overexpression when repressor locus mutations disrupt transcriptional silencing.

* **[Stochastic.Mutagenesis.Kinematics.cuh](Stochastic.Mutagenesis.Kinematics.cuh) | [Stochastic.Mutagenesis.Kinematics.cu](Stochastic.Mutagenesis.Kinematics.cu)**
  * **Role:** Thermodynamic Genotoxicity & Oxidative Mutagenesis Engine.
  * **Implementation:** Executes `Tissue_Genotoxicity_Kernel` and `Agent_Genotoxicity_Kernel`. Models oxidative DNA damage (bit-flipping via `atomicXor`) driven by Michaelis-Menten ROS saturation kinetics from SASP concentration, tissue structural collapse, agent starvation, and lipotoxicity. Uses continuous locus hit detection (`Detect_Locus_Hit`) to track mutation strikes across coding loci vs. junk DNA.

* **[Genomic.Repair.PARP.cuh](Genomic.Repair.PARP.cuh) | [Genomic.Repair.PARP.cu](Genomic.Repair.PARP.cu)**
  * **Role:** ATP-Dependent DNA Repair & PARP-1 Enzyme Engine.
  * **Implementation:** Executes `Tissue_PARP_Restoration_Kernel` and `Agent_PARP_Restoration_Kernel`. Simulates single-base repair capacity using non-linear Michaelis-Menten ATP kinetics ($V_{\max} = 256$ bp/epoch, $K_m = 30$ ATP). Scans genomic loci and restores wild-type bits via `atomicXor`, deducting repair ATP taxes ($0.5$ ATP per repair) and scanning taxes ($0.001$ ATP), driving agents into bioenergetic catastrophe when ATP drops below survival thresholds ($0.1\text{f}$).

* **[Thermodynamic.Neural.Network.cuh](Thermodynamic.Neural.Network.cuh) | [Thermodynamic.Neural.Network.cu](Thermodynamic.Neural.Network.cu)**
  * **Role:** Sensorimotor Neural Lattice & Hebbian Plasticity Engine.
  * **Implementation:** Manages an $8 \to 2$ sensorimotor neural network evaluated via cuBLAS matrix multiplication (`cublasSgemm`) and hyperbolic tangent activation (`Activation_Tanh_Batch_Kernel`). Executes Hebbian synaptic learning (`Hebbian_Plasticity_Kernel`) reinforced by net ATP change gradients, homeostatic synaptic decay (`Entropy_Decay_Kernel`), and spontaneous mEPSP miniature vesicle release noise.

* **[Biophysical.Telemetry.Spooler.cuh](Biophysical.Telemetry.Spooler.cuh) | [Biophysical.Telemetry.Spooler.cu](Biophysical.Telemetry.Spooler.cu)**
  * **Role:** Asynchronous Telemetry Logger & Ring Buffer Disk Spooler.
  * **Implementation:** Performs GPU parallel reductions over populations and fields (`Telemetry_Agent_Reduction_Kernel`, `Telemetry_Tissue_Reduction_Kernel`, `Telemetry_SASP_ATP_Reduction_Kernel`, `Telemetry_Scavenger_Reduction_Kernel`, `Genomic_Proteomic_Reduction_Kernel`). Copies accumulator structures asynchronously to host pinned memory (`BiophysicalAccumulators`) and pushes 89-metric payloads to a lock-free ring buffer (`PreallocatedTelemetryRingBuffer`, capacity $4,194,304$ records). A background worker thread spools the data to a dual-chronology CSV file.

* **[SDF.Raymarch.Microscope.h](SDF.Raymarch.Microscope.h) | [SDF.Raymarch.Microscope.cpp](SDF.Raymarch.Microscope.cpp) & [Shader.Payload.h](Shader.Payload.h)**
  * **Role:** DirectX 11 Optical Raymarching Microscope & HLSL Shader Subsystem.
  * **Implementation:** Shares CUDA state buffers with D3D11 textures via CUDA-DirectX interop (`cudaGraphicsMapResources`). Compiles and executes full-screen HLSL pixel shader (`MICROSCOPE_LENS_HLSL`). Calculates signed distance fields (SDF), metaball membrane blending, phase-contrast scattering, Beer-Lambert light attenuation, SNARF-4F ratiometric pH fluorophore color shifts, Alexa Fluor 488 $8\text{-oxo-dG}$ damage emissions, and bitwise permutation spatial hashing (`evaluate_photon_noise`) to eliminate Moiré interference artifacts.

* **[Biochemical.Constants.h](Biochemical.Constants.h)**
  * **Role:** Central Biophysical Constants & Parameter Registry.
  * **Implementation:** Header file defining domain dimensions ($1024 \times 1024$), plasma relaxation constants (`PLASMA_TAU = 0.8f`), drag coefficients, Gaussian morphological variances ($\sigma = 3.5\ \mu\text{m}$ for macrophages, $\sigma = 4.5\ \mu\text{m}$ for senescent cells), genomic locus offsets, central dogma epoch durations, Michaelis-Menten kinetic thresholds, and PARP repair constants.

* **[Spatial.Optical.Integration.cuh](Spatial.Optical.Integration.cuh) | [Spatial.Optical.Integration.cu](Spatial.Optical.Integration.cu)**
  * **Role:** Spatial Density Projection & Optical Field Rasterization.
  * **Implementation:** Provides GPU wrappers (`ExecuteSpatialDensityProjection`, `SplatBiochemicalState`, `IntegrateOpticalFields`, `IntegrateOpticalBiochemicalFields`) to project discrete agent positions, $CD47$ protein expression, and genomic mutation counts onto continuous 2D spatial grids using Gaussian splatting algorithms.

--------------------------------------------------------------------------------

#### Visual & Empirical Validation Portal

Comprehensive visual data, peer-reviewed literature mappings, and empirical datasets are provided to verify the engine's biophysical models, GPU execution stability, and optical shader accuracy.

* **[ScientificArticlesUsedInZeroSenophage-EN.md](ScientificArticlesUsedInZeroSenophage-EN.md):**  
  A dedicated peer-reviewed scientific literature directory documenting the **86 academic articles** (from PubMed, PMC, and DOI databases) utilized to ground and calibrate the biophysical constants of ZeroSenophage. This includes empirical velocity ranges ($0.78 \text{ to } 1.02\ \mu\text{m/min}$ for macrophages, $1.6\ \mu\text{m/min}$ for senescent cells), cytokine diffusion coefficients ($10 - 15\ \mu\text{m}^2\text{/s}$), plasma kinematic viscosity at $37^\circ\text{C}$ ($\tau = 0.8$), CD47-SIRPα phagocytic cup inhibition, and SNARF-4F/Alexa Fluor 488 optical emission spectra.

* **[TelemetryGallery](TelemetryGallery.md):**  
  A visual repository containing high-resolution captures of the DirectX 11 optical raymarching microscope during operation, documenting system state transitions across tracked biophysical variables, phase-contrast halos, SNARF-4F pH ratiometric shifts, and GPU hardware utilization.

* **[BiologicalTelemetryDataset](BiologicalTelemetryDataset.md):**  
  An analytical dictionary and data specification for the **89-column CSV telemetry output** generated asynchronously by `AsynchronousTelemetrySpooler`. Details all recorded parameters including dual-chronology timestamps, active genomic pool sizes, PARP-1 repair tax, FAO ATP yields, and WDDM memory eviction penalties.

--------------------------------------------------------------------------------

#### Current Status

The ZeroSenophage simulator is fully operational in CUDA C++ / DirectX 11 environments. The physics compute thread (`ThermodynamicComputeThread`) and optical rendering loop run asynchronously without deadlock. The 5 non-blocking CUDA streams execute parallel pipeline stages, and the `AsynchronousTelemetrySpooler` streams 89 biophysical metrics per epoch to disk via a lock-free ring buffer without introducing UI latency or frame drops.

--------------------------------------------------------------------------------

#### Assumptions & Limitations

To evaluate this simulator within an engineering framework, the following technical abstractions and biological limitations must be explicitly noted:

1. **2D Spatial Dimension Limitation:**  The tissue continuum matrix is currently simulated on a 2D $1024 \times 1024$ voxel domain ($1\ \text{voxel} = 1\ \mu\text{m}$). While 2D toroidal boundary wrapping allows continuous flux, real-world tissue microenvironments operate in 3D viscoelastic extracellular matrix structures.
2. **Temporal Mapping Equivalence:**  The simulator equates $1\ \text{epoch tick}$ to $1\ \text{second}$ of biological time. While physical transport equations (diffusion rates, viscosity) are calibrated to $37^\circ\text{C}$ per-second constants, long-term cellular turnover speeds are scaled by heuristic multipliers to accommodate GPU execution bounds.
3. **2-Bit Nucleotide Bit-Packing Abstraction:**  Genomic storage compresses base pairs into 2-bit representations ($A=00, C=01, G=10, T=11$). While this enables $34.3+\text{ billion base pairs}$ to reside in 8.59 GB VRAM, it abstracts away complex 3D chromatin folding, histone tail modifications, and non-coding structural RNA loops.
4. **Epigenetic Promoters as Continuous Floats:**  Promoter methylation state is represented as a continuous scalar $[0.0, 1.0]$. In biological systems, methylation involves discrete CpG island methylation patterns and histone acetylation kinetics.
5. **Pseudo-Random Number Generators (PRNG):**  Stochastic events (mutagenesis bit-flips, Brownian forcing, Lévy walk angles) rely on PCG hash algorithms (`Generate_PCG_Hash`). While computationally efficient on CUDA architectures, PRNGs represent mathematical approximations of true biological quantum entropy.

--------------------------------------------------------------------------------

#### Usage / How to Run

1. **System Requirements:**
   * **OS:** Windows 10 / 11 64-bit.
   * **GPU:** NVIDIA GPU with DirectX 11 support and Compute Capability 7.0+ (Tested on RTX 3060 12GB VRAM).
   * **Compiler & Toolchain:** Microsoft Visual Studio 2022 (MSVC C++17), NVIDIA CUDA Toolkit 12.x, Windows SDK 10.0.

2. **Compilation Steps:**
   ```bash
   # Open Visual Studio x64 Native Tools Command Prompt
   # Compile CUDA kernels and C++ host code
   nvcc -O3 -arch=sm_86 -std=c++17         Zero.Nucleus.cpp Matrix.Orchestrator.cpp SDF.Raymarch.Microscope.cpp         Autonomous.Senolytic.Population.cu Lattice.Boltzmann.Plasma.cu         Reaction.Diffusion.SASP.cu Macromolecular.Genomic.Allocation.cu         Epigenetic.Promoter.Indexing.cu Proteomic.Expression.State.cu         Central.Dogma.Transcription.cu Stochastic.Mutagenesis.Kinematics.cu         Genomic.Repair.PARP.cu Thermodynamic.Neural.Network.cu         Biophysical.Telemetry.Spooler.cu Spatial.Optical.Integration.cu         -o ZeroSenophage.exe         -lcudart -lcublas -lcurand -lnvml -ld3d11 -ld3dcompiler -ldxgi -luser32 -lgdi32
   ```

3. **Execution:**
   ```bash
   ./ZeroSenophage.exe
   ```

--------------------------------------------------------------------------------
