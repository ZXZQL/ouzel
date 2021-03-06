// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#include <stdexcept>
#include <vector>
#include "Language.hpp"
#include "utils/Utils.hpp"

namespace ouzel
{
    struct TranslationInfo final
    {
        uint32_t stringLength;
        uint32_t stringOffset;

        uint32_t translationLength;
        uint32_t translationOffset;
    };

    Language::Language(const std::vector<uint8_t>& data)
    {
        const unsigned long MAGIC_BIG = 0xde120495;
        const unsigned long MAGIC_LITTLE = 0x950412de;

        uint32_t offset = 0;

        if (data.size() < 5 * sizeof(uint32_t))
            throw std::runtime_error("Not enough data");

        uint32_t magic = *reinterpret_cast<const uint32_t*>(data.data() + offset);
        offset += sizeof(magic);

        uint32_t (*decodeUInt32)(const void*) = nullptr;

        if (magic == MAGIC_BIG)
            decodeUInt32 = decodeUInt32Big;
        else if (magic == MAGIC_LITTLE)
            decodeUInt32 = decodeUInt32Little;
        else
            throw std::runtime_error("Wrong magic " + std::to_string(magic));

        uint32_t revision = decodeUInt32(data.data() + offset);
        offset += sizeof(revision);

        if (revision != 0)
            throw std::runtime_error("Unsupported revision " + std::to_string(revision));

        uint32_t stringCount = decodeUInt32(data.data() + offset);
        offset += sizeof(stringCount);

        std::vector<TranslationInfo> translations(stringCount);

        uint32_t stringsOffset = decodeUInt32(data.data() + offset);
        offset += sizeof(stringsOffset);

        uint32_t translationsOffset = decodeUInt32(data.data() + offset);
        offset += sizeof(translationsOffset);

        offset = stringsOffset;

        if (data.size() < offset + 2 * sizeof(uint32_t) * stringCount)
            throw std::runtime_error("Not enough data");

        for (uint32_t i = 0; i < stringCount; ++i)
        {
            translations[i].stringLength = decodeUInt32(data.data() + offset);
            offset += sizeof(translations[i].stringLength);

            translations[i].stringOffset = decodeUInt32(data.data() + offset);
            offset += sizeof(translations[i].stringOffset);
        }

        offset = translationsOffset;

        if (data.size() < offset + 2 * sizeof(uint32_t) * stringCount)
            throw std::runtime_error("Not enough data");

        for (uint32_t i = 0; i < stringCount; ++i)
        {
            translations[i].translationLength = decodeUInt32(data.data() + offset);
            offset += sizeof(translations[i].translationLength);

            translations[i].translationOffset = decodeUInt32(data.data() + offset);
            offset += sizeof(translations[i].translationOffset);
        }

        for (uint32_t i = 0; i < stringCount; ++i)
        {
            if (data.size() < translations[i].stringOffset + translations[i].stringLength ||
                data.size() < translations[i].translationOffset + translations[i].translationLength)
                throw std::runtime_error("Not enough data");

            std::string str(reinterpret_cast<const char*>(data.data() + translations[i].stringOffset), translations[i].stringLength);
            std::string translation(reinterpret_cast<const char*>(data.data() + translations[i].translationOffset), translations[i].translationLength);

            strings[str] = translation;
        }
    }

    std::string Language::getString(const std::string& str)
    {
        auto i = strings.find(str);

        if (i != strings.end())
            return i->second;
        else
            return str;
    }
}
