// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#ifndef OUZEL_AUDIO_STREAMWAVE_HPP
#define OUZEL_AUDIO_STREAMWAVE_HPP

#include <cstdint>
#include "Stream.hpp"

namespace ouzel
{
    namespace audio
    {
        class StreamWave final: public Stream
        {
        public:
            void reset() override;

            inline uint32_t getOffset() const { return offset; }
            inline void setOffset(uint32_t newOffset) { offset = newOffset; }

        private:
            uint32_t offset = 0;
        };
    } // namespace audio
} // namespace ouzel

#endif // OUZEL_AUDIO_STREAMWAVE_HPP
