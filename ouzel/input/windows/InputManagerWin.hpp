// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#pragma once

#define DIRECTINPUT_VERSION 0x0800
#include <dinput.h>
#include <Xinput.h>
#include "input/InputManager.hpp"

namespace ouzel
{
    namespace input
    {
        class GamepadDeviceDI;
        class GamepadDeviceXI;

        class InputManagerWin : public InputManager
        {
            friend Engine;
        public:
            virtual ~InputManagerWin();

            void update();

            virtual void setCursorVisible(bool visible) override;
            virtual bool isCursorVisible() const override;

            virtual void setCursorLocked(bool locked) override;
            virtual bool isCursorLocked() const override;

            IDirectInput8W* getDirectInput() const { return directInput; }
            void handleDeviceConnect(const DIDEVICEINSTANCEW* didInstance);

            void updateCursor();

        private:
            InputManagerWin();

            virtual void activateNativeCursor(NativeCursor* resource) override;
            virtual NativeCursor* createNativeCursor() override;

            IDirectInput8W* directInput = nullptr;
            std::vector<GamepadDeviceDI*> gamepadsDI;
            GamepadDeviceXI* gamepadsXI[XUSER_MAX_COUNT];

            bool cursorVisible = true;
            bool cursorLocked = false;
            HCURSOR defaultCursor = nullptr;
            HCURSOR currentCursor = nullptr;
        };
    } // namespace input
} // namespace ouzel
