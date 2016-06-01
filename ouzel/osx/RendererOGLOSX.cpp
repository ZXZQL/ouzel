// Copyright (C) 2016 Elviss Strazdins
// This file is part of the Ouzel engine.

#include "RendererOGLOSX.h"

namespace ouzel
{
    namespace graphics
    {
        bool RendererOGLOSX::init(const WindowPtr& window,
                                  uint32_t newSampleCount,
                                  TextureFiltering newTextureFiltering,
                                  float newTargetFPS,
                                  bool newVerticalSync)
        {
            return RendererOGL::init(window, newSampleCount, newTextureFiltering, newTargetFPS, newVerticalSync);
        }
    } // namespace graphics
} // namespace ouzel
