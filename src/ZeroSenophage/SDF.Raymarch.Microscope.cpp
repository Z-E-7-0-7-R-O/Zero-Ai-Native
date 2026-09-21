// --- START OF FILE SDF.Raymarch.Microscope.cpp ---

#include "SDF.Raymarch.Microscope.h"
#include "Matrix.Orchestrator.h" 
#include "Shader.Payload.h"
#include <d3dcompiler.h>
#include <chrono>

#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "d3dcompiler.lib")
#pragma comment(lib, "dxgi.lib")

OpticalMicroscopeSubsystem::OpticalMicroscopeSubsystem(HWND hwnd) : target_hwnd(hwnd), d3d_device(nullptr),
d3d_context(nullptr), swap_chain(nullptr), render_target_view(nullptr),
vertex_shader(nullptr), pixel_shader(nullptr), optical_constant_buffer(nullptr),
biological_density_texture(nullptr), biological_density_srv(nullptr), cuda_shared_optical_resource(nullptr),
biochemical_state_texture(nullptr), biochemical_state_srv(nullptr), cuda_shared_biochemical_resource(nullptr),
texture_sampler(nullptr), mapped_optical_array(nullptr), mapped_biochemical_array(nullptr),
optical_render_stream(nullptr), dxgi_adapter3(nullptr), render_frame_count(0),
cached_wddm_penalty(0.0), cached_wddm_exceeded(0.0)
{
    InitializeSubsystem();
}

OpticalMicroscopeSubsystem::~OpticalMicroscopeSubsystem() {
    // Phase 82: Clean release of DXGI3 Adapter interface
    if (dxgi_adapter3) dxgi_adapter3->Release();

    // Phase 74.1: Clean destruction of the non-blocking stream
    if (optical_render_stream) cudaStreamDestroy(optical_render_stream);

    if (cuda_shared_biochemical_resource) cudaGraphicsUnregisterResource(cuda_shared_biochemical_resource);
    if (cuda_shared_optical_resource) cudaGraphicsUnregisterResource(cuda_shared_optical_resource);
    if (biochemical_state_srv) biochemical_state_srv->Release();
    if (biochemical_state_texture) biochemical_state_texture->Release();
    if (biological_density_srv) biological_density_srv->Release();
    if (biological_density_texture) biological_density_texture->Release();
    if (texture_sampler) texture_sampler->Release();
    if (optical_constant_buffer) optical_constant_buffer->Release();
    if (render_target_view) render_target_view->Release();
    if (swap_chain) swap_chain->Release();
    if (d3d_context) d3d_context->Release();
    if (d3d_device) d3d_device->Release();
    if (vertex_shader) vertex_shader->Release();
    if (pixel_shader) pixel_shader->Release();
}

void OpticalMicroscopeSubsystem::InitializeSubsystem() {
    DXGI_SWAP_CHAIN_DESC scd = { 0 };
    scd.BufferCount = 1;
    scd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    scd.BufferDesc.Width = BiophysicalConstants::ENVIRONMENT_WIDTH;
    scd.BufferDesc.Height = BiophysicalConstants::ENVIRONMENT_HEIGHT;
    scd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    scd.OutputWindow = target_hwnd;
    scd.SampleDesc.Count = 1;
    scd.Windowed = TRUE;

    D3D11CreateDeviceAndSwapChain(
        NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, NULL, 0,
        D3D11_SDK_VERSION, &scd, &swap_chain, &d3d_device, NULL, &d3d_context
    );

    ID3D11Texture2D* back_buffer = nullptr;
    swap_chain->GetBuffer(0, __uuidof(ID3D11Texture2D), (LPVOID*)&back_buffer);
    d3d_device->CreateRenderTargetView(back_buffer, NULL, &render_target_view);
    back_buffer->Release();

    d3d_context->OMSetRenderTargets(1, &render_target_view, NULL);

    D3D11_VIEWPORT viewport = { 0 };
    viewport.TopLeftX = 0;
    viewport.TopLeftY = 0;
    viewport.Width = static_cast<FLOAT>(BiophysicalConstants::ENVIRONMENT_WIDTH);
    viewport.Height = static_cast<FLOAT>(BiophysicalConstants::ENVIRONMENT_HEIGHT);
    d3d_context->RSSetViewports(1, &viewport);

    // Phase 74.1: Instantiation of the strictly isolated, Non-Blocking CUDA Stream
    cudaStreamCreateWithFlags(&optical_render_stream, cudaStreamNonBlocking);

    // Phase 82: Extraction of the DXGI3 interface to interrogate OS-level VRAM Eviction events
    IDXGIFactory4* dxgi_factory = nullptr;
    if (SUCCEEDED(CreateDXGIFactory1(__uuidof(IDXGIFactory4), (void**)&dxgi_factory))) {
        IDXGIAdapter1* adapter1 = nullptr;
        if (SUCCEEDED(dxgi_factory->EnumAdapters1(0, &adapter1))) {
            adapter1->QueryInterface(__uuidof(IDXGIAdapter3), (void**)&dxgi_adapter3);
            adapter1->Release();
        }
        dxgi_factory->Release();
    }

    CompileShaders();
    AllocateSharedMemorySubsystem();
}

void OpticalMicroscopeSubsystem::CompileShaders() {
    ID3DBlob* vs_blob = nullptr;
    ID3DBlob* ps_blob = nullptr;

    SIZE_T shader_length = sizeof(MICROSCOPE_LENS_HLSL) - 1;

    D3DCompile(MICROSCOPE_LENS_HLSL, shader_length, NULL, NULL, NULL, "VS_Main", "vs_5_0", 0, 0, &vs_blob, NULL);
    D3DCompile(MICROSCOPE_LENS_HLSL, shader_length, NULL, NULL, NULL, "PS_Main", "ps_5_0", 0, 0, &ps_blob, NULL);

    d3d_device->CreateVertexShader(vs_blob->GetBufferPointer(), vs_blob->GetBufferSize(), NULL, &vertex_shader);
    d3d_device->CreatePixelShader(ps_blob->GetBufferPointer(), ps_blob->GetBufferSize(), NULL, &pixel_shader);

    d3d_context->IASetInputLayout(NULL);
    d3d_context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    vs_blob->Release();
    ps_blob->Release();
}

void OpticalMicroscopeSubsystem::AllocateSharedMemorySubsystem() {
    D3D11_BUFFER_DESC cb_desc = { 0 };
    cb_desc.Usage = D3D11_USAGE_DYNAMIC;
    cb_desc.ByteWidth = sizeof(OpticalConstantBuffer);
    cb_desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
    cb_desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    d3d_device->CreateBuffer(&cb_desc, NULL, &optical_constant_buffer);

    D3D11_TEXTURE2D_DESC tex_desc = { 0 };
    tex_desc.Width = BiophysicalConstants::ENVIRONMENT_WIDTH;
    tex_desc.Height = BiophysicalConstants::ENVIRONMENT_HEIGHT;
    tex_desc.MipLevels = 1;
    tex_desc.ArraySize = 1;
    tex_desc.Format = DXGI_FORMAT_R32G32B32A32_FLOAT;
    tex_desc.SampleDesc.Count = 1;
    tex_desc.Usage = D3D11_USAGE_DEFAULT;
    tex_desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    tex_desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;

    d3d_device->CreateTexture2D(&tex_desc, NULL, &biological_density_texture);
    d3d_device->CreateShaderResourceView(biological_density_texture, NULL, &biological_density_srv);

    d3d_device->CreateTexture2D(&tex_desc, NULL, &biochemical_state_texture);
    d3d_device->CreateShaderResourceView(biochemical_state_texture, NULL, &biochemical_state_srv);

    cudaGraphicsD3D11RegisterResource(&cuda_shared_optical_resource, biological_density_texture, cudaGraphicsRegisterFlagsNone);
    cudaGraphicsD3D11RegisterResource(&cuda_shared_biochemical_resource, biochemical_state_texture, cudaGraphicsRegisterFlagsNone);

    D3D11_SAMPLER_DESC samp_desc = {};
    samp_desc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    samp_desc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
    samp_desc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
    samp_desc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;
    samp_desc.ComparisonFunc = D3D11_COMPARISON_NEVER;
    d3d_device->CreateSamplerState(&samp_desc, &texture_sampler);
}

void OpticalMicroscopeSubsystem::RenderFrame(float current_time_tick, BiophysicalSimulationOrchestrator* orchestrator) {

    ID3D11ShaderResourceView* null_srv[2] = { nullptr, nullptr };
    d3d_context->PSSetShaderResources(0, 2, null_srv);

    cudaGraphicsResource_t resources[2] = { cuda_shared_optical_resource, cuda_shared_biochemical_resource };

    // Phase 82: High-Resolution Precision Probe for D3D11-CUDA Interop Contention Lock
    auto interop_start = std::chrono::high_resolution_clock::now();

    // Phase 86 implementation note: By pacing RenderFrame calls externally, 
    // cudaGraphicsMapResources now exclusively locks the VRAM only during precise observation ticks (60Hz).
    cudaGraphicsMapResources(2, resources, optical_render_stream);

    cudaGraphicsSubResourceGetMappedArray(&mapped_optical_array, cuda_shared_optical_resource, 0, 0);
    cudaGraphicsSubResourceGetMappedArray(&mapped_biochemical_array, cuda_shared_biochemical_resource, 0, 0);

    size_t matrix_row_pitch = BiophysicalConstants::ENVIRONMENT_WIDTH * 4 * sizeof(float);

    // Thread-Safe and completely Lock-Free asynchronous dispatch
    orchestrator->FetchRenderState(
        mapped_optical_array,
        mapped_biochemical_array,
        matrix_row_pitch,
        BiophysicalConstants::ENVIRONMENT_HEIGHT,
        optical_render_stream
    );

    cudaGraphicsUnmapResources(2, resources, optical_render_stream);

    auto interop_end = std::chrono::high_resolution_clock::now();
    double interop_latency_ms = std::chrono::duration<double, std::milli>(interop_end - interop_start).count();

    // Phase 74.1: CRITICAL GPU BARRIER. The CPU Render thread safely waits here until the VRAM copy operations 
    // submitted to the optical_render_stream are fully deposited into the D3D11 textures. 
    cudaStreamSynchronize(optical_render_stream);

    D3D11_MAPPED_SUBRESOURCE mapped_resource;
    d3d_context->Map(optical_constant_buffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped_resource);
    OpticalConstantBuffer* opt_buffer = static_cast<OpticalConstantBuffer*>(mapped_resource.pData);
    opt_buffer->biological_time = current_time_tick;
    opt_buffer->resolution_x = static_cast<float>(BiophysicalConstants::ENVIRONMENT_WIDTH);
    opt_buffer->resolution_y = static_cast<float>(BiophysicalConstants::ENVIRONMENT_HEIGHT);
    opt_buffer->padding_alignment = 0.0f;
    d3d_context->Unmap(optical_constant_buffer, 0);

    float clear_color[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
    d3d_context->ClearRenderTargetView(render_target_view, clear_color);

    d3d_context->VSSetShader(vertex_shader, 0, 0);
    d3d_context->PSSetShader(pixel_shader, 0, 0);
    d3d_context->PSSetConstantBuffers(0, 1, &optical_constant_buffer);

    ID3D11ShaderResourceView* bind_srvs[2] = { biological_density_srv, biochemical_state_srv };
    d3d_context->PSSetShaderResources(0, 2, bind_srvs);
    d3d_context->PSSetSamplers(0, 1, &texture_sampler);

    d3d_context->Draw(3, 0);

    // Phase 82: High-Resolution Precision Probe for DWM Present Backpressure
    auto present_start = std::chrono::high_resolution_clock::now();
    swap_chain->Present(0, 0);
    auto present_end = std::chrono::high_resolution_clock::now();
    double present_latency_ms = std::chrono::duration<double, std::milli>(present_end - present_start).count();

    // Phase 82: Low-Frequency WDDM Memory Eviction Polling
    if (render_frame_count % 60 == 0 && dxgi_adapter3) {
        DXGI_QUERY_VIDEO_MEMORY_INFO mem_info;
        if (SUCCEEDED(dxgi_adapter3->QueryVideoMemoryInfo(0, DXGI_MEMORY_SEGMENT_GROUP_LOCAL, &mem_info))) {
            if (mem_info.CurrentUsage > mem_info.Budget) {
                cached_wddm_penalty = static_cast<double>(mem_info.CurrentUsage - mem_info.Budget);
                cached_wddm_exceeded = 1.0;
            }
            else {
                cached_wddm_penalty = 0.0;
                cached_wddm_exceeded = 0.0;
            }
        }
    }
    render_frame_count++;

    // Phase 82: Funneling all optical subsystem metrics safely to the Orchestrator
    orchestrator->UpdateOpticalTelemetry(cached_wddm_penalty, cached_wddm_exceeded, interop_latency_ms, present_latency_ms);
}
// --- END OF FILE SDF.Raymarch.Microscope.cpp ---