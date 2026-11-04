import { useEffect, useRef, useState } from 'react'
import type { Language } from '../types'
import { startMicrophoneMeter } from '../lib/microphoneMeter'
import {importLimits} from '../lib/mediaImportLimits'

type RecordingStatus = 'idle' | 'requesting' | 'recording' | 'stopping' | 'ready' | 'error'

export function useVoiceRecorder(language: Language) {
  const [status, setStatus] = useState<RecordingStatus>('idle')
  const [seconds, setSeconds] = useState(0)
  const [level, setLevel] = useState(0)
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [recordedFile, setRecordedFile] = useState<File | null>(null)
  const [error, setError] = useState<string | null>(null)
  const mounted = useRef(true)
  const generation = useRef(0)
  const phase = useRef<RecordingStatus>('idle')
  const stream = useRef<MediaStream | null>(null)
  const recorder = useRef<MediaRecorder | null>(null)
  const stopMeter = useRef<(() => void) | null>(null)
  const objectUrl = useRef<string | null>(null)
  const chunks = useRef<Blob[]>([])
  const startedAt = useRef(0)
  const capturedBytes=useRef(0)

  function transition(next: RecordingStatus) { phase.current = next; setStatus(next) }
  function releaseCapture() {
    const activeRecorder = recorder.current
    recorder.current = null
    if (activeRecorder) {
      activeRecorder.ondataavailable = null
      activeRecorder.onstop = null
      activeRecorder.onerror = null
      try { if (activeRecorder.state !== 'inactive') activeRecorder.stop() } catch { /* Cleanup must still release tracks. */ }
    }
    const releaseMeter = stopMeter.current
    stopMeter.current = null
    try { releaseMeter?.() } finally {
      stream.current?.getTracks().forEach(track => track.stop())
      stream.current = null
      chunks.current = []
      capturedBytes.current=0
    }
  }
  function revokePreview() {
    if (objectUrl.current) URL.revokeObjectURL(objectUrl.current)
    objectUrl.current = null
  }

  useEffect(() => {
    mounted.current = true
    return () => {
      mounted.current = false
      generation.current += 1
      releaseCapture()
      revokePreview()
    }
  }, [])

  useEffect(() => {
    if (status !== 'recording') return
    const timer = window.setInterval(() => {
      const elapsed=(performance.now()-startedAt.current)/1000
      setSeconds(Math.min(importLimits.duration,elapsed))
      if(elapsed>=importLimits.duration)stop()
    }, 100)
    return () => window.clearInterval(timer)
  }, [status])

  function fail(message: string) {
    releaseCapture()
    setLevel(0)
    setError(message)
    transition('error')
  }

  async function start() {
    if (!mounted.current || !['idle', 'error'].includes(phase.current)) return
    transition('requesting') // Synchronous ref gate also blocks double clicks before a re-render.
    setError(null)
    setLevel(0)
    const token = ++generation.current
    const isCurrent = () => mounted.current && generation.current === token
    if (!navigator.mediaDevices?.getUserMedia || typeof MediaRecorder === 'undefined') {
      fail(language === 'tr' ? 'Bu tarayıcı mikrofon kaydını desteklemiyor. Dosyalar’dan ses seçebilirsin.' : 'This browser does not support microphone recording. Choose an audio file instead.')
      return
    }
    try {
      const input = await navigator.mediaDevices.getUserMedia({ audio: true })
      if (!isCurrent()) { input.getTracks().forEach(track => track.stop()); return }
      stream.current = input
      stopMeter.current = startMicrophoneMeter(input, value => {
        if (isCurrent() && phase.current === 'recording') setLevel(Number.isFinite(value) ? Math.max(0, Math.min(1, value)) : 0)
      })
      const capture = new MediaRecorder(input)
      recorder.current = capture
      chunks.current = []
      capture.ondataavailable = event => {
        if(!isCurrent()||!event.data.size)return
        capturedBytes.current+=event.data.size
        if(capturedBytes.current>importLimits.inputBytes){fail(language==='tr'?'Kayıt 32 MiB sınırını aştı. Daha kısa kayıt yapın.':'Recording exceeded 32 MiB. Make a shorter recording.');return}
        chunks.current.push(event.data)
      }
      capture.onerror = () => { if (isCurrent()) fail(language === 'tr' ? 'Kayıt tamamlanamadı. Mikrofonu kontrol edip tekrar dene.' : 'Recording failed. Check your microphone and try again.') }
      capture.onstop = () => {
        if (!isCurrent()) return
        try {
          const type = capture.mimeType || chunks.current[0]?.type || 'audio/webm'
          const blob = new Blob(chunks.current, { type })
          if (!blob.size) throw new Error('Empty recording')
          const extension = type.includes('mp4') ? 'm4a' : type.includes('ogg') ? 'ogg' : type.includes('wav') ? 'wav' : 'webm'
          const file = new File([blob], `ringify-recording-${Date.now()}.${extension}`, { type })
          releaseCapture()
          revokePreview()
          objectUrl.current = URL.createObjectURL(file)
          setRecordedFile(file)
          setAudioUrl(objectUrl.current)
          setLevel(0)
          transition('ready')
        } catch {
          fail(language === 'tr' ? 'Kayıt dosyası oluşturulamadı. Yeniden kaydetmeyi dene.' : 'The recording file could not be created. Try recording again.')
        }
      }
      capture.start(250)
      startedAt.current = performance.now()
      setSeconds(0)
      transition('recording')
    } catch (failure) {
      if (!isCurrent()) return
      const denied = failure instanceof DOMException && (failure.name === 'NotAllowedError' || failure.name === 'SecurityError')
      fail(language === 'tr'
        ? (denied ? 'Mikrofon izni reddedildi. Site izinlerini kontrol edip tekrar dene.' : 'Mikrofon başlatılamadı. Bağlantısını ve başka bir uygulamada kullanımını kontrol et.')
        : (denied ? 'Microphone access was denied. Check site permissions and try again.' : 'The microphone could not start. Check its connection and whether another app is using it.'))
    }
  }

  function stop() {
    if (phase.current !== 'recording' || !recorder.current) return
    setSeconds((performance.now() - startedAt.current) / 1000)
    setLevel(0)
    transition('stopping')
    try { recorder.current.stop() }
    catch { fail(language === 'tr' ? 'Kayıt durdurulamadı. Yeniden dene.' : 'The recording could not stop. Try again.') }
  }

  function discard() {
    generation.current += 1
    releaseCapture()
    revokePreview()
    setAudioUrl(null)
    setRecordedFile(null)
    setSeconds(0)
    setLevel(0)
    setError(null)
    transition('idle')
  }

  const currentTime=()=>phase.current==='recording'?Math.min(importLimits.duration,(performance.now()-startedAt.current)/1000):seconds
  return { status, seconds, level, audioUrl, recordedFile, error, start, stop, discard, currentTime }
}
