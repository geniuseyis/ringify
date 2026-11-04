import {useRef, useState} from 'react'
import {cleanup, fireEvent, render, screen} from '@testing-library/react'
import {afterEach, describe, expect, it, vi} from 'vitest'
import {ModalSheet} from './ModalSheet'

afterEach(cleanup)

function Harness({busy=false, onClose=()=>{}}:{busy?:boolean;onClose?:()=>void}) {
  const [open,setOpen]=useState(false)
  const [rename,setRename]=useState(false)
  const trigger=useRef<HTMLElement|null>(null)
  return <>
    <button onClick={event=>{
      trigger.current=event.currentTarget
      // Browsers blur a background trigger when its parent becomes inert.
      event.currentTarget.blur()
      setOpen(true)
    }}>Open</button>
    {open?<ModalSheet title="Project" closeLabel="Close" busy={busy}
      focusKey={rename?'rename':'actions'} restoreFocusTo={trigger.current}
      onClose={()=>{onClose();setOpen(false)}}>
      {rename?<input aria-label="Name" data-autofocus disabled={busy} />:null}
      <button disabled={busy} onClick={()=>setRename(true)}>Rename</button>
      <button disabled={busy}>Last action</button>
    </ModalSheet>:null}
  </>
}

describe('ModalSheet keyboard and focus lifecycle',()=>{
  it('covers the app and disables its tab bar while preserving screen scope and tokens',()=>{
    const {container}=render(<div className="ringify-app"><section className="screen v3-screen uf-library" style={{'--n-accent':'#7140f6'} as React.CSSProperties}><Harness /></section><nav aria-label="Main tabs"><button>Library tab</button></nav></div>)
    const app=container.querySelector('.ringify-app')!,owner=container.querySelector('.screen')!,tabs=container.querySelector('nav')!
    const opener=screen.getByRole('button',{name:'Open'})
    fireEvent.click(opener)
    const dialog=screen.getByRole('dialog'),host=dialog.closest('[data-modal-host]') as HTMLElement
    expect(host.parentElement).toBe(app)
    expect(host).toHaveClass('uf-library','v3-screen')
    expect(host.style.display).toBe('contents')
    expect(host.style.getPropertyValue('--n-accent')).toBe('#7140f6')
    expect(dialog.parentElement).toHaveStyle({position:'absolute',inset:'0',zIndex:'60'})
    expect(owner).toHaveAttribute('inert')
    expect(tabs).toHaveAttribute('inert')
    expect(tabs).toHaveAttribute('aria-hidden','true')
    expect(screen.queryByRole('navigation')).not.toBeInTheDocument()
    fireEvent.keyDown(dialog,{key:'Escape'})
    expect(owner).not.toHaveAttribute('inert')
    expect(tabs).not.toHaveAttribute('inert')
    expect(tabs).not.toHaveAttribute('aria-hidden')
    expect(app.querySelector('[data-modal-host]')).toBeNull()
    expect(opener).toHaveFocus()
  })

  it('restores pre-existing accessibility attributes and removes the host on unmount',()=>{
    const {container,unmount}=render(<div className="ringify-app"><section><Harness /></section><aside inert aria-hidden="false">Inactive content</aside></div>)
    const background=container.querySelector('aside')!
    fireEvent.click(screen.getByRole('button',{name:'Open'}))
    expect(background).toHaveAttribute('aria-hidden','true')
    fireEvent.click(screen.getByRole('button',{name:'Close'}))
    expect(background).toHaveAttribute('inert')
    expect(background).toHaveAttribute('aria-hidden','false')
    fireEvent.click(screen.getByRole('button',{name:'Open'}))
    const app=container.querySelector('.ringify-app')!
    unmount()
    expect(app.querySelector('[data-modal-host]')).toBeNull()
    expect(background).toHaveAttribute('aria-hidden','false')
  })

  it('keeps an inline dialog usable when there is no app host',()=>{
    const {container}=render(<Harness />)
    fireEvent.click(screen.getByRole('button',{name:'Open'}))
    expect(container).toContainElement(screen.getByRole('dialog'))
    expect(container.querySelector('[data-modal-host]')).toBeNull()
    fireEvent.mouseDown(screen.getByRole('dialog').parentElement!)
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('focuses an enabled control and traps Tab in both directions',()=>{
    render(<Harness />)
    fireEvent.click(screen.getByRole('button',{name:'Open'}))
    const close=screen.getByRole('button',{name:'Close'})
    const last=screen.getByRole('button',{name:'Last action'})
    expect(close).toHaveFocus()
    fireEvent.keyDown(close,{key:'Tab',shiftKey:true})
    expect(last).toHaveFocus()
    fireEvent.keyDown(last,{key:'Tab'})
    expect(close).toHaveFocus()
  })

  it('restores the explicit trigger even after native inert has blurred it',()=>{
    const onClose=vi.fn()
    render(<Harness onClose={onClose} />)
    const trigger=screen.getByRole('button',{name:'Open'})
    trigger.focus()
    fireEvent.click(trigger)
    fireEvent.keyDown(screen.getByRole('dialog'),{key:'Escape'})
    expect(onClose).toHaveBeenCalledOnce()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(trigger).toHaveFocus()
  })

  it('prioritizes the rename input on a mode change and retains the original return target',()=>{
    render(<Harness />)
    const trigger=screen.getByRole('button',{name:'Open'})
    fireEvent.click(trigger)
    fireEvent.click(screen.getByRole('button',{name:'Rename'}))
    expect(screen.getByRole('textbox',{name:'Name'})).toHaveFocus()
    fireEvent.keyDown(document,{key:'Escape'})
    expect(trigger).toHaveFocus()
  })

  it('blocks dismissal while busy, traps an empty focus set and removes its key listener',()=>{
    const onClose=vi.fn()
    const view=render(<Harness busy onClose={onClose} />)
    fireEvent.click(screen.getByRole('button',{name:'Open'}))
    const dialog=screen.getByRole('dialog')
    fireEvent.keyDown(document,{key:'Tab'})
    expect(dialog).toHaveFocus()
    fireEvent.keyDown(document,{key:'Escape'})
    fireEvent.mouseDown(dialog.parentElement!)
    fireEvent.click(screen.getByRole('button',{name:'Close'}))
    expect(onClose).not.toHaveBeenCalled()
    expect(dialog).toHaveAttribute('aria-busy','true')
    view.unmount()
    const event=new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true})
    document.dispatchEvent(event)
    expect(event.defaultPrevented).toBe(false)
  })
})
