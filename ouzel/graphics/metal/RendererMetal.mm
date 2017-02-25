// Copyright (C) 2017 Elviss Strazdins
// This file is part of the Ouzel engine.

#include "core/CompileConfig.h"
#include "RendererMetal.h"
#include "TextureMetal.h"
#include "ShaderMetal.h"
#include "MeshBufferMetal.h"
#include "BufferMetal.h"
#include "BlendStateMetal.h"
#include "events/EventDispatcher.h"
#if OUZEL_PLATFORM_MACOS
    #include "core/macos/WindowMacOS.h"
    #include "ColorPSMacOS.h"
    #include "ColorVSMacOS.h"
    #include "TexturePSMacOS.h"
    #include "TextureVSMacOS.h"
    #define COLOR_PIXEL_SHADER_METAL ColorPSMacOS_metallib
    #define COLOR_VERTEX_SHADER_METAL ColorVSMacOS_metallib
    #define TEXTURE_PIXEL_SHADER_METAL TexturePSMacOS_metallib
    #define TEXTURE_VERTEX_SHADER_METAL TextureVSMacOS_metallib
#elif OUZEL_PLATFORM_TVOS
    #include "core/tvos/WindowTVOS.h"
    #include "ColorPSTVOS.h"
    #include "ColorVSTVOS.h"
    #include "TexturePSTVOS.h"
    #include "TextureVSTVOS.h"
    #define COLOR_PIXEL_SHADER_METAL ColorPSTVOS_metallib
    #define COLOR_VERTEX_SHADER_METAL ColorVSTVOS_metallib
    #define TEXTURE_PIXEL_SHADER_METAL TexturePSTVOS_metallib
    #define TEXTURE_VERTEX_SHADER_METAL TextureVSTVOS_metallib
#elif OUZEL_PLATFORM_IOS
    #include "core/ios/WindowIOS.h"
    #include "ColorPSIOS.h"
    #include "ColorVSIOS.h"
    #include "TexturePSIOS.h"
    #include "TextureVSIOS.h"
    #define COLOR_PIXEL_SHADER_METAL ColorPSIOS_metallib
    #define COLOR_VERTEX_SHADER_METAL ColorVSIOS_metallib
    #define TEXTURE_PIXEL_SHADER_METAL TexturePSIOS_metallib
    #define TEXTURE_VERTEX_SHADER_METAL TextureVSIOS_metallib
#endif
#include "core/Engine.h"
#include "core/Cache.h"
#include "utils/Log.h"
#include "stb_image_write.h"

namespace ouzel
{
    namespace graphics
    {
        bool RendererMetal::available()
        {
            id<MTLDevice> device = MTLCreateSystemDefaultDevice();

            if (device)
            {
                [device release];
                return true;
            }

            return false;
        }

        RendererMetal::RendererMetal():
            Renderer(Driver::METAL)
        {
            apiMajorVersion = 1;
            apiMinorVersion = 0;

            std::fill(std::begin(depthStencilStates), std::end(depthStencilStates), Nil);
        }

        RendererMetal::~RendererMetal()
        {
            resourceDeleteSet.clear();
            resources.clear();

            for (uint32_t state = 0; state < 4; ++state)
            {
                if (depthStencilStates[state])
                {
                    [depthStencilStates[state] release];
                }
            }

            for (const auto& samplerState : samplerStates)
            {
                [samplerState.second release];
            }

            if (depthTexture)
            {
                [depthTexture release];
            }

            if (msaaTexture)
            {
                [msaaTexture release];
            }

            if (currentRenderCommandEncoder)
            {
                [currentRenderCommandEncoder release];
            }

            if (currentCommandBuffer)
            {
                [currentCommandBuffer release];
            }

            for (const auto& pipelineState : pipelineStates)
            {
                [pipelineState.second release];
            }

            if (commandQueue)
            {
                [commandQueue release];
            }

            if (renderPassDescriptor)
            {
                [renderPassDescriptor release];
            }

            if (device)
            {
                [device release];
            }
        }

        bool RendererMetal::init(Window* newWindow,
                                 const Size2& newSize,
                                 uint32_t newSampleCount,
                                 Texture::Filter newTextureFilter,
                                 uint32_t newMaxAnisotropy,
                                 PixelFormat newBackBufferFormat,
                                 bool newVerticalSync,
                                 bool newDepth)
        {
            if (!Renderer::init(newWindow,
                                newSize,
                                newSampleCount,
                                newTextureFilter,
                                newMaxAnisotropy,
                                newBackBufferFormat,
                                newVerticalSync,
                                newDepth))
            {
                return false;
            }

            inflightSemaphore = dispatch_semaphore_create(3); // allow encoding up to 3 command buffers simultaneously

            device = MTLCreateSystemDefaultDevice();

            if (!device)
            {
                Log(Log::Level::ERR) << "Failed to create Metal device";
                return false;
            }

            if (device.name)
            {
                Log(Log::Level::INFO) << "Using " << [device.name cStringUsingEncoding:NSUTF8StringEncoding] << " for rendering";
            }

#if OUZEL_PLATFORM_MACOS
            view = (MTKViewPtr)static_cast<WindowMacOS*>(window)->getNativeView();
#elif OUZEL_PLATFORM_TVOS
            view = (MTKViewPtr)static_cast<WindowTVOS*>(window)->getNativeView();
#elif OUZEL_PLATFORM_IOS
            view = (MTKViewPtr)static_cast<WindowIOS*>(window)->getNativeView();
#endif
            view.device = device;
            view.sampleCount = sampleCount;
            view.framebufferOnly = NO; // for screenshot capturing

            colorFormat = view.colorPixelFormat;

            if (depth)
            {
                view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
                depthFormat = view.depthStencilPixelFormat;

                for (uint32_t state = 0; state < 4; ++state)
                {
                    MTLDepthStencilDescriptor* depthStencilDescriptor = [MTLDepthStencilDescriptor new];
                    depthStencilDescriptor.depthCompareFunction = (state & 0x01) ? MTLCompareFunctionLessEqual : MTLCompareFunctionAlways; // read
                    depthStencilDescriptor.depthWriteEnabled = (state & 0x02) ? YES : NO; // write
                    depthStencilStates[state] = [device newDepthStencilStateWithDescriptor:depthStencilDescriptor];
                    [depthStencilDescriptor release];
                }
            }

            renderPassDescriptor = [[MTLRenderPassDescriptor renderPassDescriptor] retain];

            if (!renderPassDescriptor)
            {
                Log(Log::Level::ERR) << "Failed to create Metal render pass descriptor";
                return false;
            }

            renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 0.0f);
            renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
            renderPassDescriptor.depthAttachment.loadAction = MTLLoadActionClear;
            renderPassDescriptor.depthAttachment.clearDepth = 1.0f;
            renderPassDescriptor.depthAttachment.storeAction = MTLStoreActionStore;

            commandQueue = [device newCommandQueue];

            if (!commandQueue)
            {
                Log(Log::Level::ERR) << "Failed to create Metal command queue";
                return false;
            }

            std::shared_ptr<Shader> textureShader = std::make_shared<Shader>();
            textureShader->initFromBuffers(std::vector<uint8_t>(std::begin(TEXTURE_PIXEL_SHADER_METAL), std::end(TEXTURE_PIXEL_SHADER_METAL)),
                                           std::vector<uint8_t>(std::begin(TEXTURE_VERTEX_SHADER_METAL), std::end(TEXTURE_VERTEX_SHADER_METAL)),
                                           VertexPCT::ATTRIBUTES,
                                           {{"color", DataType::FLOAT_VECTOR4}},
                                           {{"modelViewProj", DataType::FLOAT_MATRIX4}},
                                           256, 256,
                                           "main_ps", "main_vs");

            sharedEngine->getCache()->setShader(SHADER_TEXTURE, textureShader);

            std::shared_ptr<Shader> colorShader = std::make_shared<Shader>();
            colorShader->initFromBuffers(std::vector<uint8_t>(std::begin(COLOR_PIXEL_SHADER_METAL), std::end(COLOR_PIXEL_SHADER_METAL)),
                                         std::vector<uint8_t>(std::begin(COLOR_VERTEX_SHADER_METAL), std::end(COLOR_VERTEX_SHADER_METAL)),
                                         VertexPC::ATTRIBUTES,
                                         {{"color", DataType::FLOAT_VECTOR4}},
                                         {{"modelViewProj", DataType::FLOAT_MATRIX4}},
                                         256, 256,
                                         "main_ps", "main_vs");

            sharedEngine->getCache()->setShader(SHADER_COLOR, colorShader);

            std::shared_ptr<BlendState> noBlendState = std::make_shared<BlendState>();

            noBlendState->init(false,
                               BlendState::BlendFactor::ONE, BlendState::BlendFactor::ZERO,
                               BlendState::BlendOperation::ADD,
                               BlendState::BlendFactor::ONE, BlendState::BlendFactor::ZERO,
                               BlendState::BlendOperation::ADD);

            sharedEngine->getCache()->setBlendState(BLEND_NO_BLEND, noBlendState);

            std::shared_ptr<BlendState> addBlendState = std::make_shared<BlendState>();

            addBlendState->init(true,
                                BlendState::BlendFactor::ONE, BlendState::BlendFactor::ONE,
                                BlendState::BlendOperation::ADD,
                                BlendState::BlendFactor::ONE, BlendState::BlendFactor::ONE,
                                BlendState::BlendOperation::ADD);

            sharedEngine->getCache()->setBlendState(BLEND_ADD, addBlendState);

            std::shared_ptr<BlendState> multiplyBlendState = std::make_shared<BlendState>();

            multiplyBlendState->init(true,
                                     BlendState::BlendFactor::DEST_COLOR, BlendState::BlendFactor::ZERO,
                                     BlendState::BlendOperation::ADD,
                                     BlendState::BlendFactor::ONE, BlendState::BlendFactor::ONE,
                                     BlendState::BlendOperation::ADD);

            sharedEngine->getCache()->setBlendState(BLEND_MULTIPLY, multiplyBlendState);

            std::shared_ptr<BlendState> alphaBlendState = std::make_shared<BlendState>();

            alphaBlendState->init(true,
                                  BlendState::BlendFactor::SRC_ALPHA, BlendState::BlendFactor::INV_SRC_ALPHA,
                                  BlendState::BlendOperation::ADD,
                                  BlendState::BlendFactor::ONE, BlendState::BlendFactor::ONE,
                                  BlendState::BlendOperation::ADD);

            sharedEngine->getCache()->setBlendState(BLEND_ALPHA, alphaBlendState);

            std::shared_ptr<Texture> whitePixelTexture = std::make_shared<Texture>();
            whitePixelTexture->initFromBuffer({255, 255, 255, 255}, Size2(1.0f, 1.0f), false, false);
            sharedEngine->getCache()->setTexture(TEXTURE_WHITE_PIXEL, whitePixelTexture);

            return true;
        }

        bool RendererMetal::upload()
        {
            colorBufferLoadAction = clearColorBuffer ? MTLLoadActionClear : MTLLoadActionDontCare;
            depthBufferLoadAction = clearDepthBuffer ? MTLLoadActionClear : MTLLoadActionDontCare;

            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(clearColor.normR(),
                                                                                    clearColor.normG(),
                                                                                    clearColor.normB(),
                                                                                    clearColor.normA());

            dirty = false;

            return true;
        }

        bool RendererMetal::draw(const std::vector<DrawCommand>& drawCommands)
        {
            NSUInteger frameBufferWidth = view.currentDrawable.texture.width;
            NSUInteger frameBufferHeight = view.currentDrawable.texture.height;

            if (sampleCount > 1)
            {
                if (!msaaTexture ||
                    frameBufferWidth != msaaTexture.width ||
                    frameBufferHeight != msaaTexture.height)
                {
                    if (msaaTexture) [msaaTexture release];

                    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat: MTLPixelFormatBGRA8Unorm
                                                                                                    width: frameBufferWidth
                                                                                                   height: frameBufferHeight
                                                                                                mipmapped: NO];
                    desc.textureType = MTLTextureType2DMultisample;
                    desc.storageMode = MTLStorageModePrivate;
                    desc.sampleCount = sampleCount;
                    desc.usage = MTLTextureUsageRenderTarget;

                    msaaTexture = [device newTextureWithDescriptor: desc];

                    if (!msaaTexture)
                    {
                        Log(Log::Level::ERR) << "Failed to create MSAA texture";
                        return false;
                    }

                    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
                    renderPassDescriptor.colorAttachments[0].texture = msaaTexture;
                }

                renderPassDescriptor.colorAttachments[0].resolveTexture = view.currentDrawable.texture;
            }
            else
            {
                renderPassDescriptor.colorAttachments[0].texture = view.currentDrawable.texture;
            }

            if (depth)
            {
                if (!depthTexture ||
                    frameBufferWidth != depthTexture.width ||
                    frameBufferHeight != depthTexture.height)
                {
                    if (depthTexture) [depthTexture release];

                    MTLTextureDescriptor* desc = [MTLTextureDescriptor
                                                  texture2DDescriptorWithPixelFormat:static_cast<MTLPixelFormat>(depthFormat)
                                                  width:frameBufferWidth height:frameBufferHeight mipmapped:NO];

                    desc.textureType = (sampleCount > 1) ? MTLTextureType2DMultisample : MTLTextureType2D;
                    desc.storageMode = MTLStorageModePrivate;
                    desc.sampleCount = sampleCount;
                    desc.usage = MTLTextureUsageRenderTarget;

                    depthTexture = [device newTextureWithDescriptor:desc];

                    if (!depthTexture)
                    {
                        Log(Log::Level::ERR) << "Failed to create depth texture";
                        return false;
                    }

                    renderPassDescriptor.depthAttachment.texture = depthTexture;
                }
            }
            else
            {
                renderPassDescriptor.depthAttachment.texture = Nil;
            }

            dispatch_semaphore_wait(inflightSemaphore, DISPATCH_TIME_FOREVER);

            currentCommandBuffer = [[commandQueue commandBuffer] retain];

            if (!currentCommandBuffer)
            {
                Log(Log::Level::ERR) << "Failed to create Metal command buffer";
                return false;
            }

            __block dispatch_semaphore_t blockSemaphore = inflightSemaphore;
            [currentCommandBuffer addCompletedHandler:^(id<MTLCommandBuffer>)
             {
                 dispatch_semaphore_signal(blockSemaphore);
             }];

            MTLScissorRect scissorRect;

            std::vector<float> shaderData;

            MTLViewport viewport;

            if (drawCommands.empty())
            {
                frameBufferClearedFrame = currentFrame;

                if (!createRenderCommandEncoder(renderPassDescriptor))
                {
                    return false;
                }

                viewport = {
                    0.0, 0.0,
                    static_cast<double>(frameBufferWidth),
                    static_cast<double>(frameBufferHeight),
                    0.0, 1.0
                };

                [currentRenderCommandEncoder setViewport: viewport];

                if (depthStencilStates[3])
                {
                    [currentRenderCommandEncoder setDepthStencilState:depthStencilStates[3]];
                }

                currentRenderPassDescriptor.colorAttachments[0].loadAction = static_cast<MTLLoadAction>(colorBufferLoadAction);
                currentRenderPassDescriptor.depthAttachment.loadAction = static_cast<MTLLoadAction>(depthBufferLoadAction);
            }
            else for (const DrawCommand& drawCommand : drawCommands)
            {
                MTLRenderPassDescriptorPtr newRenderPassDescriptor;
                PipelineStateDesc pipelineStateDesc;
                MTLLoadAction newColorBufferLoadAction = MTLLoadActionDontCare;
                MTLLoadAction newDepthBufferLoadAction = MTLLoadActionDontCare;

                viewport = {
                    static_cast<double>(drawCommand.viewport.position.v[0]),
                    static_cast<double>(drawCommand.viewport.position.v[1]),
                    static_cast<double>(drawCommand.viewport.size.v[0]),
                    static_cast<double>(drawCommand.viewport.size.v[1]),
                    0.0, 1.0
                };

                // render target
                if (drawCommand.renderTarget)
                {
                    TextureMetal* renderTargetMetal = static_cast<TextureMetal*>(drawCommand.renderTarget);

                    if (!renderTargetMetal->getRenderPassDescriptor())
                    {
                        continue;
                    }

                    newRenderPassDescriptor = renderTargetMetal->getRenderPassDescriptor();
                    pipelineStateDesc.sampleCount = renderTargetMetal->getSampleCount();
                    pipelineStateDesc.colorFormat = renderTargetMetal->getColorFormat();
                    pipelineStateDesc.depthFormat = renderTargetMetal->getDepthFormat();

                    TextureMetal* renderTargetTextureMetal = static_cast<TextureMetal*>(renderTargetMetal);
                    viewport.originY = renderTargetTextureMetal->getHeight() - (viewport.originY + viewport.height);

                    scissorRect.x = scissorRect.y = 0;
                    scissorRect.width = renderTargetTextureMetal->getTexture().width;
                    scissorRect.height = renderTargetTextureMetal->getTexture().height;

                    if (renderTargetMetal->getFrameBufferClearedFrame() != currentFrame)
                    {
                        renderTargetMetal->setFrameBufferClearedFrame(currentFrame);
                        newColorBufferLoadAction = static_cast<MTLLoadAction>(renderTargetMetal->getColorBufferLoadAction());
                        newDepthBufferLoadAction = static_cast<MTLLoadAction>(renderTargetMetal->getDepthBufferLoadAction());
                    }
                }
                else
                {
                    newRenderPassDescriptor = renderPassDescriptor;
                    pipelineStateDesc.sampleCount = sampleCount;
                    pipelineStateDesc.colorFormat = colorFormat;
                    pipelineStateDesc.depthFormat = depthFormat;

                    viewport.originY = static_cast<float>(frameBufferHeight) - (viewport.originY + viewport.height);

                    scissorRect.x = scissorRect.y = 0;
                    scissorRect.width = frameBufferWidth;
                    scissorRect.height = frameBufferHeight;

                    if (frameBufferClearedFrame != currentFrame)
                    {
                        frameBufferClearedFrame = currentFrame;
                        newColorBufferLoadAction = static_cast<MTLLoadAction>(colorBufferLoadAction);
                        newDepthBufferLoadAction = static_cast<MTLLoadAction>(depthBufferLoadAction);
                    }
                }

                if (currentRenderPassDescriptor != newRenderPassDescriptor ||
                    !currentRenderCommandEncoder)
                {
                    if (!createRenderCommandEncoder(newRenderPassDescriptor))
                    {
                        return false;
                    }

                    currentRenderPassDescriptor.colorAttachments[0].loadAction = newColorBufferLoadAction;
                    currentRenderPassDescriptor.depthAttachment.loadAction = newDepthBufferLoadAction;
                }

                [currentRenderCommandEncoder setViewport: viewport];

                [currentRenderCommandEncoder setTriangleFillMode:drawCommand.wireframe ? MTLTriangleFillModeLines : MTLTriangleFillModeFill];

                // scissor test
                if (drawCommand.scissorTestEnabled)
                {
                    scissorRect.x = static_cast<NSUInteger>(drawCommand.scissorTest.position.v[0]);
                    scissorRect.y = static_cast<NSUInteger>(drawCommand.scissorTest.position.v[1]);
                    scissorRect.width = static_cast<NSUInteger>(drawCommand.scissorTest.size.v[0]);
                    scissorRect.height = static_cast<NSUInteger>(drawCommand.scissorTest.size.v[1]);
                }

                [currentRenderCommandEncoder setScissorRect: scissorRect];

                uint32_t depthStencilStateIndex = 0;
                if (drawCommand.depthTest) depthStencilStateIndex |= 0x01;
                if (drawCommand.depthWrite) depthStencilStateIndex |= 0x02;

                if (depthStencilStates[depthStencilStateIndex])
                {
                    [currentRenderCommandEncoder setDepthStencilState:depthStencilStates[depthStencilStateIndex]];
                }

                // shader
                ShaderMetal* shaderMetal = static_cast<ShaderMetal*>(drawCommand.shader);

                if (!shaderMetal || !shaderMetal->getPixelShader() || !shaderMetal->getVertexShader())
                {
                    // don't render if invalid shader
                    continue;
                }

                pipelineStateDesc.shader = shaderMetal;

                // pixel shader constants
                const std::vector<ShaderMetal::Location>& pixelShaderConstantLocations = shaderMetal->getPixelShaderConstantLocations();

                if (drawCommand.pixelShaderConstants.size() > pixelShaderConstantLocations.size())
                {
                    Log(Log::Level::ERR) << "Invalid pixel shader constant size";
                    return false;
                }

                shaderData.clear();

                for (size_t i = 0; i < drawCommand.pixelShaderConstants.size(); ++i)
                {
                    const ShaderMetal::Location& pixelShaderConstantLocation = pixelShaderConstantLocations[i];
                    const std::vector<float>& pixelShaderConstant = drawCommand.pixelShaderConstants[i];

                    if (sizeof(float) * pixelShaderConstant.size() != pixelShaderConstantLocation.size)
                    {
                        Log(Log::Level::ERR) << "Invalid pixel shader constant size";
                        return false;
                    }

                    shaderData.insert(shaderData.end(), pixelShaderConstant.begin(), pixelShaderConstant.end());
                }

                shaderMetal->uploadBuffer(shaderMetal->getPixelShaderConstantBuffer(),
                                          shaderMetal->getPixelShaderConstantBufferOffset(),
                                          shaderData.data(),
                                          static_cast<uint32_t>(sizeof(float) * shaderData.size()));

                [currentRenderCommandEncoder setFragmentBuffer:shaderMetal->getPixelShaderConstantBuffer()
                                                        offset:shaderMetal->getPixelShaderConstantBufferOffset()
                                                       atIndex:1];

                // vertex shader constants
                const std::vector<ShaderMetal::Location>& vertexShaderConstantLocations = shaderMetal->getVertexShaderConstantLocations();

                if (drawCommand.vertexShaderConstants.size() > vertexShaderConstantLocations.size())
                {
                    Log(Log::Level::ERR) << "Invalid vertex shader constant size";
                    return false;
                }

                shaderData.clear();

                for (size_t i = 0; i < drawCommand.vertexShaderConstants.size(); ++i)
                {
                    const ShaderMetal::Location& vertexShaderConstantLocation = vertexShaderConstantLocations[i];
                    const std::vector<float>& vertexShaderConstant = drawCommand.vertexShaderConstants[i];

                    if (sizeof(float) * vertexShaderConstant.size() != vertexShaderConstantLocation.size)
                    {
                        Log(Log::Level::ERR) << "Invalid vertex shader constant size";
                        return false;
                    }

                    shaderData.insert(shaderData.end(), vertexShaderConstant.begin(), vertexShaderConstant.end());
                }

                shaderMetal->uploadBuffer(shaderMetal->getVertexShaderConstantBuffer(),
                                          shaderMetal->getVertexShaderConstantBufferOffset(),
                                          shaderData.data(),
                                          static_cast<uint32_t>(sizeof(float) * shaderData.size()));

                [currentRenderCommandEncoder setVertexBuffer:shaderMetal->getVertexShaderConstantBuffer()
                                                      offset:shaderMetal->getVertexShaderConstantBufferOffset()
                                                     atIndex:1];

                shaderMetal->nextBuffers();

                // blend state
                BlendStateMetal* blendStateMetal = static_cast<BlendStateMetal*>(drawCommand.blendState);

                if (!blendStateMetal)
                {
                    // don't render if invalid blend state
                    continue;
                }

                pipelineStateDesc.blendState = blendStateMetal;

                MTLRenderPipelineStatePtr pipelineState = getPipelineState(pipelineStateDesc);

                if (!pipelineState)
                {
                    Log(Log::Level::ERR) << "Failed to get Metal pipeline state";
                    return false;
                }

                [currentRenderCommandEncoder setRenderPipelineState:pipelineState];

                // textures
                bool texturesValid = true;

                for (uint32_t layer = 0; layer < Texture::LAYERS; ++layer)
                {
                    TextureMetal* textureMetal = nullptr;

                    if (drawCommand.textures.size() > layer)
                    {
                        textureMetal = static_cast<TextureMetal*>(drawCommand.textures[layer]);
                    }

                    if (textureMetal)
                    {
                        if (!textureMetal->getTexture())
                        {
                            texturesValid = false;
                            break;
                        }

                        [currentRenderCommandEncoder setFragmentTexture:textureMetal->getTexture() atIndex:layer];
                        [currentRenderCommandEncoder setFragmentSamplerState:textureMetal->getSamplerState() atIndex:layer];
                    }
                    else
                    {
                        [currentRenderCommandEncoder setFragmentTexture:Nil atIndex:layer];
                    }
                }

                if (!texturesValid)
                {
                    continue;
                }

                // mesh buffer
                MeshBufferMetal* meshBufferMetal = static_cast<MeshBufferMetal*>(drawCommand.meshBuffer);
                BufferMetal* indexBufferMetal = meshBufferMetal->getIndexBufferMetal();
                BufferMetal* vertexBufferMetal = meshBufferMetal->getVertexBufferMetal();

                if (!meshBufferMetal ||
                    !indexBufferMetal ||
                    !vertexBufferMetal ||
                    !indexBufferMetal->getBuffer() ||
                    !vertexBufferMetal->getBuffer())
                {
                    // don't render if invalid mesh buffer
                    continue;
                }

                [currentRenderCommandEncoder setVertexBuffer:vertexBufferMetal->getBuffer() offset:0 atIndex:0];

                // draw
                MTLPrimitiveType primitiveType;

                switch (drawCommand.drawMode)
                {
                    case DrawMode::POINT_LIST: primitiveType = MTLPrimitiveTypePoint; break;
                    case DrawMode::LINE_LIST: primitiveType = MTLPrimitiveTypeLine; break;
                    case DrawMode::LINE_STRIP: primitiveType = MTLPrimitiveTypeLineStrip; break;
                    case DrawMode::TRIANGLE_LIST: primitiveType = MTLPrimitiveTypeTriangle; break;
                    case DrawMode::TRIANGLE_STRIP: primitiveType = MTLPrimitiveTypeTriangleStrip; break;
                    default: Log(Log::Level::ERR) << "Invalid draw mode"; return false;
                }

                [currentRenderCommandEncoder drawIndexedPrimitives:primitiveType
                                                        indexCount:drawCommand.indexCount
                                                         indexType:meshBufferMetal->getIndexType()
                                                       indexBuffer:indexBufferMetal->getBuffer()
                                                 indexBufferOffset:drawCommand.startIndex * meshBufferMetal->getBytesPerIndex()];
            }

            if (currentRenderCommandEncoder)
            {
                [currentRenderCommandEncoder endEncoding];
                [currentRenderCommandEncoder release];
                currentRenderCommandEncoder = Nil;
            }

            if (currentCommandBuffer)
            {
                [currentCommandBuffer presentDrawable:static_cast<id<CAMetalDrawable> _Nonnull>(view.currentDrawable)];

                [currentCommandBuffer commit];
                [currentCommandBuffer release];
                currentCommandBuffer = Nil;
            }

            return true;
        }

        std::vector<Size2> RendererMetal::getSupportedResolutions() const
        {
            return std::vector<Size2>();
        }

        BlendStateResource* RendererMetal::createBlendState()
        {
            std::lock_guard<std::mutex> lock(resourceMutex);

            BlendStateResource* blendState = new BlendStateMetal();
            resources.push_back(std::unique_ptr<Resource>(blendState));
            return blendState;
        }

        TextureResource* RendererMetal::createTexture()
        {
            std::lock_guard<std::mutex> lock(resourceMutex);

            TextureResource* texture = new TextureMetal();
            resources.push_back(std::unique_ptr<Resource>(texture));
            return texture;
        }

        ShaderResource* RendererMetal::createShader()
        {
            std::lock_guard<std::mutex> lock(resourceMutex);

            ShaderResource* shader = new ShaderMetal();
            resources.push_back(std::unique_ptr<Resource>(shader));
            return shader;
        }

        MeshBufferResource* RendererMetal::createMeshBuffer()
        {
            std::lock_guard<std::mutex> lock(resourceMutex);

            MeshBufferResource* meshBuffer = new MeshBufferMetal();
            resources.push_back(std::unique_ptr<Resource>(meshBuffer));
            return meshBuffer;
        }

        BufferResource* RendererMetal::createBuffer()
        {
            std::lock_guard<std::mutex> lock(resourceMutex);

            BufferResource* buffer = new BufferMetal();
            resources.push_back(std::unique_ptr<Resource>(buffer));
            return buffer;
        }

        MTLRenderPipelineStatePtr RendererMetal::getPipelineState(const PipelineStateDesc& desc)
        {
            auto pipelineStateIterator = pipelineStates.find(desc);

            if (pipelineStateIterator != pipelineStates.end())
            {
                return pipelineStateIterator->second;
            }
            else
            {
                MTLRenderPipelineDescriptor* pipelineStateDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
                pipelineStateDescriptor.sampleCount = desc.sampleCount;
                pipelineStateDescriptor.vertexFunction = desc.shader->getVertexShader();
                pipelineStateDescriptor.fragmentFunction = desc.shader->getPixelShader();
                pipelineStateDescriptor.vertexDescriptor = desc.shader->getVertexDescriptor();

                pipelineStateDescriptor.colorAttachments[0].pixelFormat = static_cast<MTLPixelFormat>(desc.colorFormat);
                pipelineStateDescriptor.depthAttachmentPixelFormat = static_cast<MTLPixelFormat>(desc.depthFormat);
                pipelineStateDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;

                // blending
                pipelineStateDescriptor.colorAttachments[0].blendingEnabled = desc.blendState->isMetalBlendingEnabled() ? YES : NO;

                pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = desc.blendState->getSourceRGBBlendFactor();
                pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = desc.blendState->getDestinationRGBBlendFactor();
                pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = desc.blendState->getRGBBlendOperation();

                pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = desc.blendState->getSourceAlphaBlendFactor();
                pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = desc.blendState->getDestinationAlphaBlendFactor();
                pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = desc.blendState->getAlphaBlendOperation();

                pipelineStateDescriptor.colorAttachments[0].writeMask = MTLColorWriteMaskAll;

                NSError* error = Nil;
                id<MTLRenderPipelineState> pipelineState = [device newRenderPipelineStateWithDescriptor:pipelineStateDescriptor error:&error];
                [pipelineStateDescriptor release];
                if (error || !pipelineState)
                {
                    if (pipelineState) [pipelineState release];

                    Log(Log::Level::ERR) << "Failed to created Metal pipeline state";
                    return Nil;
                }
                
                pipelineStates[desc] = pipelineState;
                
                return pipelineState;
            }
        }

        bool RendererMetal::generateScreenshot(const std::string& filename)
        {
            MTLTextureResourcePtr texture = view.currentDrawable.texture;

            if (!texture)
            {
                return false;
            }

            NSUInteger width = static_cast<NSUInteger>(texture.width);
            NSUInteger height = static_cast<NSUInteger>(texture.height);

            std::shared_ptr<uint8_t> data(new uint8_t[width * height * 4]);
            [texture getBytes:data.get() bytesPerRow:width * 4 fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];

            uint8_t temp;
            for (uint32_t y = 0; y < height; ++y)
            {
                for (uint32_t x = 0; x < width; ++x)
                {
                    temp = data.get()[((y * width + x) * 4)];
                    data.get()[((y * width + x) * 4)] = data.get()[((y * width + x) * 4) + 2];
                    data.get()[((y * width + x) * 4) + 2] = temp;
                    data.get()[((y * width + x) * 4) + 3] = 255;
                }
            }

            if (!stbi_write_png(filename.c_str(), static_cast<int>(width), static_cast<int>(height), 4, data.get(), static_cast<int>(width * 4)))
            {
                Log(Log::Level::ERR) << "Failed to save image to file";
                return false;
            }

            return true;
        }

        bool RendererMetal::createRenderCommandEncoder(MTLRenderPassDescriptorPtr newRenderPassDescriptor)
        {
            if (currentRenderCommandEncoder)
            {
                [currentRenderCommandEncoder endEncoding];
                [currentRenderCommandEncoder release];
            }

            currentRenderPassDescriptor = newRenderPassDescriptor;
            currentRenderCommandEncoder = [[currentCommandBuffer renderCommandEncoderWithDescriptor:currentRenderPassDescriptor] retain];

            if (!currentRenderCommandEncoder)
            {
                Log(Log::Level::ERR) << "Failed to create Metal render command encoder";
                return false;
            }

            return true;
        }

        MTLSamplerStatePtr RendererMetal::getSamplerState(const SamplerStateDesc& desc)
        {
            auto samplerStatesIterator = samplerStates.find(desc);

            if (samplerStatesIterator != samplerStates.end())
            {
                return samplerStatesIterator->second;
            }
            else
            {
                MTLSamplerDescriptor* samplerDescriptor = [MTLSamplerDescriptor new];
                switch (desc.filter)
                {
                    case Texture::Filter::DEFAULT:
                    case Texture::Filter::POINT:
                        samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
                        samplerDescriptor.magFilter = MTLSamplerMinMagFilterNearest;
                        samplerDescriptor.mipFilter = MTLSamplerMipFilterNearest;
                        break;
                    case Texture::Filter::LINEAR:
                        samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
                        samplerDescriptor.magFilter = MTLSamplerMinMagFilterNearest;
                        samplerDescriptor.mipFilter = MTLSamplerMipFilterNearest;
                        break;
                    case Texture::Filter::BILINEAR:
                        samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
                        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
                        samplerDescriptor.mipFilter = MTLSamplerMipFilterNearest;
                        break;
                    case Texture::Filter::TRILINEAR:
                        samplerDescriptor.minFilter = MTLSamplerMinMagFilterLinear;
                        samplerDescriptor.magFilter = MTLSamplerMinMagFilterLinear;
                        samplerDescriptor.mipFilter = MTLSamplerMipFilterLinear;
                        break;
                }

                switch (desc.addressX)
                {
                    case Texture::Address::CLAMP:
                        samplerDescriptor.sAddressMode = MTLSamplerAddressModeClampToEdge;
                        break;
                    case Texture::Address::REPEAT:
                        samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
                        break;
                }

                switch (desc.addressY)
                {
                    case Texture::Address::CLAMP:
                        samplerDescriptor.tAddressMode = MTLSamplerAddressModeClampToEdge;
                        break;
                    case Texture::Address::REPEAT:
                        samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
                        break;
                }

                samplerDescriptor.maxAnisotropy = desc.maxAnisotropy;

                MTLSamplerStatePtr samplerState = [device newSamplerStateWithDescriptor:samplerDescriptor];
                [samplerDescriptor release];

                if (!samplerState)
                {
                    Log(Log::Level::ERR) << "Failed to create Metal sampler state";
                    return Nil;
                }

                return samplerState;
            }
        }
    } // namespace graphics
} // namespace ouzel
