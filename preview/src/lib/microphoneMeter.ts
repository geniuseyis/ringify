export function rmsLevel(samples: Float32Array): number {
  if (samples.length === 0) return 0
  let sum = 0
  for (const value of samples) sum += value * value
  return Math.min(1, Math.sqrt(sum / samples.length))
}

export function startMicrophoneMeter(stream: MediaStream, onLevel: (level: number) => void): () => void {
  const context = new AudioContext()
  const source = context.createMediaStreamSource(stream)
  const analyser = context.createAnalyser()
  analyser.fftSize = 2048
  source.connect(analyser) // Never connect the microphone to the speakers.
  const samples = new Float32Array(analyser.fftSize)
  const timer = window.setInterval(() => {
    analyser.getFloatTimeDomainData(samples)
    onLevel(rmsLevel(samples))
  }, 80)
  void context.resume().catch(() => onLevel(0))
  return () => {
    window.clearInterval(timer)
    source.disconnect()
    analyser.disconnect()
    void context.close()
  }
}
