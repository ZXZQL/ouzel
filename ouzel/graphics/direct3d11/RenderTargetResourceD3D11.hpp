// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#ifndef OUZEL_GRAPHICS_RENDERTARGETRESOURCED3D11_HPP
#define OUZEL_GRAPHICS_RENDERTARGETRESOURCED3D11_HPP

#include "core/Setup.h"

#if OUZEL_COMPILE_DIRECT3D11

#include "graphics/direct3d11/RenderResourceD3D11.hpp"

namespace ouzel
{
    namespace graphics
    {
        class RenderDeviceD3D11;

        class RenderTargetResourceD3D11 final: public RenderResourceD3D11
        {
        public:
            explicit RenderTargetResourceD3D11(RenderDeviceD3D11& renderDeviceD3D11);
        };
    } // namespace graphics
} // namespace ouzel

#endif

#endif // OUZEL_GRAPHICS_RENDERTARGETRESOURCED3D11_HPP
