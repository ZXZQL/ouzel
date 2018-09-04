// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#pragma once

#include <cstdint>
#include <functional>
#include <memory>
#include <string>
#include <vector>
#include <queue>
#include <set>
#include <atomic>
#include "graphics/Texture.hpp"
#include "math/Rect.hpp"
#include "math/Matrix4.hpp"
#include "math/Size2.hpp"
#include "math/Color.hpp"

namespace ouzel
{
    class Engine;
    class Window;

    namespace graphics
    {
        class RenderDevice;
        class BlendStateResource;
        class BufferResource;
        class TextureResource;
        class ShaderResource;

        class Renderer final
        {
            friend Engine;
            friend Window;
        public:
            enum class Driver
            {
                DEFAULT,
                EMPTY,
                OPENGL,
                DIRECT3D11,
                METAL
            };

            enum class DrawMode
            {
                POINT_LIST,
                LINE_LIST,
                LINE_STRIP,
                TRIANGLE_LIST,
                TRIANGLE_STRIP
            };

            enum class CullMode
            {
                NONE,
                FRONT,
                BACK
            };

            enum class FillMode
            {
                SOLID,
                WIREFRAME
            };

            Renderer(const Renderer&) = delete;
            Renderer& operator=(const Renderer&) = delete;

            Renderer(Renderer&&) = delete;
            Renderer& operator=(Renderer&&) = delete;

            static std::set<Driver> getAvailableRenderDrivers();

            inline RenderDevice* getDevice() const { return device.get(); }

            void executeOnRenderThread(const std::function<void(void)>& func);

            void setClearColorBuffer(bool clear);
            inline bool getClearColorBuffer() const { return clearColorBuffer; }

            void setClearDepthBuffer(bool clear);
            inline bool getClearDepthBuffer() const { return clearDepthBuffer; }

            void setClearColor(Color color);
            inline Color getClearColor() const { return clearColor; }

            void setClearDepth(float newClearDepth);
            inline float getClearDepth() const { return clearDepth; }

            inline const Size2& getSize() const { return size; }

            void saveScreenshot(const std::string& filename);

            void setRenderTarget(TextureResource* renderTarget);
            void clear(TextureResource* renderTarget);
            void setCullMode(Renderer::CullMode cullMode);
            void setFillMode(Renderer::FillMode fillMode);
            void setScissorTest(bool enabled, const Rect& rectangle);
            void setViewport(const Rect& viewport);
            void setDepthState(bool depthTest, bool depthWrite);
            void setPipelineState(BlendStateResource* blendState,
                                  ShaderResource* shader);
            void draw(BufferResource* indexBuffer,
                      uint32_t indexCount,
                      uint32_t indexSize,
                      BufferResource* vertexBuffer,
                      DrawMode drawMode,
                      uint32_t startIndex);
            void pushDebugMarker(const std::string& name);
            void popDebugMarker();
            void setShaderConstants(std::vector<std::vector<float>> fragmentShaderConstants,
                                    std::vector<std::vector<float>> vertexShaderConstants);
            void setTextures(const std::vector<TextureResource*>& textures);

            void waitForNextFrame();

        protected:
            explicit Renderer(Driver driver,
                              Window* newWindow,
                              const Size2& newSize,
                              uint32_t newSampleCount,
                              Texture::Filter newTextureFilter,
                              uint32_t newMaxAnisotropy,
                              bool newVerticalSync,
                              bool newDepth,
                              bool newDebugRenderer);

            void setSize(const Size2& newSize);

            std::unique_ptr<RenderDevice> device;

            Size2 size;
            Color clearColor;
            float clearDepth = 1.0;
            bool clearColorBuffer = true;
            bool clearDepthBuffer = false;
        };
    } // namespace graphics
} // namespace ouzel
