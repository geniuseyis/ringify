import type { ReactNode } from 'react'
import { AlertTriangle, Inbox, LoaderCircle } from 'lucide-react'
import { Button } from './Button'

export function LoadingView({ label = 'Hazırlanıyor…' }: { label?: string }) {
  return (
    <div className="state-view" role="status">
      <LoaderCircle className="spin" size={30} />
      <strong>{label}</strong>
    </div>
  )
}

export function EmptyView({
  title,
  description,
  action,
}: {
  title: string
  description: string
  action?: ReactNode
}) {
  return (
    <div className="state-view state-card">
      <span className="state-icon"><Inbox size={27} /></span>
      <strong>{title}</strong>
      <p>{description}</p>
      {action}
    </div>
  )
}

export function ErrorView({ title, description, onRetry }: { title: string; description: string; onRetry?: () => void }) {
  return (
    <div className="state-view state-card" role="alert">
      <span className="state-icon state-icon-error"><AlertTriangle size={27} /></span>
      <strong>{title}</strong>
      <p>{description}</p>
      {onRetry ? <Button variant="secondary" onClick={onRetry}>Tekrar Dene</Button> : null}
    </div>
  )
}
