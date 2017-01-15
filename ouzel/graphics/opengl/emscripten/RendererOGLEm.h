// Copyright (C) 2017 Elviss Strazdins
// This file is part of the Ouzel engine.

#pragma once

#include <emscripten.h>
#include <html5.h>
#include "graphics/opengl/RendererOGL.h"

namespace ouzel
{
    class Engine;

    namespace graphics
    {
        class RendererOGLEm: public RendererOGL
        {
            friend Engine;
        public:
            virtual ~RendererOGLEm();
            virtual void free() override;

            virtual bool present() override;

        private:
            virtual bool init(Window* newWindow,
                              const Size2& newSize,
                              uint32_t newSampleCount,
                              Texture::Filter newTextureFilter,
                              PixelFormat newBackBufferFormat,
                              bool newVerticalSync,
                              bool newDepth) override;

            EMSCRIPTEN_WEBGL_CONTEXT_HANDLE webGLContext = 0;
        };
    } // namespace graphics
} // namespace ouzel
