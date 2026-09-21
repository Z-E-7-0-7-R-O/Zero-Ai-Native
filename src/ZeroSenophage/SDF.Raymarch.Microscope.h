// --- START OF FILE SDF.Raymarch.Microscope.h ---

#ifndef OPTICAL_MICROSCOPE_SUBSYSTEM_H
#define OPTICAL_MICROSCOPE_SUBSYSTEM_H

#include <d3d11.h>
#include <dxgi1_4.h>
#include <cuda_d3d11_interop.h>
#include "Biochemical.Constants.h"

class BiophysicalSimulationOrchestrator;

struct OpticalConstantBuffer {
    float biological_time;
    float resolution_x;
    float resolution_y;
    float padding_alignment;
};

class OpticalMicroscopeSubsystem {
public:
    OpticalMicroscopeSubsystem(HWND hwnd);
    ~OpticalMicroscopeSubsystem();

    void InitializeSubsystem();

    // RenderFrame executes totally asynchronously relying on hardware CUDA stream orchestration
    void RenderFrame(float current_time_tick, BiophysicalSimulationOrchestrator* orchestrator);

private:
    HWND target_hwnd;

    ID3D11Device* d3d_device;
    ID3D11DeviceContext* d3d_context;
    IDXGISwapChain* swap_chain;
    ID3D11RenderTargetView* render_target_view;

    ID3D11VertexShader* vertex_shader;
    ID3D11PixelShader* pixel_shader;

    ID3D11Buffer* optical_constant_buffer;
    ID3D11SamplerState* texture_sampler;

    ID3D11Texture2D* biological_density_texture;
    ID3D11ShaderResourceView* biological_density_srv;

    ID3D11Texture2D* biochemical_state_texture;
    ID3D11ShaderResourceView* biochemical_state_srv;

    cudaArray_t mapped_optical_array;
    cudaGraphicsResource_t cuda_shared_optical_resource;

    cudaArray_t mapped_biochemical_array;
    cudaGraphicsResource_t cuda_shared_biochemical_resource;

    // Phase 74.1: Dedicated Non-Blocking Stream to bypass WDDM Command Queue Stalls
    cudaStream_t optical_render_stream;

    // Phase 82: Hardware OS-Interrogation Variables
    IDXGIAdapter3* dxgi_adapter3;
    unsigned long long render_frame_count;
    double cached_wddm_penalty;
    double cached_wddm_exceeded;

    void CompileShaders();
    void AllocateSharedMemorySubsystem();
};

#endif // OPTICAL_MICROSCOPE_SUBSYSTEM_H
// --- END OF FILE SDF.Raymarch.Microscope.h ---