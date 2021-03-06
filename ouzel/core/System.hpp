// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#ifndef OUZEL_CORE_SYSTEM_HPP
#define OUZEL_CORE_SYSTEM_HPP

namespace ouzel
{
    class System
    {
    public:
        class Command final
        {
        public:
            enum class Type
            {
                SET_SCREENSAVER_ENABLED,
                OPEN_URL
            };
        };

        class Event
        {
        public:
            enum class Type
            {
                LAUNCH,
                DEVICE_ORIENTATION_CHANGE,
                LOW_MEMORY,
                OPEN_FILE
            };

        };

        virtual ~System() {}
    };
}

#endif // OUZEL_CORE_SYSTEM_HPP
