import {
  ArcRotateCamera,
  AxesViewer,
  Camera,
  Engine,
  Mesh,
  MeshBuilder,
  Scene,
  ShaderLanguage,
  ShaderMaterial,
  Vector3,
  WebGPUEngine,
} from '@babylonjs/core'
import {
  loadWGSLShaders,
} from '@inhibitor1217/babylonjs-wgsl'

import './style.css'

async function prepare(canvas: HTMLCanvasElement): Promise<WebGPUEngine> {
  const engine = new WebGPUEngine(canvas)
  await engine.initAsync()

  await loadWGSLShaders(await import.meta.glob('./material/**/*.wgsl', { as: 'raw' }))

  window.addEventListener('resize', () => {
    engine.resize()
  })

  return engine
}

async function orthographicCamera(scene: Scene): Promise<Camera> {
  const camera = new ArcRotateCamera('camera', -0.5 * Math.PI, 0.5 * Math.PI, 4, Vector3.Zero(), scene)

  camera.mode = Camera.ORTHOGRAPHIC_CAMERA
  const rect = camera.getEngine().getRenderingCanvasClientRect()
  const aspectRatio = rect ? (rect.width / rect.height) : 1.0

  camera.orthoLeft = -camera.radius * aspectRatio;
  camera.orthoRight = camera.radius * aspectRatio;
  camera.orthoBottom = -camera.radius;
  camera.orthoTop = camera.radius;
  
  camera.setTarget(Vector3.Zero())

  return camera;
}

async function fullQuad(scene: Scene): Promise<Mesh> {
  const rect = scene.getEngine().getRenderingCanvasClientRect()

  const quad = MeshBuilder.CreatePlane('quad', { width: rect?.width, height: rect?.height }, scene)
  quad.position = Vector3.Zero()

  return quad
}

async function shaderMaterial(
  engine: Engine,
  scene: Scene,
  shader: string,
): Promise<ShaderMaterial> {
  const mat = new ShaderMaterial(
    shader,
    scene,
    {
      vertex: shader,
      fragment: shader,
    },
    {
      attributes: ['position', 'normal', 'uv'],
      uniformBuffers: ['Scene', 'Mesh'],
      shaderLanguage: ShaderLanguage.WGSL,
    },
  )

  return mat
}

async function createScene(engine: Engine): Promise<Scene> {
  const scene = new Scene(engine)

  const _camera = await orthographicCamera(scene)

  const organismMat = await shaderMaterial(engine, scene, 'organism')
  const quad = await fullQuad(scene)
  quad.material = organismMat
  
  const _axesViewer = new AxesViewer(scene)

  return scene
}

async function main() {
  const canvas = document.getElementById('root') as HTMLCanvasElement

  const engine = await prepare(canvas)
  const scene = await createScene(engine)

  engine.runRenderLoop(() => {
    scene.render()
  })
}

main()
