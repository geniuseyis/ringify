import { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { getAudioContext } from '../lib/audio'
import { SegmentPlayer } from '../lib/segmentPlayer'
import type { EditorState } from '../types'

export function useSegmentPlayer(editor: EditorState, loop = false) {
  const [isPlaying, setIsPlaying] = useState(false)
  const [playhead, setPlayhead] = useState(editor.trimStart)
  const [error, setError] = useState<string | null>(null)
  const request = useRef(0)
  const { buffer } = editor.asset
  const { trimStart, trimEnd } = editor
  const { volume, fadeIn, fadeOut, normalize } = editor.effects
  const studioKey=JSON.stringify(editor.effects.studio??null)
  const loopCrossfade=editor.effects.loopCrossfade
  const player = useMemo(() => buffer ? new SegmentPlayer(getAudioContext(), buffer, trimStart, trimEnd,
    { volume, fadeIn, fadeOut, normalize, loopCrossfade, ...(studioKey==='null'?{}:{studio:JSON.parse(studioKey)}) }) : null, [buffer, trimStart, trimEnd, volume, fadeIn, fadeOut, normalize,studioKey,loopCrossfade])

  // Invalidate asynchronous resume callbacks at commit time, before a previous
  // project's permission result can change the new transport's UI state.
  useLayoutEffect(() => {
    request.current += 1
    return () => { request.current += 1; player?.stop() }
  }, [player])

  useEffect(() => {
    setIsPlaying(false)
    setPlayhead(trimStart)
    setError(null)
    const timer = window.setInterval(() => {
      setIsPlaying(player?.isPlaying ?? false)
      setPlayhead(trimStart + (player?.sourcePosition ?? 0))
    }, 40)
    return () => { window.clearInterval(timer) }
  }, [player, trimStart])

  useEffect(() => { player?.setLoop(loop) }, [player, loop])

  const stop = useCallback(() => {
    request.current += 1
    player?.stop()
    setIsPlaying(false)
    setPlayhead(trimStart)
    setError(null)
  }, [player, trimStart])

  const play = useCallback(async () => {
    const token = ++request.current
    if (!player) { setError('Ses verisi yok / Audio unavailable'); return }
    try {
      if (player.isPlaying) player.pause()
      else await player.play()
      if (token !== request.current) return
      setIsPlaying(player.isPlaying)
      setPlayhead(trimStart + player.sourcePosition)
      setError(null)
    } catch (reason) {
      if (token !== request.current) return
      player.stop()
      setIsPlaying(false)
      setError(reason instanceof Error ? reason.message : 'Ses oynatılamadı / Playback failed')
    }
  }, [player, trimStart])
  return { isPlaying, playhead, play, stop, error }
}
