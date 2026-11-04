import { cleanup, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ImportScreen, RecorderScreen } from './CaptureScreens'
import { useVoiceRecorder } from '../hooks/useVoiceRecorder'

vi.mock('../hooks/useVoiceRecorder', () => ({ useVoiceRecorder: vi.fn() }))
beforeEach(() => {
  vi.mocked(useVoiceRecorder).mockReturnValue({status:'idle',seconds:0,level:0,audioUrl:null,recordedFile:null,error:null,start:vi.fn().mockResolvedValue(undefined),stop:vi.fn(),discard:vi.fn(),currentTime:()=>0})
})
afterEach(cleanup)

describe('Capture screen information cleanup', () => {
  it('removes import notices and the information-only footer without removing source controls', () => {
    const { container } = render(<ImportScreen language="tr" isLoading={false} error={null} onBack={vi.fn()} onChooseFile={vi.fn()} onUseDemo={vi.fn()} onNavigate={vi.fn()} onClearError={vi.fn()} />)
    expect(container.querySelector('aside, footer, .r-local-note')).toBeNull()
    expect(screen.queryByText(/Yalnızca kullanım hakkına/)).not.toBeInTheDocument()
    expect(screen.getByRole('button',{name:'Dosyalar’dan ses'})).toBeInTheDocument()
    expect(screen.getByRole('button',{name:'Mikrofonla kaydet'})).toBeInTheDocument()
  })
  it('removes recorder helper notes but retains duration, meter and the real recording action', () => {
    const { container } = render(<RecorderScreen language="tr" onBack={vi.fn()} onUseRecording={vi.fn()} />)
    expect(container.querySelector('aside, .r-record-hint, .r-local-note')).toBeNull()
    expect(screen.queryByText(/Kayıt cihazında kalır/)).not.toBeInTheDocument()
    expect(screen.getByLabelText('Kayıt süresi')).toHaveTextContent('0:00.0')
    expect(screen.getByRole('meter')).toHaveAttribute('aria-valuenow','0')
    expect(screen.getByRole('button',{name:'Kaydı Başlat'})).toBeEnabled()
  })
})
