// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#ifndef OUZEL_AUDIO_GAIN_HPP
#define OUZEL_AUDIO_GAIN_HPP

#include "audio/SoundInput.hpp"
#include "audio/SoundOutput.hpp"

namespace ouzel
{
    namespace audio
    {
        class Audio;

        class Gain final: public SoundInput, public SoundOutput
        {
        public:
            Gain(Audio& initAudio);
            ~Gain();

            Gain(const Gain&) = delete;
            Gain& operator=(const Gain&) = delete;

            Gain(Audio&&) = delete;
            Gain& operator=(Gain&&) = delete;
            
            float getGain() const { return gain; }
            void setGain(float newGain);

        private:
            Audio& audio;
            uintptr_t nodeId = 0;
            float gain = 0.0F;
        };
    } // namespace audio
} // namespace ouzel

#endif // OUZEL_AUDIO_GAIN_HPP
