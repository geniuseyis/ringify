import type { ButtonHTMLAttributes, ReactNode } from 'react'

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger'
  fullWidth?: boolean
  icon?: ReactNode
  children: ReactNode
}

export function Button({
  variant = 'primary',
  fullWidth = false,
  icon,
  className = '',
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={`button button-${variant} ${fullWidth ? 'button-full' : ''} ${className}`.trim()}
      {...props}
    >
      {icon ? <span className="button-icon" aria-hidden="true">{icon}</span> : null}
      <span>{children}</span>
    </button>
  )
}
