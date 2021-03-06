// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#include <vector>
#include "GamepadDeviceIOKit.hpp"
#include "InputSystemMacOS.hpp"
#include "input/GamepadConfig.hpp"
#include "core/Setup.h"

static const float THUMB_DEADZONE = 0.2F;

static void deviceInput(void* ctx, IOReturn, void*, IOHIDValueRef value)
{
    ouzel::input::GamepadDeviceIOKit* gamepadDevice = reinterpret_cast<ouzel::input::GamepadDeviceIOKit*>(ctx);
    gamepadDevice->handleInput(value);
}

namespace ouzel
{
    namespace input
    {
        GamepadDeviceIOKit::GamepadDeviceIOKit(InputSystem& initInputSystem,
                                               uint32_t initId,
                                               IOHIDDeviceRef initDevice):
            GamepadDeviceMacOS(initInputSystem, initId),
            device(initDevice)
        {
            IOReturn ret;
            if ((ret = IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone)) != kIOReturnSuccess)
                throw std::system_error(ret, ioKitErrorCategory, "Failed to open HID device");

            CFStringRef productName = static_cast<CFStringRef>(IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductKey)));
            if (productName)
            {
                if (const char* deviceName = CFStringGetCStringPtr(productName, kCFStringEncodingUTF8))
                    name = deviceName;
                else
                {
                    CFIndex stringLength = CFStringGetLength(productName);
                    std::vector<char> temp(static_cast<size_t>(CFStringGetMaximumSizeForEncoding(stringLength, kCFStringEncodingUTF8)) + 1);
                    CFStringGetCString(productName, temp.data(), static_cast<CFIndex>(temp.size()), kCFStringEncodingUTF8);
                    name = temp.data();
                }
            }

            int32_t vendorId;
            CFNumberRef vendor = static_cast<CFNumberRef>(IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey)));
            if (!vendor)
                throw std::runtime_error("Failed to get vendor ID");

            CFNumberGetValue(vendor, kCFNumberSInt32Type, &vendorId);

            int32_t productId;
            CFNumberRef product = static_cast<CFNumberRef>(IOHIDDeviceGetProperty(device, CFSTR(kIOHIDProductIDKey)));
            if (!product)
                throw std::runtime_error("Failed to get product ID");

            CFNumberGetValue(product, kCFNumberSInt32Type, &productId);

            const GamepadConfig& gamepadConfig = getGamepadConfig(vendorId, productId);

            static const std::unordered_map<uint32_t, size_t> axisUsageMap = {
                {kHIDUsage_GD_X, 0},
                {kHIDUsage_GD_Y, 1},
                {kHIDUsage_GD_Z, 2},
                {kHIDUsage_GD_Rx, 3},
                {kHIDUsage_GD_Ry, 4},
                {kHIDUsage_GD_Rz, 5}
            };

            CFArrayRef elementArray = IOHIDDeviceCopyMatchingElements(device, nullptr, kIOHIDOptionsTypeNone);
            CFIndex count = CFArrayGetCount(elementArray);

            for (CFIndex i = 0; i < count; ++i)
            {
                IOHIDElementRef element = static_cast<IOHIDElementRef>(const_cast<void*>(CFArrayGetValueAtIndex(elementArray, i)));
                IOHIDElementType type = IOHIDElementGetType(element);
                uint32_t usagePage = IOHIDElementGetUsagePage(element);
                uint32_t usage = IOHIDElementGetUsage(element);

                if (usage == kHIDUsage_GD_Hatswitch)
                    hatElement = element;

                if (usage >= kHIDUsage_Button_1 && usage < kHIDUsage_Button_1 + 24)
                {
                    Button button;
                    button.button = gamepadConfig.buttonMap[usage - kHIDUsage_Button_1];
                    buttons.insert(std::make_pair(element, button));
                }

                if ((type == kIOHIDElementTypeInput_Misc || type == kIOHIDElementTypeInput_Axis) &&
                    usagePage == kHIDPage_GenericDesktop)
                {
                    auto usageIterator = axisUsageMap.find(usage);

                    if (usageIterator != axisUsageMap.end())
                    {
                        size_t index = usageIterator->second;

                        Axis axis;
                        axis.axis = gamepadConfig.axisMap[index];
                        axis.min = IOHIDElementGetLogicalMin(element);
                        axis.max = IOHIDElementGetLogicalMax(element);
                        axis.range = axis.max - axis.min;

                        switch (gamepadConfig.axisMap[index])
                        {
                            case Gamepad::Axis::NONE:
                                break;
                            case Gamepad::Axis::LEFT_THUMB_X:
                                axis.negativeButton = Gamepad::Button::LEFT_THUMB_LEFT;
                                axis.positiveButton = Gamepad::Button::LEFT_THUMB_RIGHT;
                                break;
                            case Gamepad::Axis::LEFT_THUMB_Y:
                                axis.negativeButton = Gamepad::Button::LEFT_THUMB_UP;
                                axis.positiveButton = Gamepad::Button::LEFT_THUMB_DOWN;
                                break;
                            case Gamepad::Axis::RIGHT_THUMB_X:
                                axis.negativeButton = Gamepad::Button::RIGHT_THUMB_LEFT;
                                axis.positiveButton = Gamepad::Button::RIGHT_THUMB_RIGHT;
                                break;
                            case Gamepad::Axis::RIGHT_THUMB_Y:
                                axis.negativeButton = Gamepad::Button::RIGHT_THUMB_UP;
                                axis.positiveButton = Gamepad::Button::RIGHT_THUMB_DOWN;
                                break;
                            case Gamepad::Axis::LEFT_TRIGGER:
                                axis.negativeButton = Gamepad::Button::LEFT_TRIGGER;
                                axis.positiveButton = Gamepad::Button::LEFT_TRIGGER;
                                hasLeftTrigger = true;
                                break;
                            case Gamepad::Axis::RIGHT_TRIGGER:
                                axis.negativeButton = Gamepad::Button::RIGHT_TRIGGER;
                                axis.positiveButton = Gamepad::Button::RIGHT_TRIGGER;
                                hasRightTrigger = true;
                                break;
                        }

                        axes.insert(std::make_pair(element, axis));
                    }
                }
            }

            CFRelease(elementArray);

            IOHIDDeviceRegisterInputValueCallback(device, deviceInput, this);
        }

        void GamepadDeviceIOKit::handleInput(IOHIDValueRef value)
        {
            IOHIDElementRef element = IOHIDValueGetElement(value);
            CFIndex newValue = IOHIDValueGetIntegerValue(value);

            if (element == hatElement)
            {
                uint32_t oldHatValue = static_cast<uint32_t>(hatValue);
                uint32_t oldBitmask = (oldHatValue >= 8) ? 0 : (1 << (oldHatValue / 2)) | // first bit
                    (1 << (oldHatValue / 2 + oldHatValue % 2)) % 4; // second bit

                uint32_t newBitmask = (newValue >= 8) ? 0 : (1 << (newValue / 2)) | // first bit
                (1 << (newValue / 2 + newValue % 2)) % 4; // second bit

                if ((oldBitmask & 0x01) != (newBitmask & 0x01))
                    handleButtonValueChange(Gamepad::Button::DPAD_UP,
                                            (newBitmask & 0x01) > 0,
                                            (newBitmask & 0x01) > 0 ? 1.0F : 0.0F);
                if ((oldBitmask & 0x02) != (newBitmask & 0x02))
                    handleButtonValueChange(Gamepad::Button::DPAD_RIGHT,
                                            (newBitmask & 0x02) > 0,
                                            (newBitmask & 0x02) > 0 ? 1.0F : 0.0F);
                if ((oldBitmask & 0x04) != (newBitmask & 0x04))
                    handleButtonValueChange(Gamepad::Button::DPAD_DOWN,
                                            (newBitmask & 0x04) > 0,
                                            (newBitmask & 0x04) > 0 ? 1.0F : 0.0F);
                if ((oldBitmask & 0x08) != (newBitmask & 0x08))
                    handleButtonValueChange(Gamepad::Button::DPAD_LEFT,
                                            (newBitmask & 0x08) > 0,
                                            (newBitmask & 0x08) > 0 ? 1.0F : 0.0F);

                hatValue = newValue;
            }

            auto buttonIterator = buttons.find(element);

            if (buttonIterator != buttons.end())
            {
                Button& button = buttonIterator->second;

                if ((button.button != Gamepad::Button::LEFT_TRIGGER || !hasLeftTrigger) &&
                    (button.button != Gamepad::Button::RIGHT_TRIGGER || !hasRightTrigger))
                {
                    handleButtonValueChange(button.button, newValue > 0, (newValue > 0) ? 1.0F : 0.0F);
                }

                button.value = newValue;
            }

            auto axisIterator = axes.find(element);

            if (axisIterator != axes.end())
            {
                Axis& axis = axisIterator->second;

                handleAxisChange(axis.value,
                                 newValue,
                                 axis.min, axis.range,
                                 axis.negativeButton, axis.positiveButton);

                axis.value = newValue;
            }
        }

        void GamepadDeviceIOKit::handleAxisChange(CFIndex oldValue, CFIndex newValue,
                                                  CFIndex min, CFIndex range,
                                                  Gamepad::Button negativeButton,
                                                  Gamepad::Button positiveButton)
        {
            if (negativeButton == positiveButton)
            {
                float floatValue = static_cast<float>(newValue - min) / range;

                handleButtonValueChange(negativeButton,
                                        floatValue > 0.0F,
                                        floatValue);
            }
            else
            {
                float floatValue = 2.0F * (newValue - min) / range - 1.0F;

                if (floatValue > 0.0F)
                {
                    handleButtonValueChange(positiveButton,
                                            floatValue > THUMB_DEADZONE,
                                            floatValue);
                }
                else if (floatValue < 0.0F)
                {
                    handleButtonValueChange(negativeButton,
                                            -floatValue > THUMB_DEADZONE,
                                            -floatValue);
                }
                else // thumbstick is 0
                {
                    if (oldValue > newValue)
                        handleButtonValueChange(positiveButton, false, 0.0F);
                    else
                        handleButtonValueChange(negativeButton, false, 0.0F);
                }
            }
        }
    } // namespace input
} // namespace ouzel
