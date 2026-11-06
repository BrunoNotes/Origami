// info about bindings https://wiki.libsdl.org/SDL3/SDL_CreateGPUShader
struct VertexIn {
  // the location can be implied by the order in the struct
  [[vk::location(0)]]
  float3 position;
  [[vk::location(1)]]
  float4 color;
  [[vk::location(2)]]
  float2 uv;
  [[vk::location(3)]]
  float3 normal;
}

struct VertexOut {
  float4 position : SV_Position;
  float4 color;
  float2 uv;
  float3 normal;
}

struct FragmentIn {
  float4 color;
  float2 uv;
  float3 normal;
}

struct FragmentOut {
  float4 color : SV_Target;
}

// vertex uniform
[[vk::binding(0, 1)]]
ConstantBuffer<float4x4> u_projection_matrix;
[[vk::binding(1, 1)]]
ConstantBuffer<float4x4> u_view_matrix;
[[vk::binding(2, 1)]]
ConstantBuffer<float4x4> u_transform_matrix;

// fragment uniform
[[vk::binding(0, 3)]]
ConstantBuffer<float4> u_color;

[shader("vertex")]
VertexOut vertexMain(VertexIn input) {
  VertexOut output;

  float4x4 projection = u_projection_matrix;
  float4x4 view = mul(projection, u_view_matrix);
  float4x4 transform = mul(view, u_transform_matrix);
  output.position = mul(transform, float4(input.position, 1.0));

  output.color = input.color;
  output.uv = input.uv;
  output.normal = input.normal;

  return output;
}

[[vk::binding(0, 2)]]
Sampler2D texture;

[shader("fragment")]
FragmentOut fragmentMain(FragmentIn input) {
  FragmentOut output;

  float4 tex_color = texture.Sample(input.uv);
  output.color = input.color * u_color * tex_color;

  return output;
}

