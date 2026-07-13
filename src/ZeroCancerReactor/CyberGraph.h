/**
 * @file CyberGraph.h
 * @brief Military-Grade DirectX 11 Cyber-Hologram Engine (Phase 66: Biopsy FOV & Refractory Locks)
 * @note [SECURE SKELETON: EDUCATIONAL & RESEARCH BIO-SIMULATION ONLY]
 */

#pragma once

#define NOMINMAX 
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h> 

#include "Core/ReactorEngine.h"
#include "Interface/BioTerminal.h"
#include <atomic>
#include <vector>
#include <thread>
#include <condition_variable>
#include <chrono>
#include <queue>
#include <cstdint>
#include <mutex>
#include <cmath>

namespace ZeroCancerReactor {
    namespace Interface {

        enum class ReactorVisualState {
            STABLE_GREEN,
            DEGRADING_ORANGE,
            CRITICAL_RED,
            FLATLINE_WHITE
        };

        enum class SimulationPhase {
            OFFLINE,
            HOMEOSTASIS,
            INSTABILITY_INDUCED,
            IMMORTALITY_ACHIEVED,
            DEAD
        };

        struct BioParticle {
            float x, y;
            float vx, vy;
            float base_x, base_y;
            float size;
            float phase;
        };

        __declspec(align(16))
            struct HologramConstants {
            float time_anim;
            float pop_ratio;
            float healthy_ratio;
            float tumor_sat;
            float avg_tel;
            float immortality_control;
            float oncogenic_cells;
            float total_population;
        };

        class CyberGraph {
        private:
            Core::ReactorEngine& engine_;
            BioTerminal& terminal_;

            HWND hwnd_;
            ID3D11Device* pd3dDevice_ = nullptr;
            ID3D11DeviceContext* pd3dDeviceContext_ = nullptr;
            IDXGISwapChain* pSwapChain_ = nullptr;
            ID3D11RenderTargetView* pMainRenderTargetView_ = nullptr;

            ID3D11Texture2D* hologram_texture_ = nullptr;
            ID3D11ShaderResourceView* hologram_srv_ = nullptr;
            ID3D11RenderTargetView* hologram_rtv_ = nullptr;
            ID3D11VertexShader* holo_vs_ = nullptr;
            ID3D11PixelShader* holo_ps_ = nullptr;
            ID3D11Buffer* cb_telemetry_ = nullptr;

            static constexpr int HOLO_WIDTH = 512;
            static constexpr int HOLO_HEIGHT = 512;

            std::vector<BioParticle> background_particles_;
            ReactorVisualState current_state_;

            SimulationPhase current_phase_;
            SimulationPhase next_phase_;
            bool is_processing_;
            float processing_timer_;
            bool lazarus_achieved_;

            bool ai_injection_triggered_;

            // 🛑 PHASE 66: Biochemical Refractory Integration Locks
            float injection_cooldown_timer_;
            bool integration_phase_active_;

            int ui_selected_sex_;
            float ui_current_age_;
            float ui_target_age_;

            std::thread audio_worker_;
            std::mutex audio_mtx_;
            std::condition_variable audio_cv_;
            std::atomic<bool> audio_stop_{ false };
            std::queue<ReactorVisualState> audio_queue_;

            void AudioWorkerLoop();
            void PlayAudioAlarm(ReactorVisualState state);

            void RenderBackgroundParticles(float delta_time);
            void RenderMicroscopePanel(const Core::BioTelemetry& tel, float width, float height);

            void UpdateHologramTexture(const Core::BioTelemetry& tel, float time_anim);
            void RenderDashboardAndTerminal(const Core::BioTelemetry& tel, float delta_time);

            bool CreateDeviceD3D(HWND hWnd);
            void CleanupDeviceD3D();
            void CreateRenderTarget();
            void CleanupRenderTarget();

        public:
            CyberGraph(Core::ReactorEngine& engine, BioTerminal& terminal);
            ~CyberGraph();

            bool InitializeGraphicsContext(HINSTANCE hInstance, int nCmdShow);
            void RunMainRenderLoop();
        };

    }
}