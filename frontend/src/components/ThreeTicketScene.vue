<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import * as THREE from 'three'

const mount = ref(null)
let renderer
let scene
let camera
let frameId
let group

function roundedPanel(width, height, depth, color) {
  const geom = new THREE.BoxGeometry(width, height, depth, 4, 4, 2)
  const mat = new THREE.MeshStandardMaterial({
    color,
    metalness: 0.35,
    roughness: 0.28,
  })
  const mesh = new THREE.Mesh(geom, mat)
  return mesh
}

onMounted(() => {
  if (!mount.value) return

  scene = new THREE.Scene()
  camera = new THREE.PerspectiveCamera(42, 1, 0.1, 100)
  camera.position.set(0, 0.3, 7)

  renderer = new THREE.WebGLRenderer({
    antialias: true,
    alpha: true,
  })

  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
  renderer.setSize(
    mount.value.clientWidth,
    mount.value.clientHeight
  )
  renderer.outputColorSpace = THREE.SRGBColorSpace
  mount.value.appendChild(renderer.domElement)

  const ambient = new THREE.AmbientLight(0xffffff, 1.2)
  scene.add(ambient)

  const key = new THREE.PointLight(0x37e3b1, 20, 15)
  key.position.set(3.5, 4, 5)
  scene.add(key)

  const rim = new THREE.PointLight(0x53c7e6, 14, 15)
  rim.position.set(-4, -2, 4)
  scene.add(rim)

  group = new THREE.Group()
  scene.add(group)

  const core = roundedPanel(3.65, 2.25, 0.38, 0x111915)
  core.rotation.x = -0.08
  core.rotation.y = -0.18
  group.add(core)

  const edgeMat = new THREE.LineBasicMaterial({ color: 0x4fe1b6 })
  const edges = new THREE.EdgesGeometry(core.geometry)
  const edgeLines = new THREE.LineSegments(edges, edgeMat)
  edgeLines.position.copy(core.position)
  edgeLines.rotation.copy(core.rotation)
  edgeLines.scale.setScalar(1.001)
  group.add(edgeLines)

  const titleBar = roundedPanel(2.7, 0.16, 0.16, 0x28352f)
  titleBar.position.set(-0.12, 0.63, 0.29)
  titleBar.rotation.copy(core.rotation)
  group.add(titleBar)

  const ticketBar = roundedPanel(2.35, 0.22, 0.12, 0x23332d)
  ticketBar.position.set(-0.22, 0.12, 0.32)
  ticketBar.rotation.copy(core.rotation)
  group.add(ticketBar)

  const ticketBar2 = roundedPanel(1.72, 0.18, 0.12, 0x1c2924)
  ticketBar2.position.set(-0.52, -0.36, 0.31)
  ticketBar2.rotation.copy(core.rotation)
  group.add(ticketBar2)

  const badge = new THREE.Mesh(
    new THREE.CylinderGeometry(0.22, 0.22, 0.11, 32),
    new THREE.MeshStandardMaterial({
      color: 0x32e5b0,
      emissive: 0x0d5c48,
      emissiveIntensity: 1.2,
      metalness: 0.35,
      roughness: 0.25,
    })
  )
  badge.rotation.x = Math.PI / 2
  badge.position.set(1.28, 0.1, 0.42)
  group.add(badge)

  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(2.55, 0.035, 14, 120),
    new THREE.MeshStandardMaterial({
      color: 0x36d5b0,
      emissive: 0x123d34,
      emissiveIntensity: 0.8,
      transparent: true,
      opacity: 0.55,
    })
  )
  ring.rotation.x = Math.PI / 2.35
  ring.rotation.z = 0.4
  group.add(ring)

  const ring2 = new THREE.Mesh(
    new THREE.TorusGeometry(3.05, 0.018, 10, 120),
    new THREE.MeshStandardMaterial({
      color: 0x62cde1,
      transparent: true,
      opacity: 0.3,
    })
  )
  ring2.rotation.y = Math.PI / 2.5
  ring2.rotation.z = -0.5
  group.add(ring2)

  const particlesGeometry = new THREE.BufferGeometry()
  const particleCount = 140
  const positions = new Float32Array(particleCount * 3)

  for (let i = 0; i < particleCount; i++) {
    positions[i * 3] = (Math.random() - 0.5) * 8
    positions[i * 3 + 1] = (Math.random() - 0.5) * 6
    positions[i * 3 + 2] = (Math.random() - 0.5) * 5
  }

  particlesGeometry.setAttribute(
    'position',
    new THREE.BufferAttribute(positions, 3)
  )

  const particles = new THREE.Points(
    particlesGeometry,
    new THREE.PointsMaterial({
      color: 0x5ddfba,
      size: 0.025,
      transparent: true,
      opacity: 0.7,
    })
  )
  scene.add(particles)

  const clock = new THREE.Clock()

  function render() {
    const t = clock.getElapsedTime()

    group.rotation.y = Math.sin(t * 0.45) * 0.18
    group.rotation.x = Math.cos(t * 0.32) * 0.06
    group.position.y = Math.sin(t * 0.7) * 0.12

    ring.rotation.z += 0.0025
    ring2.rotation.x += 0.0015
    particles.rotation.y += 0.0005

    renderer.render(scene, camera)
    frameId = requestAnimationFrame(render)
  }

  render()

  const ro = new ResizeObserver(() => {
    if (!mount.value || !renderer || !camera) return

    const width = mount.value.clientWidth
    const height = mount.value.clientHeight

    renderer.setSize(width, height)
    camera.aspect = width / Math.max(height, 1)
    camera.updateProjectionMatrix()
  })

  ro.observe(mount.value)
  mount.value.__tfResizeObserver = ro
})

onBeforeUnmount(() => {
  cancelAnimationFrame(frameId)

  if (mount.value?.__tfResizeObserver) {
    mount.value.__tfResizeObserver.disconnect()
  }

  if (renderer) {
    renderer.dispose()
    renderer.domElement?.remove()
  }

  if (scene) {
    scene.traverse((object) => {
      object.geometry?.dispose?.()

      if (Array.isArray(object.material)) {
        object.material.forEach((m) => m.dispose?.())
      } else {
        object.material?.dispose?.()
      }
    })
  }
})
</script>

<template>
  <div ref="mount" class="tf-three-stage" aria-label="Animated 3D TicketFlow model"></div>
</template>
