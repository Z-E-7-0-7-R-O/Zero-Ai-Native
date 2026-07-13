/**
 * @file CyberGraph.cpp
 * @brief Military-Grade DirectX 11 Cyber-Hologram Engine (Phase 72: Absolute Decoupling & FPS Top-Left Shift)
 * @note [SECURE SKELETON: EDUCATIONAL & RESEARCH BIO-SIMULATION ONLY]
 */

#define NOMINMAX 
#include "Interface/CyberGraph.h"
#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"

 // Note: Shield/SentinelGuard.h is now decoupled from the UI Render Loop.
#include "Shield/SentinelGuard.h"
#include "OncoLogic/TelomeraseExploit.h"
#include "Cellular/Cell.h"

#include <cmath>
#include <random>
#include <iostream>
#include <algorithm>

#include <avrt.h>
#pragma comment(lib, "Avrt.lib")
#pragma comment(lib, "d3dcompiler.lib") 

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam)) return true;
    switch (msg) {
    case WM_SIZE: if (wParam != SIZE_MINIMIZED) return 0; return 0;
    case WM_SYSCOMMAND: if ((wParam & 0xfff0) == SC_KEYMENU) return 0; break;
    case WM_DESTROY: PostQuitMessage(0); return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}

namespace ZeroCancerReactor {
    namespace Interface {

        const ImVec4 THEME_NEON_GREEN = ImVec4(0.0f, 1.0f, 0.533f, 1.0f);
        const ImU32  THEME_NEON_GREEN_U32 = IM_COL32(0, 255, 136, 255);

        CyberGraph::CyberGraph(Core::ReactorEngine& engine, BioTerminal& terminal)
            : engine_(engine), terminal_(terminal), current_state_(ReactorVisualState::STABLE_GREEN),
            current_phase_(SimulationPhase::OFFLINE), next_phase_(SimulationPhase::OFFLINE),
            is_processing_(false), processing_timer_(0.0f), lazarus_achieved_(false), hwnd_(nullptr),
            ai_injection_triggered_(false), injection_cooldown_timer_(0.0f), integration_phase_active_(false),
            ui_selected_sex_(0), ui_current_age_(30.0f), ui_target_age_(25.0f) {

            // 🛑 PHASE 72: Bridge the UI Terminal to the Reactor Engine for decoupled SentinelGuard Execution
            engine_.AttachTerminal(&terminal_);

            std::random_device rd;
            std::mt19937 gen(rd());
            std::uniform_real_distribution<float> dis_pos(0.0f, 2560.0f);
            std::uniform_real_distribution<float> dis_vel(-0.5f, 0.5f);
            std::uniform_real_distribution<float> dis_phase(0.0f, 6.28f);

            for (int i = 0; i < 1000; ++i) {
                background_particles_.push_back({
                    dis_pos(gen), dis_pos(gen),
                    dis_vel(gen), dis_vel(gen),
                    0.0f, 0.0f,
                    std::uniform_real_distribution<float>(1.0f, 2.5f)(gen),
                    dis_phase(gen)
                    });
                background_particles_.back().base_x = background_particles_.back().x;
                background_particles_.back().base_y = background_particles_.back().y;
            }

            audio_worker_ = std::thread(&CyberGraph::AudioWorkerLoop, this);
        }

        CyberGraph::~CyberGraph() {
            audio_stop_.store(true);
            audio_cv_.notify_all();
            if (audio_worker_.joinable()) audio_worker_.join();

            if (hologram_srv_) hologram_srv_->Release();
            if (hologram_rtv_) hologram_rtv_->Release();
            if (hologram_texture_) hologram_texture_->Release();
            if (holo_vs_) holo_vs_->Release();
            if (holo_ps_) holo_ps_->Release();
            if (cb_telemetry_) cb_telemetry_->Release();

            ImGui_ImplDX11_Shutdown();
            ImGui_ImplWin32_Shutdown();
            ImGui::DestroyContext();
            CleanupDeviceD3D();
            DestroyWindow(hwnd_);
        }

        void CyberGraph::AudioWorkerLoop() {
            DWORD taskIndex = 0;
            HANDLE hTask = AvSetMmThreadCharacteristics(TEXT("Pro Audio"), &taskIndex);
            if (hTask != NULL) AvSetMmThreadPriority(hTask, AVRT_PRIORITY_CRITICAL);
            else SetThreadPriority(GetCurrentThread(), THREAD_PRIORITY_TIME_CRITICAL);

            while (!audio_stop_.load()) {
                ReactorVisualState state_to_play;
                size_t queue_load = 0;
                {
                    std::unique_lock<std::mutex> lock(audio_mtx_);
                    audio_cv_.wait(lock, [this]() { return !audio_queue_.empty() || audio_stop_.load(); });
                    if (audio_stop_.load() && audio_queue_.empty()) break;
                    state_to_play = audio_queue_.front();
                    audio_queue_.pop();
                    queue_load = audio_queue_.size();
                }

                DWORD duration_primary = 150; DWORD duration_secondary = 100; DWORD pause_time = 50;
                if (queue_load > 6) { duration_primary = 20; duration_secondary = 15; pause_time = 10; }
                else if (queue_load > 2) { duration_primary = 60; duration_secondary = 40; pause_time = 20; }

                if (state_to_play == ReactorVisualState::DEGRADING_ORANGE) { Beep(800, duration_primary); Sleep(pause_time); Beep(800, duration_primary); }
                else if (state_to_play == ReactorVisualState::CRITICAL_RED) {
                    for (int i = 0; i < 3; i++) { Beep(1500, duration_secondary); Sleep(pause_time); Beep(1200, duration_secondary); Sleep(pause_time); }
                }
                else if (state_to_play == ReactorVisualState::FLATLINE_WHITE) { Beep(800, 3000); }

                std::this_thread::yield();
            }
            if (hTask != NULL) AvRevertMmThreadCharacteristics(hTask);
        }

        void CyberGraph::PlayAudioAlarm(ReactorVisualState state) {
            std::scoped_lock<std::mutex> lock(audio_mtx_);
            while (audio_queue_.size() >= 12) audio_queue_.pop();
            audio_queue_.push(state);
            audio_cv_.notify_one();
        }

        bool CyberGraph::CreateDeviceD3D(HWND hWnd) {
            DXGI_SWAP_CHAIN_DESC sd;
            ZeroMemory(&sd, sizeof(sd));
            sd.BufferCount = 2; sd.BufferDesc.Width = 0; sd.BufferDesc.Height = 0;
            sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM; sd.BufferDesc.RefreshRate.Numerator = 60;
            sd.BufferDesc.RefreshRate.Denominator = 1; sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
            sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT; sd.OutputWindow = hWnd;
            sd.SampleDesc.Count = 1; sd.SampleDesc.Quality = 0; sd.Windowed = TRUE; sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;
            UINT createDeviceFlags = 0; D3D_FEATURE_LEVEL featureLevel;
            const D3D_FEATURE_LEVEL featureLevelArray[2] = { D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_0, };
            if (D3D11CreateDeviceAndSwapChain(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, createDeviceFlags, featureLevelArray, 2, D3D11_SDK_VERSION, &sd, &pSwapChain_, &pd3dDevice_, &featureLevel, &pd3dDeviceContext_) != S_OK)
                return false;
            CreateRenderTarget(); return true;
        }

        void CyberGraph::CleanupDeviceD3D() {
            CleanupRenderTarget();
            if (pSwapChain_) { pSwapChain_->Release(); pSwapChain_ = nullptr; }
            if (pd3dDeviceContext_) { pd3dDeviceContext_->Release(); pd3dDeviceContext_ = nullptr; }
            if (pd3dDevice_) { pd3dDevice_->Release(); pd3dDevice_ = nullptr; }
        }

        void CyberGraph::CreateRenderTarget() {
            ID3D11Texture2D* pBackBuffer = nullptr;
            HRESULT hr = pSwapChain_->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer));
            if (SUCCEEDED(hr) && pBackBuffer != nullptr) {
                pd3dDevice_->CreateRenderTargetView(pBackBuffer, nullptr, &pMainRenderTargetView_);
                pBackBuffer->Release();
            }
        }

        void CyberGraph::CleanupRenderTarget() {
            if (pMainRenderTargetView_) { pMainRenderTargetView_->Release(); pMainRenderTargetView_ = nullptr; }
        }

        bool CyberGraph::InitializeGraphicsContext(HINSTANCE hInstance, int nCmdShow) {
            FreeConsole();

            WNDCLASSEX wc = { sizeof(WNDCLASSEX), CS_CLASSDC, WndProc, 0L, 0L, GetModuleHandle(nullptr), nullptr, nullptr, nullptr, nullptr, L"ZeroCancerReactor", nullptr };
            ::RegisterClassEx(&wc);
            hwnd_ = ::CreateWindowEx(0, wc.lpszClassName, L"Zero-Cancer-Reactor [MILITARY GRADE INTERFACE]", WS_OVERLAPPEDWINDOW | WS_MAXIMIZE, 100, 100, 1920, 1080, nullptr, nullptr, wc.hInstance, nullptr);
            if (!CreateDeviceD3D(hwnd_)) { CleanupDeviceD3D(); ::UnregisterClass(wc.lpszClassName, wc.hInstance); return false; }
            ::ShowWindow(hwnd_, SW_MAXIMIZE); ::UpdateWindow(hwnd_);

            D3D11_TEXTURE2D_DESC desc = {};
            desc.Width = HOLO_WIDTH; desc.Height = HOLO_HEIGHT;
            desc.MipLevels = 1; desc.ArraySize = 1;
            desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
            desc.SampleDesc.Count = 1;
            desc.Usage = D3D11_USAGE_DEFAULT;
            desc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
            desc.CPUAccessFlags = 0;

            HRESULT hrTex = pd3dDevice_->CreateTexture2D(&desc, nullptr, &hologram_texture_);
            if (SUCCEEDED(hrTex) && hologram_texture_ != nullptr) {
                pd3dDevice_->CreateShaderResourceView(hologram_texture_, nullptr, &hologram_srv_);
                pd3dDevice_->CreateRenderTargetView(hologram_texture_, nullptr, &hologram_rtv_);
            }

            const char* shaderCode = R"(
                cbuffer TelemetryCB : register(b0) {
                    float time_anim;
                    float pop_ratio;
                    float healthy_ratio;
                    float tumor_sat;
                    float avg_tel;
                    float immortality_control;
                    float oncogenic_cells;
                    float total_population;
                };

                struct VS_Output {
                    float4 pos : SV_POSITION;
                    float2 uv : TEXCOORD;
                };

                VS_Output VS_Main(uint id : SV_VertexID) {
                    VS_Output output;
                    output.uv = float2((id << 1) & 2, id & 2);
                    output.pos = float4(output.uv * float2(2, -2) + float2(-1, 1), 0, 1);
                    return output;
                }

                float4 PS_Main(VS_Output input) : SV_TARGET {
                    float2 center = float2(256.0, 256.0);
                    float2 diff = input.pos.xy - center;
                    float dist = length(diff);
                    
                    float max_radius = 240.0 * sqrt(max(0.001, pop_ratio));
                    if (dist > max_radius + 5.0) return float4(0, 0, 0, 0);

                    float cancer_ratio = (total_population > 0.0) ? (oncogenic_cells / total_population) : 0.0;
                    float tumor_radius = max_radius * sqrt(max(0.001, cancer_ratio));
                    
                    float grid_size = 4.5; 
                    float2 grid_uv = frac(input.pos.xy / grid_size) - 0.5;
                    float point_dist = length(grid_uv);
                    
                    float dot_radius = 0.25;
                    float tumor_blend = saturate((tumor_radius - dist) / 10.0);
                    
                    float life_intensity = saturate(0.3 + 0.7 * (avg_tel / 100.0));
                    float3 healthy_col = float3(0.0, 1.0, 0.533) * life_intensity; 
                    
                    float3 tumor_col = float3(1.0, 0.2 + 0.3 * (1.0 - tumor_sat), 0.0);
                    
                    float pulse = sin(time_anim * 5.0 - dist * 0.05) * 0.5 + 0.5;
                    dot_radius += pulse * 0.15 * tumor_blend;
                    
                    float is_dot = 1.0 - smoothstep(dot_radius - 0.05, dot_radius + 0.05, point_dist);
                    float3 final_col = lerp(healthy_col, tumor_col, tumor_blend);
                    
                    float scan = saturate(1.0 - abs(dist - fmod(time_anim * 60.0, max_radius + 20.0)) / 5.0);
                    final_col += scan * 0.5 * float3(0.0, 1.0, 0.533);
                    
                    float glow = exp(-point_dist * 6.0) * 0.5;
                    float alpha = (is_dot + glow) * saturate((max_radius - dist) / 5.0);
                    
                    if (total_population == 0.0) alpha = 0.0;
                    return float4(final_col * alpha, alpha);
                }
            )";

            ID3DBlob* vsBlob = nullptr;
            ID3DBlob* psBlob = nullptr;
            ID3DBlob* errorBlob = nullptr;

            D3DCompile(shaderCode, strlen(shaderCode), nullptr, nullptr, nullptr, "VS_Main", "vs_5_0", 0, 0, &vsBlob, &errorBlob);
            if (vsBlob) {
                pd3dDevice_->CreateVertexShader(vsBlob->GetBufferPointer(), vsBlob->GetBufferSize(), nullptr, &holo_vs_);
                vsBlob->Release();
            }

            D3DCompile(shaderCode, strlen(shaderCode), nullptr, nullptr, nullptr, "PS_Main", "ps_5_0", 0, 0, &psBlob, &errorBlob);
            if (psBlob) {
                pd3dDevice_->CreatePixelShader(psBlob->GetBufferPointer(), psBlob->GetBufferSize(), nullptr, &holo_ps_);
                psBlob->Release();
            }
            if (errorBlob) errorBlob->Release();

            D3D11_BUFFER_DESC cbDesc = {};
            cbDesc.ByteWidth = sizeof(HologramConstants);
            cbDesc.Usage = D3D11_USAGE_DEFAULT;
            cbDesc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
            pd3dDevice_->CreateBuffer(&cbDesc, nullptr, &cb_telemetry_);

            IMGUI_CHECKVERSION(); ImGui::CreateContext(); ImGuiIO& io = ImGui::GetIO(); (void)io;
            ImGui::StyleColorsDark();

            ImGuiStyle& style = ImGui::GetStyle();
            style.WindowRounding = 12.0f; style.FrameRounding = 4.0f; style.ScrollbarRounding = 12.0f;
            style.WindowBorderSize = 1.0f; style.WindowPadding = ImVec2(20.0f, 20.0f);

            auto& colors = style.Colors;
            colors[ImGuiCol_WindowBg] = ImVec4(0.015f, 0.02f, 0.025f, 0.75f);
            colors[ImGuiCol_Border] = ImVec4(0.0f, 1.0f, 0.533f, 0.4f);
            colors[ImGuiCol_Header] = ImVec4(0.0f, 0.0f, 0.0f, 0.0f);
            colors[ImGuiCol_HeaderHovered] = ImVec4(0.0f, 0.0f, 0.0f, 0.0f);
            colors[ImGuiCol_HeaderActive] = ImVec4(0.0f, 0.0f, 0.0f, 0.0f);
            colors[ImGuiCol_Text] = THEME_NEON_GREEN;
            colors[ImGuiCol_TitleBg] = colors[ImGuiCol_WindowBg];
            colors[ImGuiCol_TitleBgActive] = colors[ImGuiCol_WindowBg];
            colors[ImGuiCol_TitleBgCollapsed] = colors[ImGuiCol_WindowBg];

            ImGui_ImplWin32_Init(hwnd_);
            ImGui_ImplDX11_Init(pd3dDevice_, pd3dDeviceContext_);
            return true;
        }

        void CyberGraph::RenderBackgroundParticles(float delta_time) {
            ImDrawList* draw_list = ImGui::GetBackgroundDrawList();
            ImVec2 screen_size = ImGui::GetIO().DisplaySize;
            float time = static_cast<float>(ImGui::GetTime());

            ImU32 dot_color = IM_COL32(0, 255, 136, 255);
            float jitter_amount = 0.0f; float wave_speed = 1.5f;

            if (current_phase_ == SimulationPhase::DEAD) { dot_color = IM_COL32(80, 80, 80, 255); wave_speed = 0.0f; }
            else if (current_state_ == ReactorVisualState::CRITICAL_RED) { dot_color = IM_COL32(255, 30, 30, 255); jitter_amount = 5.0f; wave_speed = 15.0f; }
            else if (current_state_ == ReactorVisualState::DEGRADING_ORANGE) { dot_color = IM_COL32(255, 120, 0, 255); jitter_amount = 1.0f; wave_speed = 5.0f; }

            float spacing = 22.0f;
            for (float x = 0; x < screen_size.x; x += spacing) {
                for (float y = 0; y < screen_size.y; y += spacing) {
                    float wave = std::sin(x * 0.01f + time * wave_speed) + std::cos(y * 0.01f + time * wave_speed);
                    float alpha_mod = 0.2f + ((wave + 2.0f) / 4.0f) * 0.4f;
                    float px = x; float py = y;
                    if (jitter_amount > 0.0f) {
                        px += std::sin(time * 50.0f + y) * jitter_amount;
                        py += std::cos(time * 50.0f + x) * jitter_amount;
                    }
                    ImU32 final_color = (dot_color & 0x00FFFFFF) | (static_cast<int>(alpha_mod * 255.0f) << 24);
                    draw_list->AddCircleFilled(ImVec2(px, py), 1.8f, final_color);
                }
            }
        }

        void CyberGraph::UpdateHologramTexture(const Core::BioTelemetry& tel, float time_anim) {
            if (!hologram_rtv_ || !pd3dDeviceContext_) return;

            HologramConstants cb_data;
            cb_data.time_anim = time_anim;
            cb_data.pop_ratio = static_cast<float>(std::min(1.0, tel.total_population / 70000000.0));
            cb_data.healthy_ratio = tel.total_population > 0 ? static_cast<float>(tel.healthy_cells) / static_cast<float>(tel.total_population) : 0.0f;
            cb_data.tumor_sat = static_cast<float>(tel.systemic_z_tumor_saturation);
            cb_data.avg_tel = static_cast<float>(tel.avg_telomere_length);
            cb_data.immortality_control = static_cast<float>(tel.immortality_control);
            cb_data.oncogenic_cells = static_cast<float>(tel.oncogenic_cells);
            cb_data.total_population = static_cast<float>(tel.total_population);

            pd3dDeviceContext_->UpdateSubresource(cb_telemetry_, 0, nullptr, &cb_data, 0, 0);

            ID3D11RenderTargetView* old_rtv = nullptr;
            ID3D11DepthStencilView* old_dsv = nullptr;
            pd3dDeviceContext_->OMGetRenderTargets(1, &old_rtv, &old_dsv);

            UINT num_viewports = 1;
            D3D11_VIEWPORT old_vp;
            pd3dDeviceContext_->RSGetViewports(&num_viewports, &old_vp);

            pd3dDeviceContext_->OMSetRenderTargets(1, &hologram_rtv_, nullptr);
            D3D11_VIEWPORT vp = {};
            vp.Width = HOLO_WIDTH;
            vp.Height = HOLO_HEIGHT;
            vp.MinDepth = 0.0f;
            vp.MaxDepth = 1.0f;
            pd3dDeviceContext_->RSSetViewports(1, &vp);

            float clear_color[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
            pd3dDeviceContext_->ClearRenderTargetView(hologram_rtv_, clear_color);

            pd3dDeviceContext_->VSSetShader(holo_vs_, nullptr, 0);
            pd3dDeviceContext_->PSSetShader(holo_ps_, nullptr, 0);
            pd3dDeviceContext_->PSSetConstantBuffers(0, 1, &cb_telemetry_);

            pd3dDeviceContext_->IASetInputLayout(nullptr);
            pd3dDeviceContext_->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
            pd3dDeviceContext_->Draw(3, 0);

            pd3dDeviceContext_->OMSetRenderTargets(1, &old_rtv, old_dsv);
            pd3dDeviceContext_->RSSetViewports(1, &old_vp);

            if (old_rtv) old_rtv->Release();
            if (old_dsv) old_dsv->Release();
        }

        void CyberGraph::RenderMicroscopePanel(const Core::BioTelemetry& tel, float width, float height) {
            ImGui::Begin("MICROSCOPE_PANEL", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoBringToFrontOnFocus);

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "LIVE BIOLOGICAL MICROSCOPE [STATISTICAL BIOPSY FOV: 5M CELLS]");
            ImGui::Spacing();

            ImDrawList* draw_list = ImGui::GetWindowDrawList();
            ImVec2 p = ImGui::GetCursorScreenPos();
            ImVec2 avail = ImGui::GetContentRegionAvail();
            ImVec2 center = ImVec2(p.x + (avail.x / 2.0f), p.y + (avail.y / 2.0f));
            float radius_max = (std::min(avail.x, avail.y) / 2.0f) - 10.0f;

            draw_list->AddCircle(center, radius_max, IM_COL32(0, 255, 136, 80), 128, 3.0f);
            draw_list->AddCircle(center, radius_max - 2.0f, IM_COL32(0, 255, 136, 200), 128, 1.0f);

            if (current_phase_ != SimulationPhase::OFFLINE) {
                UpdateHologramTexture(tel, static_cast<float>(ImGui::GetTime()));
            }

            ImVec2 p_min = ImVec2(center.x - radius_max, center.y - radius_max);
            ImVec2 p_max = ImVec2(center.x + radius_max, center.y + radius_max);

            if (hologram_srv_) {
                draw_list->AddImage((ImTextureID)hologram_srv_, p_min, p_max);
            }

            ImGui::End();
        }

        void CyberGraph::RenderDashboardAndTerminal(const Core::BioTelemetry& tel, float delta_time) {
            ImVec2 screen_size = ImGui::GetIO().DisplaySize;
            float padding = 20.0f;
            float w_micro = 700.0f; float w_dash = 380.0f; float w_term = screen_size.x - w_micro - w_dash - (padding * 4.0f);
            float height = screen_size.y - (padding * 2.0f);

            ImVec4 border_col = THEME_NEON_GREEN;
            if (current_phase_ == SimulationPhase::DEAD) border_col = ImVec4(0.3f, 0.3f, 0.3f, 0.8f);
            else if (current_state_ == ReactorVisualState::CRITICAL_RED) border_col = ImVec4(1.0f, 0.0f, 0.0f, 0.9f);
            else if (current_state_ == ReactorVisualState::DEGRADING_ORANGE) border_col = ImVec4(1.0f, 0.5f, 0.0f, 0.9f);

            ImGui::GetStyle().Colors[ImGuiCol_Border] = border_col;

            ImGui::SetNextWindowPos(ImVec2(padding, padding));
            ImGui::SetNextWindowSize(ImVec2(w_micro, height));

            RenderMicroscopePanel(tel, w_micro, height);

            ImGui::SetNextWindowPos(ImVec2(padding * 2 + w_micro, padding));
            ImGui::SetNextWindowSize(ImVec2(w_term, height));
            ImGui::Begin("TERMINAL_PANEL", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoBringToFrontOnFocus);

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "CYBERNETIC BIO-LOG UPLINK");
            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();

            ImGui::BeginChild("LogScrollRegion", ImVec2(0, 0), false, ImGuiWindowFlags_None);
            ImGui::PushTextWrapPos(0.0f);

            auto logs = terminal_.GetRecentLogs();
            for (const auto& log : logs) {
                ImVec4 color;
                switch (log.level) {
                case LogLevel::INFO: color = THEME_NEON_GREEN; break;
                case LogLevel::WARNING: color = ImVec4(1.0f, 0.8f, 0.0f, 1.0f); break;
                case LogLevel::CRITICAL: color = ImVec4(1.0f, 0.2f, 0.2f, 1.0f); break;
                case LogLevel::SYSTEM_DEAD: color = ImVec4(0.6f, 0.6f, 0.6f, 1.0f); break;
                }
                ImGui::PushStyleColor(ImGuiCol_Text, color);
                ImGui::TextWrapped("%s %s", log.timestamp.c_str(), log.message.c_str());
                ImGui::PopStyleColor();
                ImGui::Dummy(ImVec2(0.0f, 2.0f));
            }
            ImGui::PopTextWrapPos();
            if (ImGui::GetScrollY() >= ImGui::GetScrollMaxY() - 10.0f) ImGui::SetScrollHereY(1.0f);

            ImGui::EndChild();
            ImGui::End();

            ImGui::SetNextWindowPos(ImVec2(padding * 3 + w_micro + w_term, padding));
            ImGui::SetNextWindowSize(ImVec2(w_dash, height));
            ImGui::Begin("TELEMETRY_PANEL", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoBringToFrontOnFocus);

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "LIVE BIOLOGICAL TELEMETRY");
            ImGui::Spacing(); ImGui::Spacing();

            ImGui::Text("HOST DEMOGRAPHICS AND CHRONO-ANCHOR");
            ImGui::Spacing();
            const char* genders[] = { "MALE (XY)", "FEMALE (XX)" };

            ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0.0f, 0.0f, 0.0f, 0.0f));
            ImGui::PushStyleColor(ImGuiCol_FrameBgHovered, ImVec4(0.0f, 1.0f, 0.533f, 0.1f));
            ImGui::PushStyleColor(ImGuiCol_FrameBgActive, ImVec4(0.0f, 1.0f, 0.533f, 0.2f));
            ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.0f, 0.0f, 0.0f, 0.0f));
            ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.0f, 1.0f, 0.533f, 0.1f));
            ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.0f, 1.0f, 0.533f, 0.2f));
            ImGui::PushStyleColor(ImGuiCol_Header, ImVec4(0.0f, 0.0f, 0.0f, 0.0f));
            ImGui::PushStyleColor(ImGuiCol_HeaderHovered, ImVec4(0.0f, 1.0f, 0.533f, 0.3f));
            ImGui::PushStyleColor(ImGuiCol_HeaderActive, ImVec4(0.0f, 1.0f, 0.533f, 0.5f));
            ImGui::PushStyleColor(ImGuiCol_PopupBg, ImVec4(0.015f, 0.02f, 0.025f, 0.98f));

            ImGui::Combo("SUBJECT SEX", &ui_selected_sex_, genders, IM_ARRAYSIZE(genders));

            ImGui::PopStyleColor(10);

            ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0.05f, 0.08f, 0.06f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_FrameBgHovered, ImVec4(0.08f, 0.12f, 0.09f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_FrameBgActive, ImVec4(0.1f, 0.15f, 0.11f, 1.0f));
            ImGui::PushStyleColor(ImGuiCol_SliderGrab, THEME_NEON_GREEN);
            ImGui::PushStyleColor(ImGuiCol_SliderGrabActive, ImVec4(0.0f, 0.8f, 0.4f, 1.0f));

            ImGui::SliderFloat("CHRONO AGE", &ui_current_age_, 1.0f, 150.0f, "%.1f YEARS");
            ImGui::SliderFloat("TARGET AGE", &ui_target_age_, 18.0f, 50.0f, "%.1f YEARS");

            ImGui::PopStyleColor(5);

            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();

            auto DrawTrueNeonBloomBar = [&](const char* label, float value, ImVec4 custom_text_color = THEME_NEON_GREEN) {
                ImGui::PushStyleColor(ImGuiCol_Text, custom_text_color);
                ImGui::Text("%s", label);
                ImGui::PopStyleColor();
                ImGui::Spacing();

                ImVec2 p = ImGui::GetCursorScreenPos(); p.x = std::floor(p.x); p.y = std::floor(p.y);
                float w = std::floor(ImGui::GetContentRegionAvail().x); float h = 25.0f; float r = 4.0f;
                ImDrawList* draw_list = ImGui::GetWindowDrawList();
                draw_list->AddRectFilled(p, ImVec2(p.x + w, p.y + h), IM_COL32(12, 16, 14, 255), r);

                float visual_value = std::min(value, 1.0f);
                if (visual_value > 0.0f) {
                    float fill_w = std::floor(w * visual_value);
                    if (fill_w < r * 2.0f) fill_w = r * 2.0f;
                    ImVec2 p_max = ImVec2(p.x + fill_w, p.y + h);
                    const int glow_passes = 6;
                    for (int i = glow_passes; i >= 1; --i) {
                        float alpha_ratio = static_cast<float>(glow_passes - i + 1) / glow_passes;
                        int alpha = static_cast<int>(35.0f * alpha_ratio * alpha_ratio);
                        draw_list->AddRectFilled(ImVec2(p.x - i, p.y - i), ImVec2(p_max.x + i, p_max.y + i), IM_COL32(0, 255, 136, alpha), r + static_cast<float>(i) * 0.5f);
                    }
                    draw_list->AddRectFilled(p, p_max, THEME_NEON_GREEN_U32, r);
                }
                char buf[32]; sprintf_s(buf, "%.1f %%", value * 100.0f);
                ImVec2 text_size = ImGui::CalcTextSize(buf);
                ImVec2 text_pos = ImVec2(std::floor(p.x + w / 2.0f - text_size.x / 2.0f), std::floor(p.y + h / 2.0f - text_size.y / 2.0f));
                draw_list->AddText(text_pos, IM_COL32(255, 255, 255, 255), buf);
                ImGui::Dummy(ImVec2(w, h + 15.0f));
                };

            float footer_height_to_reserve = 60.0f;

            ImGui::PushStyleVar(ImGuiStyleVar_ChildRounding, 12.0f);
            ImGui::BeginChild("ScrollingMatrix", ImVec2(0, ImGui::GetContentRegionAvail().y - footer_height_to_reserve), true, ImGuiWindowFlags_AlwaysVerticalScrollbar);

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "VITAL AND ORGAN AXIS");
            ImGui::Spacing(); ImGui::Spacing();
            float disp_oxy = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.pulmonary_o2_capacity);
            float disp_inf = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.systemic_inflammation);
            float disp_imm = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.immortality_control);
            float disp_hep = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.hepatic_stress);
            float disp_gfr = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.renal_gfr);
            float disp_brain = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.brain_glucose_demand);
            float disp_cardiac = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.cardiac_perfusion_rate / 3.0f);
            float disp_pulmonary = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.pulmonary_o2_capacity);
            float disp_ztumor = (current_phase_ == SimulationPhase::DEAD || current_phase_ == SimulationPhase::OFFLINE) ? 0.0f : static_cast<float>(tel.systemic_z_tumor_saturation);

            DrawTrueNeonBloomBar("TISSUE OXYGENATION", disp_oxy);
            DrawTrueNeonBloomBar("SYSTEMIC INFLAMMATION", disp_inf);
            DrawTrueNeonBloomBar("IMMORTALITY CONTROL INDEX", disp_imm);
            DrawTrueNeonBloomBar("HEPATIC STRESS (LIVER)", disp_hep);
            DrawTrueNeonBloomBar("RENAL GFR (KIDNEYS)", disp_gfr);
            DrawTrueNeonBloomBar("BRAIN GLUCOSE METABOLISM", disp_brain);
            DrawTrueNeonBloomBar("CARDIAC PERFUSION RATE", disp_cardiac);
            DrawTrueNeonBloomBar("PULMONARY O2 CAPACITY", disp_pulmonary);
            DrawTrueNeonBloomBar("SYSTEMIC Z-TUMOR SATURATION", disp_ztumor);

            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "CYTOKINE NETWORK");
            ImGui::Spacing(); ImGui::Spacing();
            DrawTrueNeonBloomBar("IL-2 (T-CELL PROLIFERATION)", static_cast<float>(tel.cytokine_il2));
            DrawTrueNeonBloomBar("IL-6 & IL-1B (ACUTE INFLAMMATION)", static_cast<float>(tel.cytokine_il6));
            DrawTrueNeonBloomBar("IL-10 & IL-35 (IMMUNE CEASEFIRE)", static_cast<float>(tel.cytokine_il10));
            DrawTrueNeonBloomBar("IL-12 (M1 MACROPHAGE ACTIVATOR)", static_cast<float>(tel.cytokine_il12));
            DrawTrueNeonBloomBar("IL-4 & IL-13 (TISSUE REPAIR)", static_cast<float>(tel.cytokine_il4));
            DrawTrueNeonBloomBar("IFN-GAMMA (MASTER KILL SWITCH)", static_cast<float>(tel.cytokine_ifn_gamma));
            DrawTrueNeonBloomBar("TNF-ALPHA (DEATH SIGNAL BOMB)", static_cast<float>(tel.cytokine_tnf_alpha));
            DrawTrueNeonBloomBar("TGF-BETA (TUMOR STROMAL SHIELD)", static_cast<float>(tel.cytokine_tgf_beta));
            DrawTrueNeonBloomBar("CXCL8 & CCL2 (WBC GPS ROUTING)", static_cast<float>((tel.cytokine_cxcl8 + tel.cytokine_ccl2) * 0.5));
            DrawTrueNeonBloomBar("G-CSF & M-CSF (BONE MARROW REQ)", static_cast<float>((tel.cytokine_g_csf + tel.cytokine_m_csf) * 0.5));

            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "WBC LINEAGES");
            ImGui::Spacing(); ImGui::Spacing();
            DrawTrueNeonBloomBar("NEUTROPHILS (FIRST RESPONDERS)", static_cast<float>(tel.wbc_neutrophils));
            DrawTrueNeonBloomBar("M1 MACROPHAGES (AGGRESSIVE KILLERS)", static_cast<float>(tel.wbc_macrophage_m1));
            DrawTrueNeonBloomBar("M2 MACROPHAGES (TISSUE REPAIR)", static_cast<float>(tel.wbc_macrophage_m2));
            DrawTrueNeonBloomBar("NK CELLS (NATURAL KILLERS)", static_cast<float>(tel.wbc_nk_cells));
            DrawTrueNeonBloomBar("CD8+ T-CELLS (PRECISION SNIPERS)", static_cast<float>(tel.wbc_cd8_t_cells));
            DrawTrueNeonBloomBar("CD4+ T-CELLS (FIELD COMMANDERS)", static_cast<float>(tel.wbc_cd4_t_cells));
            DrawTrueNeonBloomBar("B-CELLS (ANTIBODY PRODUCTION)", static_cast<float>(tel.wbc_b_cells));
            DrawTrueNeonBloomBar("REGULATORY T-CELLS (RIOT POLICE)", static_cast<float>(tel.wbc_tregs));
            DrawTrueNeonBloomBar("TCF1+ STEM-LIKE CD8+ (MEMORY RESERVOIR)", static_cast<float>(tel.wbc_tcf1_stem_like_cd8));

            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "EFFECTOR MECHANISMS");
            ImGui::Spacing(); ImGui::Spacing();
            DrawTrueNeonBloomBar("PERFORIN / GRANZYME PATHWAY", static_cast<float>(tel.effector_perforin_granzyme));
            DrawTrueNeonBloomBar("FAS / FASL (RECEPTOR DEATH KISS)", static_cast<float>(tel.effector_fas_fasl));
            DrawTrueNeonBloomBar("MAC COMPLEMENT SYSTEM (NANOBOTS)", static_cast<float>(tel.effector_mac_complement));
            DrawTrueNeonBloomBar("PHAGOCYTOSIS & ROS STORM", static_cast<float>(tel.effector_phagocytosis_ros));
            DrawTrueNeonBloomBar("TISSUE REGENERATION (WNT/VEGF)", static_cast<float>(tel.effector_tissue_regen));

            ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();

            ImGui::TextColored(ImVec4(1.0f, 1.0f, 1.0f, 1.0f), "TOLERANCE AND CHECKPOINTS");
            ImGui::Spacing(); ImGui::Spacing();
            DrawTrueNeonBloomBar("PD-1 / PD-L1 AXIS (TUMOR STEALTH)", static_cast<float>(tel.checkpoint_pd1_pdl1_axis));
            DrawTrueNeonBloomBar("CTLA-4 / CD28 CLASH", static_cast<float>(tel.checkpoint_ctla4_clash));
            DrawTrueNeonBloomBar("TREG SUPPRESSION AURA", static_cast<float>(tel.checkpoint_treg_aura));
            DrawTrueNeonBloomBar("T-CELL EXHAUSTION (TIM-3)", static_cast<float>(tel.checkpoint_t_cell_exhaustion_tim3));
            DrawTrueNeonBloomBar("CHRONIC ANTIGEN EXPOSURE (LAG-3)", static_cast<float>(tel.checkpoint_t_cell_exhaustion_lag3));

            ImGui::EndChild();

            ImGui::PopStyleVar();

            ImGui::Dummy(ImVec2(0.0f, 2.0f));

            ImVec2 btn_size = ImVec2(ImGui::GetContentRegionAvail().x, 50.0f);
            int dots = static_cast<int>(ImGui::GetTime() * 3.0f) % 4;
            std::string dot_str = ""; for (int i = 0; i < dots; ++i) dot_str += ".";

            if (is_processing_) {
                processing_timer_ -= delta_time;
                ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.15f, 0.15f, 0.15f, 1.0f));
                ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.15f, 0.15f, 0.15f, 1.0f));
                ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.15f, 0.15f, 0.15f, 1.0f));
                ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 1.0f, 1.0f, 1.0f));
                std::string btn_text;
                if (current_phase_ == SimulationPhase::IMMORTALITY_ACHIEVED && next_phase_ == SimulationPhase::IMMORTALITY_ACHIEVED) {
                    btn_text = "[AI] EXECUTING PHOENIX RE-SEEDING" + dot_str;
                }
                else { btn_text = "PROCESSING OPERATION" + dot_str; }
                ImGui::Button(btn_text.c_str(), btn_size);
                ImGui::PopStyleColor(4);
                if (processing_timer_ <= 0.0f) { is_processing_ = false; current_phase_ = next_phase_; }
            }
            else {
                if (integration_phase_active_) {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.1f, 0.08f, 0.15f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.1f, 0.08f, 0.15f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.1f, 0.08f, 0.15f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.8f, 0.5f, 1.0f, 1.0f));

                    std::string int_text = "[AI] ANTIGEN INTEGRATION IN PROGRESS" + dot_str;
                    ImGui::Button(int_text.c_str(), btn_size);
                    ImGui::PopStyleColor(4);
                }
                else if (current_phase_ == SimulationPhase::HOMEOSTASIS) {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.08f, 0.1f, 0.12f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.08f, 0.1f, 0.12f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.08f, 0.1f, 0.12f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.5f, 0.5f, 0.5f, 1.0f));
                    std::string ai_text = "[AI] AWAITING BIOLOGICAL THRESHOLD" + dot_str;
                    ImGui::Button(ai_text.c_str(), btn_size);
                    ImGui::PopStyleColor(4);
                }
                else if (current_phase_ == SimulationPhase::INSTABILITY_INDUCED) {
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.05f, 0.15f, 0.08f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.05f, 0.15f, 0.08f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.05f, 0.15f, 0.08f, 1.0f));
                    ImGui::PushStyleColor(ImGuiCol_Text, THEME_NEON_GREEN);

                    std::string ai_btn_text;
                    if (!ai_injection_triggered_) {
                        ai_btn_text = "[AI] MONITORING TELOMERE DEGRADATION" + dot_str;
                    }
                    else {
                        ai_btn_text = "[AI] AUTONOMOUS Z-TUMOR INJECTION IN PROGRESS" + dot_str;
                    }

                    ImGui::Button(ai_btn_text.c_str(), btn_size);
                    ImGui::PopStyleColor(4);
                }
                else {
                    ImVec4 btn_normal = (current_phase_ == SimulationPhase::DEAD) ? ImVec4(0.08f, 0.1f, 0.12f, 1.0f) : ImVec4(0.08f, 0.1f, 0.12f, 1.0f);
                    ImGui::PushStyleColor(ImGuiCol_Button, btn_normal);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, THEME_NEON_GREEN);
                    ImGui::PushStyleColor(ImGuiCol_ButtonActive, THEME_NEON_GREEN);

                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 1.0f, 1.0f, 1.0f));

                    if (current_phase_ == SimulationPhase::DEAD) { ImGui::Button("[FLATLINE] REACTOR DECEASED", btn_size); }
                    else if (current_phase_ == SimulationPhase::OFFLINE) {
                        if (ImGui::Button("INITIATE REACTOR", btn_size)) {
                            is_processing_ = true; processing_timer_ = 2.0f; next_phase_ = SimulationPhase::HOMEOSTASIS;
                            engine_.StartEngine();
                            terminal_.AddLog(LogLevel::INFO, "Initiating metabolic sequence. Powering up bio-reactor...");
                        }
                    }
                    else if (current_phase_ == SimulationPhase::IMMORTALITY_ACHIEVED) {
                        if (ImGui::Button("SHUTDOWN REACTOR", btn_size)) {
                            is_processing_ = true; processing_timer_ = 2.0f; next_phase_ = SimulationPhase::DEAD;
                            engine_.StopEngine();
                            terminal_.AddLog(LogLevel::SYSTEM_DEAD, "MANUAL OVERRIDE: Reactor shutdown initiated.");
                        }
                    }
                    ImGui::PopStyleColor(4);
                }
            }
            ImGui::End();

            // 🛑 PHASE 72: Precision FPS Relocation to Top-Left (Padding X, Y=5.0f)
            char fps_text[64];
            sprintf_s(fps_text, "FPS: %.1f", ImGui::GetIO().Framerate);
            ImVec2 fps_pos = ImVec2(padding, 5.0f);
            ImGui::GetForegroundDrawList()->AddText(fps_pos, IM_COL32(255, 255, 255, 255), fps_text);
        }

        void CyberGraph::RunMainRenderLoop() {
            bool done = false;
            ImVec4 clear_color = ImVec4(0.012f, 0.015f, 0.018f, 1.00f);
            auto last_time = std::chrono::high_resolution_clock::now();

            double prev_tel_val = 100.0;
            double prev_mut_val = 0.0;
            uint64_t prev_tick_val = 0;

            while (!done) {
                MSG msg;
                while (::PeekMessage(&msg, nullptr, 0U, 0U, PM_REMOVE)) {
                    ::TranslateMessage(&msg); ::DispatchMessage(&msg);
                    if (msg.message == WM_QUIT) done = true;
                }
                if (done) break;

                auto current_time = std::chrono::high_resolution_clock::now();
                float delta_time = std::chrono::duration<float>(current_time - last_time).count();
                last_time = current_time;
                delta_time = std::min(delta_time, 0.1f);

                if (injection_cooldown_timer_ > 0.0f) {
                    injection_cooldown_timer_ -= delta_time;
                    if (injection_cooldown_timer_ <= 0.0f) integration_phase_active_ = false;
                }

                Core::BioTelemetry frame_tel;
                std::vector<Cellular::Cell*> frame_cells;

                engine_.SyncAndFetchUIState(frame_tel, frame_cells);

                if (current_phase_ != SimulationPhase::OFFLINE && current_phase_ != SimulationPhase::DEAD) {

                    // 🛑 PHASE 72: Shield::SentinelGuard removed from UI Thread!

                    if (!is_processing_) {
                        if (current_phase_ == SimulationPhase::HOMEOSTASIS) {
                            if (frame_tel.avg_telomere_length < 65.0 && frame_tel.total_population > 0) {
                                is_processing_ = true; processing_timer_ = 2.5f; next_phase_ = SimulationPhase::INSTABILITY_INDUCED;
                                terminal_.AddLog(LogLevel::WARNING, "[AI OVERRIDE] Biological threshold met. Inducing genomic instability...");
                            }
                        }
                        else if (current_phase_ == SimulationPhase::INSTABILITY_INDUCED) {

                            double velocity_telomere = 0.0;
                            double velocity_mutation = 0.0;

                            if (frame_tel.epoch_ticks > prev_tick_val) {
                                double dt = static_cast<double>(frame_tel.epoch_ticks - prev_tick_val);
                                velocity_telomere = (prev_tel_val - frame_tel.avg_telomere_length) / dt;
                                velocity_mutation = (frame_tel.avg_mutation_load - prev_mut_val) / dt;
                            }

                            prev_tel_val = frame_tel.avg_telomere_length;
                            prev_mut_val = frame_tel.avg_mutation_load;
                            prev_tick_val = frame_tel.epoch_ticks;

                            double dynamic_tel_thresh = 55.0 + (std::max(0.0, velocity_telomere) * 1000.0);
                            dynamic_tel_thresh = std::clamp(dynamic_tel_thresh, 55.0, 80.0);

                            double dynamic_mut_thresh = 0.25 - (std::max(0.0, velocity_mutation) * 20.0);
                            dynamic_mut_thresh = std::clamp(dynamic_mut_thresh, 0.15, 0.25);

                            static bool warning_logged = false;
                            if (frame_tel.avg_mutation_load > 0.20 && frame_tel.total_population > 0 && !warning_logged) {
                                terminal_.AddLog(LogLevel::WARNING, "[AI ALERT] Optimal mutation window detected. Analyzing genomic instability...");
                                warning_logged = true;
                            }

                            bool critical_telomeres = (frame_tel.avg_telomere_length < dynamic_tel_thresh);
                            bool critical_mutations = (frame_tel.avg_mutation_load > dynamic_mut_thresh);

                            if ((critical_telomeres || critical_mutations) && !ai_injection_triggered_ && frame_tel.total_population > 0) {

                                if (frame_tel.avg_telomere_length >= 55.0 || frame_tel.avg_mutation_load <= 0.25) {
                                    terminal_.AddLog(LogLevel::WARNING, "[AI PRECOGNITION] High degradation velocity detected. Preemptive seeding initiated.");
                                }

                                ai_injection_triggered_ = true;
                                is_processing_ = true;
                                processing_timer_ = 3.5f;
                                next_phase_ = SimulationPhase::IMMORTALITY_ACHIEVED;

                                terminal_.AddLog(LogLevel::CRITICAL, "[AI OVERRIDE] CRITICAL DEGRADATION. CALCULATING ORGANIC TITRATION DOSE...");

                                Cellular::BiologicalSex sex_enum = (ui_selected_sex_ == 0) ? Cellular::BiologicalSex::MALE : Cellular::BiologicalSex::FEMALE;
                                auto env = engine_.GetEnvironmentState();
                                auto immune = engine_.GetImmuneState();
                                double dynamic_dose_ratio = 0.05;

                                size_t hacked_count = OncoLogic::TelomeraseExploit::ExecutePayload(frame_cells, frame_tel.total_population, dynamic_dose_ratio, sex_enum, ui_current_age_, ui_target_age_, env, immune, frame_tel.epoch_ticks);

                                if (hacked_count > 0) {
                                    terminal_.AddLog(LogLevel::CRITICAL, "[AI AUTONOMY] DOSE: 5%%. %llu SURVIVED INITIAL IMMUNE SHOCK.", hacked_count);
                                    injection_cooldown_timer_ = 15.0f;
                                    integration_phase_active_ = true;
                                }
                                else {
                                    terminal_.AddLog(LogLevel::WARNING, "[AI AUTONOMY] TITRATION FAILED. 0 SURVIVED. TOTAL IMMUNE ERADICATION.");
                                }
                            }
                        }
                        else if (current_phase_ == SimulationPhase::IMMORTALITY_ACHIEVED) {
                            if (frame_tel.oncogenic_cells == 0 && frame_tel.total_population > 0 && !integration_phase_active_ && injection_cooldown_timer_ <= 0.0f) {
                                is_processing_ = true; processing_timer_ = 2.5f; next_phase_ = SimulationPhase::IMMORTALITY_ACHIEVED;
                                terminal_.AddLog(LogLevel::CRITICAL, "[AI OVERRIDE] GLAND DESTRUCTION DETECTED. INITIATING PHOENIX RE-SEEDING...");

                                Cellular::BiologicalSex sex_enum = (ui_selected_sex_ == 0) ? Cellular::BiologicalSex::MALE : Cellular::BiologicalSex::FEMALE;
                                auto env = engine_.GetEnvironmentState();
                                auto immune = engine_.GetImmuneState();
                                double phoenix_dose_ratio = 0.02;

                                size_t seeded_count = OncoLogic::TelomeraseExploit::ExecutePayload(frame_cells, frame_tel.total_population, phoenix_dose_ratio, sex_enum, ui_current_age_, ui_target_age_, env, immune, frame_tel.epoch_ticks);

                                if (seeded_count > 0) {
                                    terminal_.AddLog(LogLevel::WARNING, "[PHOENIX PROTOCOL] DOSE: 2%%. %llu SURVIVED. GLAND RESURRECTED.", seeded_count);
                                    lazarus_achieved_ = false;
                                    injection_cooldown_timer_ = 12.0f;
                                    integration_phase_active_ = true;
                                }
                                else {
                                    terminal_.AddLog(LogLevel::CRITICAL, "[PHOENIX PROTOCOL] 2%% DOSE REJECTED. 0 SURVIVED.");
                                }
                            }
                        }
                    }

                    ReactorVisualState old_state = current_state_;
                    double cancer_ratio = frame_tel.total_population > 0 ? static_cast<double>(frame_tel.oncogenic_cells) / frame_tel.total_population : 0.0;

                    bool is_symbiosis = (current_phase_ == SimulationPhase::IMMORTALITY_ACHIEVED) && (frame_tel.immortality_control >= 0.85) && (cancer_ratio >= 0.10 && cancer_ratio <= 0.85);

                    if (is_symbiosis && !lazarus_achieved_) { lazarus_achieved_ = true; terminal_.AddLog(LogLevel::INFO, "[LAZARUS INVERSION SUCCESSFUL. ETERNAL SYMBIOSIS ACHIEVED. SYSTEM STABILIZED.]"); }
                    else if (!is_symbiosis && lazarus_achieved_) { lazarus_achieved_ = false; }

                    double organic_ratio = frame_tel.total_population > 0 ? static_cast<double>(frame_tel.healthy_cells + frame_tel.senescent_cells) / static_cast<double>(frame_tel.total_population) : 0.0;
                    bool is_system_dead = (frame_tel.total_population == 0) || (frame_tel.total_population > 0 && organic_ratio < 0.20);

                    if (is_system_dead) {
                        current_phase_ = SimulationPhase::DEAD;
                        current_state_ = ReactorVisualState::FLATLINE_WHITE;
                        engine_.StopEngine();
                        if (frame_tel.total_population == 0) {
                            terminal_.AddLog(LogLevel::SYSTEM_DEAD, "FLATLINE. TISSUE NECROSIS COMPLETE.");
                        }
                        else {
                            terminal_.AddLog(LogLevel::SYSTEM_DEAD, "FLATLINE. SYSTEMIC ORGAN FAILURE (ORGANIC MASS < 20%%). SUBJECT DECEASED.");
                        }
                        PlayAudioAlarm(current_state_);
                    }
                    else if (is_symbiosis) { current_state_ = ReactorVisualState::STABLE_GREEN; }
                    else if (frame_tel.tumor_probability > 0.8 || cancer_ratio > 0.85) { current_state_ = ReactorVisualState::CRITICAL_RED; }
                    else if (frame_tel.systemic_inflammation > 0.5 || frame_tel.pulmonary_o2_capacity < 0.5) { current_state_ = ReactorVisualState::DEGRADING_ORANGE; }
                    else { current_state_ = ReactorVisualState::STABLE_GREEN; }

                    if (current_state_ != old_state && current_phase_ != SimulationPhase::DEAD) {
                        PlayAudioAlarm(current_state_);
                        if (current_state_ == ReactorVisualState::CRITICAL_RED) terminal_.AddLog(LogLevel::CRITICAL, "WARNING: TUMOR METASTASIS. IMMUNE SYSTEM OVERWHELMED.");
                    }
                }

                ImGui_ImplDX11_NewFrame(); ImGui_ImplWin32_NewFrame(); ImGui::NewFrame();
                RenderBackgroundParticles(delta_time);

                RenderDashboardAndTerminal(frame_tel, delta_time);

                ImGui::Render();
                const float clear_color_with_alpha[4] = { clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w };
                pd3dDeviceContext_->OMSetRenderTargets(1, &pMainRenderTargetView_, nullptr);
                pd3dDeviceContext_->ClearRenderTargetView(pMainRenderTargetView_, clear_color_with_alpha);
                ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());
                pSwapChain_->Present(1, 0);
            }
        }

    }
}