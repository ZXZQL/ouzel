// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#include <stdexcept>
#include <emscripten.h>
#include <emscripten/html5.h>
#include "NativeWindowEm.hpp"

static EM_BOOL emResizeCallback(int eventType, const EmscriptenUiEvent* uiEvent, void* userData)
{
    if (eventType == EMSCRIPTEN_EVENT_RESIZE)
    {
        ouzel::NativeWindowEm* nativeWindowEm = reinterpret_cast<ouzel::NativeWindowEm*>(userData);
        nativeWindowEm->handleResize();
        return true;
    }

    return false;
}

static EM_BOOL emFullscreenCallback(int eventType, const void*, void* userData)
{
    if (eventType == EMSCRIPTEN_EVENT_CANVASRESIZED)
    {
        ouzel::NativeWindowEm* nativeWindowEm = reinterpret_cast<ouzel::NativeWindowEm*>(userData);
        nativeWindowEm->handleResize();
        return true;
    }

    return false;
}

namespace ouzel
{
    NativeWindowEm::NativeWindowEm(const std::function<void(const Event&)>& initCallback,
                                   const Size2& newSize,
                                   bool newFullscreen,
                                   const std::string& newTitle,
                                   bool newHighDpi):
        NativeWindow(initCallback,
                     newSize,
                     true,
                     newFullscreen,
                     true,
                     newTitle,
                     newHighDpi)
    {
        emscripten_set_resize_callback(nullptr, this, true, emResizeCallback);

        if (size.width <= 0.0F || size.height <= 0.0F)
        {
            int width, height, isFullscreen;
            emscripten_get_canvas_size(&width, &height, &isFullscreen);

            if (size.width <= 0.0F) size.width = static_cast<float>(width);
            if (size.height <= 0.0F) size.height = static_cast<float>(height);
            fullscreen = static_cast<bool>(isFullscreen);
        }
        else
            emscripten_set_canvas_size(static_cast<int>(size.width),
                                       static_cast<int>(size.height));

        if (fullscreen)
        {
            EmscriptenFullscreenStrategy s;
            s.scaleMode = EMSCRIPTEN_FULLSCREEN_SCALE_STRETCH;
            s.canvasResolutionScaleMode = highDpi ? EMSCRIPTEN_FULLSCREEN_CANVAS_SCALE_HIDEF : EMSCRIPTEN_FULLSCREEN_CANVAS_SCALE_STDDEF;
            s.filteringMode = EMSCRIPTEN_FULLSCREEN_FILTERING_DEFAULT;
            s.canvasResizedCallback = emFullscreenCallback;
            s.canvasResizedCallbackUserData = this;

            emscripten_request_fullscreen_strategy(nullptr, EM_TRUE, &s);
        }

        resolution = size;
    }

    void NativeWindowEm::executeCommand(const Command& command)
    {
        switch (command.type)
        {
            case Command::Type::CHANGE_SIZE:
                setSize(command.size);
                break;
            case Command::Type::CHANGE_FULLSCREEN:
                setFullscreen(command.fullscreen);
                break;
            case Command::Type::CLOSE:
                break;
            case Command::Type::SET_TITLE:
                break;
            default:
                throw std::runtime_error("Invalid command");
        }
    }

    void NativeWindowEm::setSize(const Size2& newSize)
    {
        size = newSize;

        emscripten_set_canvas_size(static_cast<int>(newSize.width),
                                   static_cast<int>(newSize.height));
    }

    void NativeWindowEm::setFullscreen(bool newFullscreen)
    {
        fullscreen = newFullscreen;

        if (newFullscreen)
        {
            EmscriptenFullscreenStrategy s;
            s.scaleMode = EMSCRIPTEN_FULLSCREEN_SCALE_STRETCH;
            s.canvasResolutionScaleMode = highDpi ? EMSCRIPTEN_FULLSCREEN_CANVAS_SCALE_HIDEF : EMSCRIPTEN_FULLSCREEN_CANVAS_SCALE_STDDEF;
            s.filteringMode = EMSCRIPTEN_FULLSCREEN_FILTERING_DEFAULT;
            s.canvasResizedCallback = emFullscreenCallback;
            s.canvasResizedCallbackUserData = this;

            emscripten_request_fullscreen_strategy(nullptr, EM_TRUE, &s);
        }
        else
            emscripten_exit_fullscreen();
    }

    void NativeWindowEm::handleResize()
    {
        int width, height, isFullscreen;
        emscripten_get_canvas_size(&width, &height, &isFullscreen);

        Size2 newSize(static_cast<float>(width), static_cast<float>(height));

        size = newSize;
        resolution = size;

        bool oldFullscreen = fullscreen;
        fullscreen = static_cast<bool>(isFullscreen);

        Event sizeChangeEvent(Event::Type::SIZE_CHANGE);
        sizeChangeEvent.size = size;
        sendEvent(sizeChangeEvent);

        Event resolutionChangeEvent(Event::Type::RESOLUTION_CHANGE);
        resolutionChangeEvent.resolution = resolution;
        sendEvent(resolutionChangeEvent);

        if (fullscreen != oldFullscreen)
        {
            Event fullscreenChangeEvent(Event::Type::FULLSCREEN_CHANGE);
            fullscreenChangeEvent.fullscreen = fullscreen;
            sendEvent(fullscreenChangeEvent);
        }
    }
}
