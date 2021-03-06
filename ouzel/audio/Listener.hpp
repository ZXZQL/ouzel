// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#ifndef OUZEL_AUDIO_LISTENER_HPP
#define OUZEL_AUDIO_LISTENER_HPP

#include <cfloat>
#include "audio/AudioDevice.hpp"
#include "audio/SoundInput.hpp"
#include "audio/SoundOutput.hpp"
#include "scene/Component.hpp"
#include "math/Quaternion.hpp"
#include "math/Vector3.hpp"

namespace ouzel
{
    namespace audio
    {
        class Audio;

        class Listener: public SoundInput, public SoundOutput, public scene::Component
        {
            friend Audio;
        public:
            Listener(Audio& initAudio);
            virtual ~Listener();

        protected:
            void updateTransform() override;

        private:
            Audio& audio;
            uintptr_t nodeId = 0;

            Vector3 position;
            Quaternion rotation;
            bool transformDirty = true;
        };
    } // namespace audio
} // namespace ouzel

#endif // OUZEL_AUDIO_LISTENER_HPP
