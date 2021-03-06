// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#include "core/Setup.h"

#if OUZEL_PLATFORM_IOS && OUZEL_COMPILE_METAL

#include "RenderDeviceMetalIOS.hpp"
#include "MetalView.h"
#include "core/Engine.hpp"
#include "core/Window.hpp"
#include "core/ios/NativeWindowIOS.hpp"
#include "utils/Log.hpp"

static void renderCallback(void* userInfo)
{
    try
    {
        ouzel::graphics::RenderDeviceMetalIOS* renderDevice = static_cast<ouzel::graphics::RenderDeviceMetalIOS*>(userInfo);
        renderDevice->renderCallback();
    }
    catch (const std::exception& e)
    {
        ouzel::engine->log(ouzel::Log::Level::ERR) << e.what();
    }
}

namespace ouzel
{
    namespace graphics
    {
        RenderDeviceMetalIOS::RenderDeviceMetalIOS(const std::function<void(const Event&)>& initCallback):
            RenderDeviceMetal(initCallback),
            displayLink(::renderCallback, this)
        {
        }

        RenderDeviceMetalIOS::~RenderDeviceMetalIOS()
        {
            displayLink.stop();
            CommandBuffer commandBuffer;
            commandBuffer.commands.push(std::unique_ptr<Command>(new PresentCommand()));
            submitCommandBuffer(std::move(commandBuffer));
        }

        void RenderDeviceMetalIOS::init(Window* newWindow,
                                        const Size2& newSize,
                                        uint32_t newSampleCount,
                                        Texture::Filter newTextureFilter,
                                        uint32_t newMaxAnisotropy,
                                        bool newVerticalSync,
                                        bool newDepth,
                                        bool newDebugRenderer)
        {
            RenderDeviceMetal::init(newWindow,
                                    newSize,
                                    newSampleCount,
                                    newTextureFilter,
                                    newMaxAnisotropy,
                                    newVerticalSync,
                                    newDepth,
                                    newDebugRenderer);

            MetalView* view = (MetalView*)static_cast<NativeWindowIOS*>(newWindow->getNativeWindow())->getNativeView();

            metalLayer = (CAMetalLayer*)view.layer;
            metalLayer.device = device;
            CGSize drawableSize = CGSizeMake(newSize.width, newSize.height);
            metalLayer.drawableSize = drawableSize;

            colorFormat = metalLayer.pixelFormat;

            displayLink.start(verticalSync);
        }

        void RenderDeviceMetalIOS::renderCallback()
        {
            process();
        }
    } // namespace graphics
} // namespace ouzel

#endif
