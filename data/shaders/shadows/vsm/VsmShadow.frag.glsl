#version 460 core
#extension GL_GOOGLE_include_directive : enable
#extension GL_ARB_bindless_texture : require

#include "../../Config.shared.h"
#include "../../visbuffer/VisbufferCommon.h.glsl"
#include "VsmCommon.h.glsl"

layout(binding = 1, r32ui) uniform restrict uimage2D i_physicalPagesUint;

layout(binding = 1, std140) uniform VsmShadowUniforms
{
  uint clipmapLod;
};

layout(location = 0) in vec2 v_uv;
layout(location = 1) in flat uint v_meshletId;
layout(location = 2) in vec3 i_objectSpacePos;

#if VSM_USE_TEMP_ZBUFFER || VSM_USE_TEMP_SBUFFER
layout(early_fragment_tests) in;
#endif

void main()
{
#if VSM_SUPPORT_ALPHA_MASKED_GEOMETRY
  const Meshlet meshlet = meshlets[v_meshletId];
  const GpuMaterial material = materials[NonUniformIndex(meshlet.materialId)];

  vec2 dxuv = dFdx(v_uv);
  vec2 dyuv = dFdy(v_uv);

  const float maxObjSpaceDerivLen = max(length(dFdx(i_objectSpacePos)), length(dFdy(i_objectSpacePos)));
  if (material.baseColorTextureHandle != uvec2(0) && material.alphaCutoff > 0)
  {
    // Apply a mip/lod bias to the sampled value
    if (perFrameUniforms.bindlessSamplerLodBias != 0)
    {
      ApplyLodBiasToGradient(dxuv, dyuv, perFrameUniforms.bindlessSamplerLodBias);
    }

    float alpha = material.baseColorFactor.a;
    if (bool(material.flags & MATERIAL_HAS_BASE_COLOR))
    {
      alpha *= textureGrad(sampler2D(material.baseColorTextureHandle), v_uv, dxuv, dyuv).a;
    }
    
    float threshold = material.alphaCutoff;
    if (bool(perFrameUniforms.flags & USE_HASHED_TRANSPARENCY))
    {
      threshold = ComputeHashedAlphaThreshold(i_objectSpacePos, maxObjSpaceDerivLen, perFrameUniforms.alphaHashScale);
    }

    if (alpha < clamp(threshold, 0.001, 1.0))
    {
      discard;
    }
  }
#endif

  const uint clipmapIndex = clipmapUniforms.clipmapTableIndices[clipmapLod];
  const ivec2 pageOffset = clipmapUniforms.clipmapPageOffsets[clipmapLod];
  const ivec2 pageAddressXy = ivec2(mod(vec2(ivec2(gl_FragCoord.xy) / PAGE_SIZE + pageOffset), vec2(imageSize(i_pageTables).xy)));
  const uint pageData = imageLoad(i_pageTables, ivec3(pageAddressXy, clipmapIndex)).x;
  if (GetIsPageBacked(pageData) && GetIsPageDirty(pageData))
  {
    const ivec2 pageTexel = ivec2(gl_FragCoord.xy) % PAGE_SIZE;
    const uint page = GetPagePhysicalAddress(pageData);
    const int atlasWidth = imageSize(i_physicalPagesUint).x / PAGE_SIZE;
    const ivec2 pageCorner = PAGE_SIZE * ivec2(page / atlasWidth, page % atlasWidth);
    const uint depthUint = floatBitsToUint(gl_FragCoord.z);
    imageAtomicMin(i_physicalPagesUint, pageCorner + pageTexel, depthUint);
  }
}