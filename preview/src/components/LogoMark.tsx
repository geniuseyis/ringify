interface LogoMarkProps {
  size?: number
  compact?: boolean
}

export function LogoMark({ size = 56, compact = false }: LogoMarkProps) {
  return (
    <div className="logo-lockup" aria-label="Ringify">
      <span className="logo-mark" style={{ width: size, height: size }} aria-hidden="true">
        <svg viewBox="0 0 56 56" role="img">
          <defs>
            <linearGradient id="ringify-logo-gradient" x1="8" y1="7" x2="50" y2="50">
              <stop stopColor="#b56cff" />
              <stop offset="1" stopColor="#6252ff" />
            </linearGradient>
          </defs>
          <rect x="2" y="2" width="52" height="52" rx="17" fill="url(#ringify-logo-gradient)" />
          <path
            d="M13 29h4l2-8 4 18 4-25 4 29 4-19 3 11 2-6h3"
            fill="none"
            stroke="white"
            strokeWidth="3.3"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </span>
      {compact ? null : <span className="logo-wordmark">Ringify</span>}
    </div>
  )
}
