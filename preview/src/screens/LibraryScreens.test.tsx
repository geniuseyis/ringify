import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { LibraryScreen } from './LibraryScreens'
import { demoProjects } from '../lib/storage'
afterEach(cleanup)
function setup(update = vi.fn().mockResolvedValue(undefined), share = vi.fn().mockResolvedValue(undefined)) {
  render(<LibraryScreen language="tr" projects={demoProjects} onCreate={vi.fn()} onOpenProject={vi.fn()}
    onUpdateProjects={update} onShare={share} />)
  return {update,share}
}
describe('library actions', () => {
  it('filters drafts and exports while preserving search', () => {
    setup()
    fireEvent.click(screen.getByRole('button',{name:'Taslaklar'}))
    expect(screen.getByText('Yumuşak Tını')).toBeInTheDocument()
    expect(screen.queryByText('Sabah Işığı')).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button',{name:'Zil Sesleri'}))
    expect(screen.getByText('Sabah Işığı')).toBeInTheDocument()
    fireEvent.change(screen.getByPlaceholderText('Projelerde ara'),{target:{value:'missing'}})
    expect(screen.getByText('Sonuç bulunamadı')).toBeInTheDocument()
  })
  it('keeps the rename dialog and old record if saving fails', async () => {
    const {update} = setup(vi.fn().mockRejectedValue(new Error('Storage full')))
    fireEvent.click(screen.getByRole('button',{name:'Sabah Işığı seçenekleri'}))
    fireEvent.click(screen.getByText('Yeniden adlandır'))
    fireEvent.change(screen.getByLabelText('Yeni ad'),{target:{value:'Renamed'}})
    fireEvent.click(screen.getByRole('button',{name:'Kaydet'}))
    expect(await screen.findByRole('alert')).toHaveTextContent('Storage full')
    expect(screen.getByRole('dialog')).toBeInTheDocument()
    expect(update).toHaveBeenCalledWith(expect.arrayContaining([expect.objectContaining({name:'Renamed'})]))
  })
  it('passes the selected project to actual file sharing', async () => {
    const {share} = setup()
    fireEvent.click(screen.getByRole('button',{name:'Sabah Işığı seçenekleri'}))
    fireEvent.click(screen.getByText('Paylaş'))
    expect(share).toHaveBeenCalledWith(demoProjects[0])
  })
})
