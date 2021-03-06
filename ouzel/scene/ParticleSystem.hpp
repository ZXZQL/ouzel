// Copyright 2015-2018 Elviss Strazdins. All rights reserved.

#ifndef OUZEL_SCENE_PARTICLESYSTEM_HPP
#define OUZEL_SCENE_PARTICLESYSTEM_HPP

#include <string>
#include <vector>
#include <functional>
#include "scene/Component.hpp"
#include "scene/ParticleSystemData.hpp"
#include "math/Vector2.hpp"
#include "math/Color.hpp"
#include "events/EventHandler.hpp"
#include "graphics/Vertex.hpp"
#include "graphics/BlendState.hpp"
#include "graphics/Buffer.hpp"
#include "graphics/Shader.hpp"
#include "graphics/Texture.hpp"

namespace ouzel
{
    namespace scene
    {
        class ParticleSystem: public Component
        {
        public:
            static const uint32_t CLASS = Component::PARTICLE_SYSTEM;

            ParticleSystem();
            explicit ParticleSystem(const ParticleSystemData& initParticleSystemData);
            explicit ParticleSystem(const std::string& filename);

            void draw(const Matrix4& transformMatrix,
                      float opacity,
                      const Matrix4& renderViewProjection,
                      bool wireframe) override;

            void init(const ParticleSystemData& newParticleSystemData);
            void init(const std::string& filename);

            void resume();
            void stop();
            void reset();

            bool isRunning() const { return running; }
            bool isActive() const { return active; }

            inline ParticleSystemData::PositionType getPositionType() const { return particleSystemData.positionType; }
            inline void setPositionType(ParticleSystemData::PositionType newPositionType) { particleSystemData.positionType = newPositionType; }

        private:
            void update(float delta);
            bool handleUpdate(const UpdateEvent& event);

            void createParticleMesh();
            void updateParticleMesh();

            void emitParticles(uint32_t count);

            ParticleSystemData particleSystemData;

            std::shared_ptr<graphics::Shader> shader;
            std::shared_ptr<graphics::BlendState> blendState;
            std::shared_ptr<graphics::Texture> texture;
            std::shared_ptr<graphics::Texture> whitePixelTexture;

            struct Particle final
            {
                float life = 0.0F;

                Vector2 position;

                float colorRed = 0.0F;
                float colorGreen = 0.0F;
                float colorBlue = 0.0F;
                float colorAlpha = 0.0F;

                float deltaColorRed = 0.0F;
                float deltaColorGreen = 0.0F;
                float deltaColorBlue = 0.0F;
                float deltaColorAlpha = 0.0F;

                float angle = 0.0F;
                float speed = 0.0F;

                float size = 0.0F;
                float deltaSize = 0.0F;

                float rotation = 0.0F;
                float deltaRotation = 0.0F;

                float radialAcceleration = 0.0F;
                float tangentialAcceleration = 0.0F;

                Vector2 direction;
                float radius = 0.0F;
                float degreesPerSecond = 0.0F;
                float deltaRadius = 0.0F;
            };

            std::vector<Particle> particles;

            std::shared_ptr<graphics::Buffer> indexBuffer;
            std::shared_ptr<graphics::Buffer> vertexBuffer;

            std::vector<uint16_t> indices;
            std::vector<graphics::Vertex> vertices;

            uint32_t particleCount = 0;

            float emitCounter = 0.0F;
            float elapsed = 0.0F;
            float timeSinceUpdate = 0.0F;
            bool active = false;
            bool running = false;
            bool finished = false;

            bool needsMeshUpdate = false;

            EventHandler updateHandler;
        };
    } // namespace scene
} // namespace ouzel

#endif // OUZEL_SCENE_PARTICLESYSTEM_HPP
