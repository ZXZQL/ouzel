// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#pragma once

#include "input/MouseDevice.hpp"

namespace ouzel
{
    namespace input
    {
        class MouseDeviceWin: public MouseDevice
        {
        public:
            MouseDeviceWin(InputSystem& initInputSystem,
                           uint32_t initId):
                MouseDevice(initInputSystem, initId)
            {
            }

            void setPosition(const Vector2& position);
            void setCursorVisible(bool visible);
            void setCursorLocked(bool locked);
        };
    } // namespace input
} // namespace ouzel