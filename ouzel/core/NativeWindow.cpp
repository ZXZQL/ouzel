// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#include "NativeWindow.hpp"

namespace ouzel
{
    NativeWindow::NativeWindow(const std::function<void(const Event&)>& initCallback,
                               const Size2& newSize,
                               bool newResizable,
                               bool newFullscreen,
                               bool newExclusiveFullscreen,
                               const std::string& newTitle,
                               bool newHighDpi):
        size(newSize),
        resizable(newResizable),
        fullscreen(newFullscreen),
        exclusiveFullscreen(newExclusiveFullscreen),
        highDpi(newHighDpi),
        title(newTitle),
        callback(initCallback)
    {

    }

    void NativeWindow::close()
    {
    }

    void NativeWindow::setSize(const Size2& newSize)
    {
        size = newSize;
    }

    void NativeWindow::setFullscreen(bool newFullscreen)
    {
        fullscreen = newFullscreen;
    }

    void NativeWindow::setTitle(const std::string& newTitle)
    {
        title = newTitle;
    }

    void NativeWindow::sendEvent(const Event& event)
    {
        callback(event);
    }
}
