export function formatTime(value: number) {
  const safe = Number.isFinite(value) ? Math.max(0, value) : 0
  const minutes = Math.floor(safe / 60)
  const seconds = Math.floor(safe % 60)
  const tenths = Math.floor((safe % 1) * 10)
  return `${minutes}:${seconds.toString().padStart(2, '0')}.${tenths}`
}
export function formatFileSize(bytes:number,language:'tr'|'en'){
  if(!Number.isSafeInteger(bytes)||bytes<0)return '—'
  const factor=bytes>=1_000_000?1_000_000:bytes>=1000?1000:1
  return `${new Intl.NumberFormat(language==='tr'?'tr-TR':'en-US',{maximumFractionDigits:2}).format(bytes/factor)} ${factor===1_000_000?'MB':factor===1000?'kB':'B'}`
}

export function formatDate(value: string, locale: string) {
  return new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'short' }).format(new Date(value))
}

export function sanitizeFileName(value: string) {
  return value
    .trim()
    .replace(/[<>:"/\\|?*\u0000-\u001F]/g, '-')
    .replace(/\.+$/g, '')
    .slice(0, 64)
}
