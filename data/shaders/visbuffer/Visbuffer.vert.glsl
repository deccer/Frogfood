#version 460 core
#extension GL_GOOGLE_include_directive : enable
#include "VisbufferCommon.h.glsl"

layout (location = 0) out flat uint o_meshletId;
layout (location = 1) out flat uint o_primitiveId;
layout (location = 2) out vec2 o_uv;
layout (location = 3) out vec3 o_objectSpacePos;

void main()
{
  const uint meshletId = (uint(gl_VertexIndex) >> MESHLET_PRIMITIVE_BITS) & MESHLET_ID_MASK;
  const uint primitiveId = uint(gl_VertexIndex) & MESHLET_PRIMITIVE_MASK;
  const uint vertexOffset = d_meshlets[meshletId].vertexOffset;
  const uint indexOffset = d_meshlets[meshletId].indexOffset;
  const uint primitiveOffset = d_meshlets[meshletId].primitiveOffset;
  const uint instanceId = d_meshlets[meshletId].instanceId;
  
  const uint primitive = uint(d_primitives[primitiveOffset + primitiveId]);
  const uint index = d_indices[indexOffset + primitive];
  const Vertex vertex = d_vertices[vertexOffset + index];
  const vec3 position = PackedToVec3(vertex.position);
  const vec2 uv = PackedToVec2(vertex.uv);
  const mat4 transform = d_transforms[instanceId].modelCurrent;

  o_meshletId = meshletId;
  o_primitiveId = primitiveId / 3;
  o_uv = uv;
  o_objectSpacePos = position;

  gl_Position = d_perFrameUniforms.viewProj * transform * vec4(position, 1.0);
}