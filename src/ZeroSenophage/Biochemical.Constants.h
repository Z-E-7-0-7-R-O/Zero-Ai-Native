#ifndef BIOCHEMICAL_CONSTANTS_H
#define BIOCHEMICAL_CONSTANTS_H

#include <cstdint>

namespace BiophysicalConstants {
    // Spatial dimensions of the computational grid
    // Scale Calibration: 1 Voxel = 1 Micrometer (um)
    static const int ENVIRONMENT_WIDTH = 1024;
    static const int ENVIRONMENT_HEIGHT = 1024;
    static const int ENVIRONMENT_TOTAL_VOXELS = ENVIRONMENT_WIDTH * ENVIRONMENT_HEIGHT;

    // Thermodynamic fluid constants (Lattice Boltzmann Method)
    // Calibrated for blood plasma kinematic viscosity at 37°C ensuring strict Mach limit stability
    static constexpr float PLASMA_TAU = 0.8f;
    static constexpr float PLASMA_VISCOSITY = (PLASMA_TAU - 0.5f) / 3.0f;

    // Biological entropy and kinetic constants
    static constexpr float ATP_DECAY_ENTROPY = 0.001f;
    static constexpr float SASP_DIFFUSION_RATE = 0.20f;

    // Membrane and rendering constants
    static constexpr float CELL_MEMBRANE_SMOOTHNESS = 4.0f;

    // Phase 33: Kinematic and Viscoelastic Constants for Low Reynolds Number Environment
    static constexpr float KINEMATIC_INERTIA = 0.20f;       // Cell scale inertia is heavily dampened by fluid
    static constexpr float KINEMATIC_DRAG = 0.96f;          // Adjusted continuous fluid friction
    static constexpr float ACTIN_BASAL_THRUST = 0.05f;      // Minimum protrusive force to break static friction
    static constexpr float MAX_LEVY_JUMP = 0.5f;            // Physiological limit to structural displacement

    // Phase 46: Parameterized Motility Vectors
    static constexpr float SENOPHAGE_MOTILITY_SPEED = 0.15f;            // Aggressive continuous pursuit vector
    static constexpr float MACROPHAGE_SCAVENGER_MOTILITY_SPEED = 0.08f; // Kinematic equivalent to 1-10 um/min In-Vitro

    // Phase 44, 46, 47 & 53: Efferotabolism, Lipid Toxicity, ABCA1 Efflux, FAO Kinetics & Autophagic Equilibrium
    static constexpr float EFFEROCYTOSIS_LIPID_INFLUX_RATE = 5.0f;     // Basal lipids generated per unit of ingested tissue
    static constexpr float MACROPINOCYTOSIS_LIPID_YIELD = 150.0f;      // Phase 47: Bulk lipid influx from Apoptotic Bodies
    static constexpr float MITOCHONDRIAL_FAO_RATE = 0.8f;              // Fatty Acid Oxidation rate
    static constexpr float MITOCHONDRIAL_FAO_ATP_YIELD = 25.0f;        // ATP generated per unit of oxidized lipid
    static constexpr float ABCA1_CHOLESTEROL_EFFLUX_RATE = 1.2f;       // Rate at which ABCA1 pumps toxic lipids out
    static constexpr float ABCA1_ATP_COST = 0.5f;                      // Energy cost of the efflux pump per unit lipid pumped
    static constexpr float LIPID_TOXICITY_THRESHOLD = 500.0f;          // Saturation point where UPR/ER stress paralyzes the macrophage
    static constexpr float AUTOPHAGY_RESERVE_THRESHOLD = 25.0f;        // Phase 53: ATP boundary where autophagy perfectly balances expenditure

    // Phase 54: Trogoptosis, Scavenger Trogocytosis, and Phagocytic Commitment
    static constexpr float TROGOPTOSIS_ACTIVATION_THRESHOLD = 0.60f;   // Integrity point where structural collapse begins exponentially
    static constexpr float TROGOPTOSIS_COLLAPSE_RATE = 0.015f;         // Multiplier for exponential secondary necrosis
    static constexpr float SCAVENGER_TROGOCYTOSIS_RATE = 0.01f;        // Rate of nibbling by hovering scavengers
    static constexpr float STRUCTURAL_FOOTPRINT_MIN = 0.05f;           // Preserves physical volume at lower integrities preventing phantom slipping

    // Phase 52: Cooperative Phagocytosis and Swarming Synergy Constants
    static constexpr float COOPERATIVE_SWARM_BASE_DENSITY = 1.0f;
    static constexpr float COOPERATIVE_SWARM_PEAK_DENSITY = 5.0f;
    static constexpr float COOPERATIVE_SYNERGY_MULTIPLIER = 1.5f;

    // Morphological Differentiation: Autonomous Senolytic Agents (Macrophages)
    static constexpr float MACROPHAGE_GAUSSIAN_SIGMA = 3.5f;
    static constexpr float MACROPHAGE_GAUSSIAN_SIGMA_SQ = 12.25f;
    static const int MACROPHAGE_SPLAT_RADIUS = 22;

    // Morphological Differentiation: Senescent Cells (Zombie Cells)
    static constexpr float SENESCENT_GAUSSIAN_SIGMA = 4.5f;
    static constexpr float SENESCENT_GAUSSIAN_SIGMA_SQ = 20.25f;
    static const int SENESCENT_SPLAT_RADIUS = 13; // 3 * Sigma cover

    // Phase 41: Senescent Cell Motility (1.6 um/min = 0.026 um/s) -> Kinematic scalar
    static constexpr float SENESCENT_BASAL_MOTILITY = 0.026f;

    // ====================================================================================================
    // Phase 91: Re-calibrated Digestion and Thermodynamic Tax Constants
    // Restoring the law of conservation of mass and energy across the Phagocytic Synapse
    // ====================================================================================================

    static constexpr float MACROPHAGE_DIGESTION_RATE = 0.015f;         // Boosted from 0.00015f to resolve Phagocytic Deadlock
    static constexpr float PHAGOCYTIC_CUP_BASE_ATP_TAX = 4.5f;         // High peak cost when dynamically expanding the actin scaffold
    static constexpr float PHAGOCYTIC_CUP_MAINTENANCE_TAX = 0.5f;      // Low resting cost when fully locked onto the target
    static constexpr float IMMEDIATE_DIGESTION_ATP_YIELD = 15.0f;      // Immediate thermodynamic reward preventing in-situ starvation

    // ====================================================================================================
    // Phase 55: Macromolecular Genomic Architecture & 64-Bit VRAM Allocation
    // ====================================================================================================

    static constexpr size_t GENOMICS_TOTAL_WORDS = 2147483580ULL;
    static constexpr size_t GENOMICS_WORDS_PER_AGENT = 6507526ULL; // Equals 104,120,416 Base Pairs per Agent

    static constexpr unsigned long long GENOMICS_TOTAL_BASE_PAIRS = 34359738368ULL;
    static const int TOTAL_ECOSYSTEM_AGENTS_INITIALIZED = 330;

    static constexpr size_t LOCUS_OFFSET_ACTB = 1000ULL;
    static constexpr size_t LOCUS_OFFSET_CD47 = 10000ULL;
    static constexpr size_t LOCUS_OFFSET_SIRPA = 20000ULL;
    static constexpr size_t LOCUS_OFFSET_P2RY2 = 30000ULL;
    static constexpr size_t LOCUS_OFFSET_ABCA1 = 50000ULL;

    static constexpr size_t LOCUS_LENGTH_ACTB = 332ULL;     // ~5,300 Base Pairs
    static constexpr size_t LOCUS_LENGTH_CD47 = 3125ULL;    // ~50,000 Base Pairs
    static constexpr size_t LOCUS_LENGTH_SIRPA = 2812ULL;   // ~45,000 Base Pairs
    static constexpr size_t LOCUS_LENGTH_P2RY2 = 1129ULL;   // 18,054 Base Pairs
    static constexpr size_t LOCUS_LENGTH_ABCA1 = 9125ULL;   // ~146,000 Base Pairs

    // ====================================================================================================
    // Phase 57: Central Dogma Engine & Transcription Kinematics
    // ====================================================================================================

    static constexpr unsigned long long CENTRAL_DOGMA_EPOCH = 100ULL;
    static constexpr float MUTATION_SENSITIVITY_SCALAR = 15.0f;

    // ====================================================================================================
    // Phase 84: Thermodynamic Mutagenesis via Michaelis-Menten Saturation Kinetics
    // Eradicates hardware freezing by replacing linear infinite growth with asymptotic biological limits.
    // ====================================================================================================

    static constexpr unsigned long long MUTAGENESIS_EPOCH = 50ULL;

    // SASP-induced ROS Kinetics
    static constexpr float ROS_VMAX_SASP = 1024.0f;           // Maximum discrete bit-flips per epoch allowed by receptor saturation
    static constexpr float ROS_KM_SASP = 2500.0f;             // SASP concentration where genotoxicity reaches exactly half of VMAX

    // Endogenous Starvation-induced ROS Kinetics
    static constexpr float ROS_VMAX_METABOLIC = 512.0f;       // Maximum endogenous oxidative stress from mitochondrial failure
    static constexpr float ROS_KM_METABOLIC = 20.0f;          // Starvation proxy concentration for half-max stress

    // Lipotoxicity-induced ROS Kinetics (ER Stress)
    static constexpr float ROS_VMAX_LIPOTOXICITY = 1024.0f;   // Severe genotoxicity limit from lipid overload
    static constexpr float ROS_KM_LIPOTOXICITY = 300.0f;      // Lipid burden threshold for half-max lipotoxic stress

    // Structural Collapse-induced ROS Kinetics
    static constexpr float ROS_VMAX_STRUCTURAL = 512.0f;      // Stress from membrane integrity failure
    static constexpr float ROS_KM_STRUCTURAL = 0.40f;         // Integrity loss threshold for half-max stress

    // ====================================================================================================
    // Phase 84: ATP-Dependent DNA Repair Mechanisms & PARP Activation via Non-Linear Kinetics
    // ====================================================================================================

    static constexpr unsigned long long PARP_REPAIR_EPOCH = 50ULL;

    // Michaelis-Menten repair capacity ensures asymptotic degradation of repair efficiency as energy drops
    static constexpr float PARP_VMAX_REPAIR = 256.0f;         // Absolute max base pairs PARP can restore per epoch at infinite ATP
    static constexpr float PARP_KM_ATP = 30.0f;               // ATP level where PARP engine operates at exactly 50% capacity
    static constexpr float PARP_KM_INTEGRITY = 0.40f;         // Integrity proxy for tissue cell repair capacity

    static constexpr float PARP_REPAIR_ATP_COST = 0.5f;       // Lethal thermodynamic cost deducted per successful bit restoration
    static constexpr float PARP_SCANNING_ATP_COST = 0.001f;   // Minimal basal cost for sliding across healthy DNA sequences

    // ====================================================================================================
    // Phase 61: Emergence of Oncogenic Phenotypes and Mutational Immortality
    // ====================================================================================================

    static constexpr float MAX_ONCOGENIC_OVEREXPRESSION = 5.0f;
    static constexpr size_t LOCUS_OFFSET_CD47_REPRESSOR = 9500ULL;
    static constexpr size_t LOCUS_LENGTH_CD47_REPRESSOR = 31ULL; // ~500 Base pairs

    // ====================================================================================================
    // Phase 78: Hardware Constraints, 64-bit Migrations & Asynchronous Pipeline Architectures
    // ====================================================================================================

    static constexpr size_t TELEMETRY_BUFFER_SIZE = 128ULL;
    static constexpr int BLOCK_PER_AGENT_THREADS = 256;
}

#endif // BIOCHEMICAL_CONSTANTS_H