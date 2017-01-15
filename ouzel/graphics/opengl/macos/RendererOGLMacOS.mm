// Copyright (C) 2017 Elviss Strazdins
// This file is part of the Ouzel engine.

#include "RendererOGLMacOS.h"
#include "utils/Log.h"

namespace ouzel
{
    namespace graphics
    {
        RendererOGLMacOS::~RendererOGLMacOS()
        {
            if (openGLContext)
            {
                [openGLContext release];
            }

            if (pixelFormat)
            {
                [pixelFormat release];
            }
        }

        void RendererOGLMacOS::free()
        {
            RendererOGL::free();

            if (openGLContext)
            {
                [openGLContext release];
                openGLContext = Nil;
            }

            if (pixelFormat)
            {
                [pixelFormat release];
                pixelFormat = Nil;
            }
        }

        bool RendererOGLMacOS::init(Window* window,
                                    const Size2& newSize,
                                    uint32_t newSampleCount,
                                    Texture::Filter newTextureFilter,
                                    PixelFormat newBackBufferFormat,
                                    bool newVerticalSync,
                                    bool newDepth)
        {
            free();

            // Create pixel format
            NSOpenGLPixelFormatAttribute openGL3Attributes[] =
            {
                NSOpenGLPFAAccelerated,
                NSOpenGLPFANoRecovery,
                NSOpenGLPFADoubleBuffer,
                NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion3_2Core,
                NSOpenGLPFAColorSize, 24,
                NSOpenGLPFAAlphaSize, 8,
                0
            };

            pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:openGL3Attributes];

            if (pixelFormat)
            {
                apiMajorVersion = 3;
                apiMinorVersion = 2;
                Log(Log::Level::INFO) << "Using OpenGL 3.2";
            }
            else
            {
                Log(Log::Level::INFO) << "Failed to crete OpenGL 3.2 pixel format";

                NSOpenGLPixelFormatAttribute openGL2Attributes[] =
                {
                    NSOpenGLPFAAccelerated,
                    NSOpenGLPFANoRecovery,
                    NSOpenGLPFADoubleBuffer,
                    NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersionLegacy,
                    NSOpenGLPFAColorSize, 24,
                    NSOpenGLPFAAlphaSize, 8,
                    0
                };

                pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:openGL2Attributes];

                if (pixelFormat)
                {
                    apiMajorVersion = 2;
                    apiMinorVersion = 0;
                    Log(Log::Level::INFO) << "Using OpenGL 2";
                }
            }

            if (!pixelFormat)
            {
                Log(Log::Level::ERR) << "Failed to crete OpenGL 2 pixel format";
                return Nil;
            }

            // Create OpenGL context
            openGLContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:NULL];
            [openGLContext makeCurrentContext];

            return RendererOGL::init(window, newSize, newSampleCount, newTextureFilter, newBackBufferFormat, newVerticalSync, newDepth);
        }

        bool RendererOGLMacOS::present()
        {
            [openGLContext makeCurrentContext];

            if (!RendererOGL::present())
            {
                return false;
            }

            [openGLContext flushBuffer];

            return true;
        }

        bool RendererOGLMacOS::update()
        {
            [openGLContext update];

            return RendererOGL::update();
        }
    } // namespace graphics
} // namespace ouzel
