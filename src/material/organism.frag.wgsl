#include <color>
#include <noise/simplex>
#include <random/sine_fract>
#include <random/sine_fract_linker>
#include <random/ndim>

varying coords: vec2<f32>;

var<uniform> elapsedTimeMs: f32;

const FREQUENCY: vec2<f32> = vec2<f32>(0.8, 0.8);

fn palette(t: f32) -> vec3<f32> {
  const A0: vec3<f32> = vec3<f32>(0.5, 0.5, 0.5);
  const B0: vec3<f32> = vec3<f32>(0.5, 0.5, 0.5);
  const C0: vec3<f32> = vec3<f32>(1.0, 1.0, 1.0);
  const D0: vec3<f32> = vec3<f32>(0.0, 0.1, 0.2);

  const A1: vec3<f32> = vec3<f32>(0.5, 0.5, 0.5);
  const B1: vec3<f32> = vec3<f32>(0.5, 0.5, 0.5);
  const C1: vec3<f32> = vec3<f32>(1.0, 1.0, 0.5);
  const D1: vec3<f32> = vec3<f32>(0.8, 0.9, 0.3);

  let p0 = A0 + B0 * cos(6.28318 * (C0 * t + D0));
  let p1 = A1 + B1 * cos(6.28318 * (C1 * t + D1));

  return mix(p0, p1, smoothstep(-0.5, 0.5, sin(t)));
}

fn mod289(x: f32) -> f32 {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

fn voronoi(
  pos: vec2<f32>,
  seed: i32,
  nearest: ptr<function, vec4<f32>>,
  secondNearest: ptr<function, vec4<f32>>,
) -> vec2<f32> {
  let sampleOffset = mod289(f32(seed)) * vec2<f32>(16.0, 16.0);

  let iPos = floor(pos);
  let fPos = fract(pos);

  var dist = vec2<f32>(16.0, 16.0);

  for (var y: i32 = -1; y <= 1; y = y + 1) {
    for (var x: i32 = -1; x <= 1; x = x + 1) {
      let neighbor = vec2<f32>(f32(x), f32(y));
      let featurePoint = RANDOM__random2d__f32_2d(iPos + neighbor + sampleOffset);
      let offset = neighbor + featurePoint - fPos;
      let d = dot(offset, offset);
      
      if (d < dist.x) {
        dist.y = dist.x;
        *secondNearest = *nearest;
        dist.x = d;
        *nearest = vec4<f32>(offset, iPos + neighbor + featurePoint);
      } else if (d < dist.y) {
        dist.y = d;
        *secondNearest = vec4<f32>(offset, iPos + neighbor + featurePoint);
      }
    }
  }

  return sqrt(dist);
}

fn isHole(pos: vec2<f32>) -> bool {
  var d = 0.0;

  d += length(pos * vec2<f32>(1.5, 1.0));
  d += 1.5 * NOISE_SIMPLEX__noise2d__f32(pos);

  return d < 4.0;
}

fn voronoiLayer(
  pos: vec2<f32>,
  seed: i32,
) -> f32 {
  var nearest: vec4<f32>;
  var secondNearest: vec4<f32>;
  let dist = voronoi(pos, seed, &nearest, &secondNearest);

  let nearestOffset = nearest.xy;
  let secondNearestOffset = secondNearest.xy;

  let nearestFeaturePoint = nearest.zw;
  let secondNearestFeaturePoint = secondNearest.zw;

  let midpoint = 0.5 * (nearestOffset + secondNearestOffset);
  let normal = normalize(secondNearestOffset - nearestOffset);
  let proj = dot(midpoint, normal);

  var intensity = 0.0;

  let isExterior = !isHole(nearestFeaturePoint);
  let isInterior = !isExterior && isHole(secondNearestFeaturePoint);

  // Fill
  if (isExterior) {
    intensity += 2.0 * proj;
  }
  
  // Outline
  if (!isInterior) {
    intensity += 0.33 * (1.0 - smoothstep(0.00, 0.01, proj));
  }

  return intensity;
}

fn color_at(pos: vec2<f32>) -> vec4<f32> {
  let sampledPos = pos * FREQUENCY;

  const NUM_LAYERS: i32 = 9;
  const LAYER_SCALE: f32 = 0.70;
  const LAYER_OFFSET: f32 = 1.0;
  const FOG_COLOR: vec3<f32> = vec3<f32>(0.0);
  const TIMESCALE: f32 = 1500.0;

  let normalizedTime = elapsedTimeMs / TIMESCALE;
  let iTime = i32(floor(normalizedTime));
  let fTime = fract(normalizedTime);

  var color = FOG_COLOR;
  var scale = pow(1. / LAYER_SCALE, f32(NUM_LAYERS) - fTime);
  var offset = vec2<f32>(cos(1.0), sin(1.0));
  var offsetAmount = -(f32(NUM_LAYERS) + 1.0 - fTime) * LAYER_OFFSET;

  for (var i: i32 = -NUM_LAYERS; i < 0; i = i + 1) {
    // Calculate layer properties
    let layerId = -i + iTime;
    let layerZ  = f32(i) + fTime;

    // Update layer dimensions
    scale *= LAYER_SCALE;
    offsetAmount += LAYER_OFFSET;

    // Sample layer
    let layerSampledPos = sampledPos * scale + offset * offsetAmount;
    var layerIntensity = voronoiLayer(layerSampledPos, layerId);
    let layerColor = palette(f32(layerId) * 0.05);

    // Blend layer
    if (layerIntensity > 0.0) {
      // Layer
      let nearFog = smoothstep(0.0, -1.0, layerZ);
      let farFog  = smoothstep(-f32(NUM_LAYERS), -f32(NUM_LAYERS) + 1.0, layerZ);

      color =
        nearFog * farFog * layerIntensity * layerColor +
        mix(FOG_COLOR, color, mix(1.00, 0.33, smoothstep(-1.0, -2.0, layerZ)));
    } else {
      // Fog
      color = mix(FOG_COLOR, color, mix(1.00, 0.67, smoothstep(-1.0, -2.0, layerZ)));
    }
  }

  return vec4<f32>(color, 1.0);
}

@fragment
fn main(input: FragmentInputs) -> FragmentOutputs {
  fragmentOutputs.color = color_at(fragmentInputs.coords);
}
