#include <sceneUboDeclaration>
#include <meshUboDeclaration>

attribute position: vec3<f32>;
attribute normal: vec3<f32>;
attribute uv: vec2<f32>;

varying coords: vec2<f32>;

@vertex
fn main(input: VertexInputs) -> FragmentInputs {
  vertexOutputs.position = scene.viewProjection * mesh.world * vec4<f32>(input.position, 1.0);
  vertexOutputs.coords = (mesh.world * vec4<f32>(input.position, 1.0)).xy;
}
