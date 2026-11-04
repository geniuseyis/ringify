import { sanitizeFileName } from './format'

export function downloadAudio(blob: Blob, name: string) {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = `${sanitizeFileName(name) || 'Ringify'}.wav`
  document.body.append(link)
  link.click()
  link.remove()
  window.setTimeout(() => URL.revokeObjectURL(url), 30_000)
}

export async function shareAudioFile(blob: Blob, name: string): Promise<'shared' | 'downloaded' | 'cancelled'> {
  const file = new File([blob], `${sanitizeFileName(name) || 'Ringify'}.wav`, { type: 'audio/wav' })
  if (navigator.share && navigator.canShare?.({ files: [file] })) {
    try { await navigator.share({ title: name, files: [file] }); return 'shared' }
    catch (error) {
      if (typeof error === 'object' && error !== null && 'name' in error && error.name === 'AbortError') return 'cancelled'
      throw error
    }
  }
  downloadAudio(blob, name)
  return 'downloaded'
}
