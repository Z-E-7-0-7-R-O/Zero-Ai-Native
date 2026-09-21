// --- START OF FILE Zero.Nucleus.cpp ---

#include <windows.h>
#include <chrono>
#include <thread>
#include <atomic>
#include "Matrix.Orchestrator.h"
#include "SDF.Raymarch.Microscope.h" 

LRESULT CALLBACK SimulationWindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {

    // Phase 87: DWM DPI Stretching Override
    // Bypassing OS-level bilinear filtering and magnification to enforce absolute 1:1 hardware pixel mapping.
    // This physically prevents Windows from amplifying microscopic sub-pixel artifacts via display scaling.
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

    const wchar_t CLASS_NAME[] = L"InSilico_Biophysical_Simulation_Class";
    WNDCLASS wc = { };
    wc.lpfnWndProc = SimulationWindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hCursor = LoadCursor(NULL, IDC_CROSS);

    RegisterClass(&wc);

    // Phase 77.1: Absolute 1:1 Pixel Mapping (DWM Moiré Interference Eradication)
    // Forcing Windows to calculate outer window borders mathematically so the internal Client Area remains EXACTLY matching the Biological Matrix resolution.
    RECT wr = { 0, 0, BiophysicalConstants::ENVIRONMENT_WIDTH, BiophysicalConstants::ENVIRONMENT_HEIGHT };
    AdjustWindowRect(&wr, WS_OVERLAPPEDWINDOW, FALSE);

    HWND hwnd = CreateWindowEx(
        0, CLASS_NAME, L"High-Performance In-Silico Biophysical Environment",
        WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
        wr.right - wr.left, wr.bottom - wr.top,
        NULL, NULL, hInstance, NULL
    );

    if (hwnd == NULL) return 0;

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    BiophysicalSimulationOrchestrator orchestrator;
    OpticalMicroscopeSubsystem rendering_subsystem(hwnd);

    std::atomic<bool> simulation_running{ true };

    auto ThermodynamicComputeThread = [&]() {
        orchestrator.InitializeSimulation();

        auto previous_time = std::chrono::high_resolution_clock::now();
        double accumulator = 0.0;
        const double thermodynamic_dt = 1.0 / 60.0;

        // Phase 77.3: Death-Spiral Hardware Clamping Boundary
        // Prevents the OS from forcing the GPU to swallow 20+ physics epochs in a single frame upon waking from an OS thread suspension.
        const double max_accumulator_threshold = thermodynamic_dt * 3.0;

        while (simulation_running.load(std::memory_order_relaxed)) {
            auto current_time = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double> frame_duration = current_time - previous_time;
            previous_time = current_time;

            double frame_time = frame_duration.count();

            if (frame_time > 0.25) {
                frame_time = 0.25;
            }

            accumulator += frame_time;

            // Phase 77.3: Execution of the clamp. The simulation experiences biological time-dilation instead of an Atomic Singularity Stall.
            if (accumulator > max_accumulator_threshold) {
                accumulator = max_accumulator_threshold;
            }

            // Phase 82: Interrogation Sensor Extraction - Thermodynamic Accumulator Debt.
            // Converting the unprocessed accumulator time into milliseconds before passing it strictly down to the orchestrator to track CPU backpressure.
            orchestrator.UpdateThermodynamicAccumulatorDebt(accumulator * 1000.0);

            bool state_updated = false;

            while (accumulator >= thermodynamic_dt) {
                orchestrator.AdvanceThermodynamicTime();
                accumulator -= thermodynamic_dt;
                state_updated = true;
            }

            if (state_updated) {
                orchestrator.CommitRenderState();
            }
        }
        };

    std::thread biophysics_engine_thread(ThermodynamicComputeThread);

    MSG msg = { };

    // Phase 86: High-Resolution Optical Shutter Pacification (Frame Pacing Hardware Lock)
    // Eradicating VRAM bandwidth contention by decoupling render frequency from pure physical capability.
    auto render_previous_time = std::chrono::high_resolution_clock::now();
    const double render_dt = 1.0 / 60.0; // Locked strictly to 60 Hz biological observation limit
    unsigned long long optical_frame_count = 0;
    auto fps_timer_start = render_previous_time;

    while (simulation_running.load(std::memory_order_relaxed)) {
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) {
                simulation_running.store(false, std::memory_order_relaxed);
            }
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }

        if (simulation_running.load(std::memory_order_relaxed)) {
            if (orchestrator.IsInitialized()) {

                auto render_current_time = std::chrono::high_resolution_clock::now();
                std::chrono::duration<double> elapsed = render_current_time - render_previous_time;
                double delta_time = elapsed.count();

                // Phase 86: Target execution threshold. Blocks render bombardment.
                if (delta_time >= render_dt) {
                    render_previous_time = render_current_time;

                    auto render_exec_start = std::chrono::high_resolution_clock::now();

                    float render_time = static_cast<float>(orchestrator.GetBiologicalTime());
                    rendering_subsystem.RenderFrame(render_time, &orchestrator);

                    auto render_exec_end = std::chrono::high_resolution_clock::now();
                    std::chrono::duration<double> exec_dur = render_exec_end - render_exec_start;

                    // Calculating VRAM Idle Time (Bandwidth restored to Compute Streams)
                    double vram_idle_ms = (render_dt - exec_dur.count()) * 1000.0;
                    if (vram_idle_ms < 0.0) vram_idle_ms = 0.0;

                    optical_frame_count++;

                    // Extracting Optical Pacification Metrics for Orchestrator Telemetry
                    std::chrono::duration<double> fps_duration = render_current_time - fps_timer_start;
                    if (fps_duration.count() >= 1.0) {
                        double optical_fps = static_cast<double>(optical_frame_count) / fps_duration.count();
                        orchestrator.UpdateOpticalPacingMetrics(optical_fps, vram_idle_ms);

                        optical_frame_count = 0;
                        fps_timer_start = render_current_time;
                    }
                }
                else {
                    // Phase 86: Hybrid Spin-Yield Timer
                    // Returns CPU execution cycles to the Thermodynamic Compute Thread when the render pipeline is artificially clamped.
                    double remaining_ms = (render_dt - delta_time) * 1000.0;
                    if (remaining_ms > 2.0) {
                        std::this_thread::sleep_for(std::chrono::milliseconds(1));
                    }
                    else {
                        std::this_thread::yield();
                    }
                }
            }
            else {
                std::this_thread::sleep_for(std::chrono::milliseconds(1));
            }
        }
    }

    biophysics_engine_thread.join();

    cudaDeviceSynchronize();

    return 0;
}
// --- END OF FILE Zero.Nucleus.cpp ---