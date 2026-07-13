/**
 * @file main.cpp
 * @brief The Genesis - Entry Point for Zero-Cancer-Reactor (Event-Driven UI Pass)
 * @note [SECURE SKELETON: EDUCATIONAL & RESEARCH BIO-SIMULATION ONLY]
 *       Architecture: Single-Threaded Event Loop. Full manual control via UI.
 */

#pragma comment(linker, "/SUBSYSTEM:windows /ENTRY:mainCRTStartup")

#define NOMINMAX
#include <windows.h>
#include <iostream>
#include <exception>

#include "Core/ReactorEngine.h"
#include "Interface/BioTerminal.h"
#include "Interface/CyberGraph.h"

using namespace ZeroCancerReactor;

int main() {
    try {
        Interface::BioTerminal terminal;
        Core::ReactorEngine engine;

        // 🛑 PHASE 46 & 55: THE MATRIX UNCHAINED 
        // راه‌اندازی بافت عظیم با 1500 سلول اولیه و آزادسازی سقف تا 70 میلیون سلول!
        // موتور پردازشی CUDA حالا با تمام 3584 هسته می‌تازد.
        engine.InitializeReactor(1500, 70000000);
        terminal.AddLog(Interface::LogLevel::INFO, "SYSTEM READY: Bio-Reactor memory allocated (1500 cells). MATRIX UNCHAINED.");

        terminal.AddLog(Interface::LogLevel::WARNING, "[DATA LOGGER] Async Telemetry Stream Active -> %s", engine.GetTelemetryFilePath().c_str());

        // 🛑 PHASE 55 Feature Log
        terminal.AddLog(Interface::LogLevel::INFO, "[PHASE 55: NEONATAL CLOAKING & QUORUM INCUBATION ACTIVE]");
        terminal.AddLog(Interface::LogLevel::INFO, "AWAITING USER COMMAND TO INITIATE METABOLIC SEQUENCE...");

        // موتور گرافیکی سایبرنتیک حالا خدای مطلق این شبیه‌سازی است
        Interface::CyberGraph gui(engine, terminal);

        if (gui.InitializeGraphicsContext(GetModuleHandle(nullptr), SW_SHOW)) {
            gui.RunMainRenderLoop();
        }
        else {
            terminal.AddLog(Interface::LogLevel::CRITICAL, "FATAL ERROR: DirectX 11 Graphics Context initialization failed.");
        }

    }
    catch (const std::exception& e) {
        MessageBoxA(nullptr, e.what(), "CATASTROPHIC KERNEL FAILURE", MB_ICONERROR | MB_OK);
        return -1;
    }

    return 0;
}