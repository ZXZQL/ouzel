// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#include "NativeWindowAndroid.hpp"
#include "EngineAndroid.hpp"
#include "utils/Errors.hpp"

namespace ouzel
{
    NativeWindowAndroid::NativeWindowAndroid(const std::function<void(const Event&)>& initCallback,
                                             const std::string& newTitle):
        NativeWindow(initCallback,
                     Size2(),
                     true,
                     true,
                     true,
                     newTitle,
                     true)
    {
        EngineAndroid* engineAndroid = static_cast<EngineAndroid*>(engine);
        JavaVM* javaVM = engineAndroid->getJavaVM();
        JNIEnv* jniEnv;

        if (javaVM->GetEnv(reinterpret_cast<void**>(&jniEnv), JNI_VERSION_1_6) != JNI_OK)
            throw SystemError("Failed to get JNI environment");

        window = ANativeWindow_fromSurface(jniEnv, engineAndroid->getSurface());

        size.width = static_cast<float>(ANativeWindow_getWidth(window));
        size.height = static_cast<float>(ANativeWindow_getHeight(window));
        resolution = size;
    }

    NativeWindowAndroid::~NativeWindowAndroid()
    {
        if (window) ANativeWindow_release(window);
    }

    void NativeWindowAndroid::handleResize(const Size2& newSize)
    {
        size = newSize;
        resolution = size;

        Event sizeChangeEvent(Event::Type::SIZE_CHANGE);
        sizeChangeEvent.size = size;
        sendEvent(sizeChangeEvent);

        Event resolutionChangeEvent(Event::Type::RESOLUTION_CHANGE);
        resolutionChangeEvent.resolution = resolution;
        sendEvent(resolutionChangeEvent);
    }

    void NativeWindowAndroid::handleSurfaceChange(jobject surface)
    {
        EngineAndroid* engineAndroid = static_cast<EngineAndroid*>(engine);
        JavaVM* javaVM = engineAndroid->getJavaVM();
        JNIEnv* jniEnv;

        if (javaVM->GetEnv(reinterpret_cast<void**>(&jniEnv), JNI_VERSION_1_6) != JNI_OK)
            throw SystemError("Failed to get JNI environment");

        if (window) ANativeWindow_release(window);
        window = ANativeWindow_fromSurface(jniEnv, surface);
    }

    void NativeWindowAndroid::handleSurfaceDestroy()
    {
        if (window)
        {
            ANativeWindow_release(window);
            window = nullptr;
        }
    }
}
