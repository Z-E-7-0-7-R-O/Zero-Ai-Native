/**
 * @file Cell.h
 * @brief Autonomous Biological Cell Unit (Phase 63: The Symbiotic Treaty & Intrinsic Overdrive)
 * @note [SECURE SKELETON: EDUCATIONAL & RESEARCH BIO-SIMULATION ONLY]
 */

#pragma once

#include <atomic>
#include <mutex>
#include <memory>
#include <cstdint>
#include "AI_Director/NatureDirector.h" 

#ifndef __CUDACC__
#include <optional>
#endif

#ifdef __CUDACC__
#define ZCR_HD __host__ __device__
#else
#define ZCR_HD
#endif

namespace ZeroCancerReactor {
    namespace Cellular {

        enum class CellState : uint8_t {
            HEALTHY = 0,
            SENESCENT = 1,
            APOPTOTIC = 2,
            ONCOGENIC = 3
        };

        enum class BiologicalSex : uint8_t {
            MALE = 0,
            FEMALE = 1
        };

        struct Exosome {
            uint64_t origin_id;
            double telomerase_payload;
            double genetic_repair_data;
            double proteostasis_reset_data;
            double vegf_tgf_beta_payload;
            bool oskm_reset_active;
            double toxin_scavenger_payload;
            double wnt_healing_signal;
            double chrono_anchor_telomere_lock;
        };

        ZCR_HD inline bool HasFlag(uint8_t flags, uint8_t mask) { return (flags & mask) != 0; }
        ZCR_HD inline void SetFlag(uint8_t& flags, uint8_t mask) { flags |= mask; }
        ZCR_HD inline void ClearFlag(uint8_t& flags, uint8_t mask) { flags &= ~mask; }

        constexpr uint8_t FLAG_P53_ACTIVE = 0x01;
        constexpr uint8_t FLAG_TELOMERASE_ACTIVE = 0x02;
        constexpr uint8_t FLAG_CLEAN_DEATH = 0x04;
        constexpr uint8_t FLAG_Z_TUMOR_MARKER = 0x08;

        constexpr double INITIAL_TELOMERE = 100.0;
        constexpr double TELOMERE_LOSS_PER_DIVISION = 2.5;
        constexpr double CRITICAL_TELOMERE_LENGTH = 15.0;
        constexpr double APOPTOSIS_THRESHOLD = 0.85;
        constexpr double EXHAUSTION_LIMIT = 100.0;
        constexpr double GOLDEN_PRIME_TELOMERE = 85.0;
        constexpr double GOLDEN_PRIME_EXHAUSTION = 10.0;

#pragma pack(push, 1)
        struct alignas(64) Cell {
            uint64_t id;                            // 8 bytes
            double age;                             // 8 bytes
            double telomere_length;                 // 8 bytes
            double mutation_load;                   // 8 bytes
            double metabolic_exhaustion;            // 8 bytes

            // 🛑 PHASE 61/63: 100% Cache-Line Efficiency (4x float = 16 bytes)
            float epigenetic_shield;                // 4 bytes
            float z_tumor_activation_threshold;     // 4 bytes
            float autophagy_active_level;           // 4 bytes
            float cd59_shield;                      // 4 bytes (The MAC Protectin Shield)
            float hif1a_expression;                 // 4 bytes (Hypoxia Inducible Factor)

            CellState state;                        // 1 byte
            uint8_t flags;                          // 1 byte
            uint8_t padding[2];                     // 2 bytes to reach exactly 64 bytes

            [[nodiscard]] uint64_t GetID() const { return id; }
            [[nodiscard]] CellState GetState() const { return state; }
            [[nodiscard]] double GetTelomereLength() const { return telomere_length; }
            [[nodiscard]] double GetMutationLoad() const { return mutation_load; }
            [[nodiscard]] double GetAge() const { return age; }
            [[nodiscard]] double GetMetabolicExhaustion() const { return metabolic_exhaustion; }
            [[nodiscard]] double GetEpigeneticShield() const { return static_cast<double>(epigenetic_shield); }
            [[nodiscard]] double GetAutophagyLevel() const { return static_cast<double>(autophagy_active_level); }

            void ForceTelomeraseActivation() { SetFlag(flags, FLAG_TELOMERASE_ACTIVE); }
            void DisableP53() { ClearFlag(flags, FLAG_P53_ACTIVE); }
            void ForceApoptosis() { state = CellState::APOPTOTIC; ClearFlag(flags, FLAG_CLEAN_DEATH); }
            void InjectZTumorMarker(double target_telomere_lock) {
                SetFlag(flags, FLAG_Z_TUMOR_MARKER);
                z_tumor_activation_threshold = static_cast<float>(target_telomere_lock);
            }
            void ProcessEnvironmentalStress(double dna_damage, double genomic_instability, double dna_repair_efficacy, double stromal_rigidity) {
                // Handled in CUDA
            }
        };
#pragma pack(pop)

        static_assert(sizeof(Cell) == 64, "Cell struct MUST be exactly 64 bytes for GPU Cache-Line alignment!");

    }
}