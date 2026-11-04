import {afterEach,describe,it,expect,vi} from 'vitest'
import {cleanup,render,screen,waitFor} from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import {PersonalPresetsPanel} from './PersonalPresetsPanel'
import type {EditorState} from '../types'
import type {UserAudioPreset} from '../lib/userAudioPresets'
afterEach(cleanup)

const saved=():UserAudioPreset=>({id:'preset',name:'Voice',createdAt:'2026-11-02T10:00:00Z',updatedAt:'2026-11-02T10:00:00Z',effects:{volume:.6,fadeIn:4,fadeOut:3,normalize:false}})
const editor=():EditorState=>({projectID:'one',projectName:'Tone',trimStart:0,trimEnd:1,effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false},
  asset:{fileName:'source.wav',duration:2,peaks:[],buffer:{sampleRate:48000} as AudioBuffer,isDemo:false}})
function setup(preset=saved()){
  const repository={listAudioPresets:vi.fn().mockResolvedValue([preset]),saveAudioPreset:vi.fn().mockResolvedValue(undefined),deleteAudioPreset:vi.fn().mockResolvedValue(undefined)}
  const onChange=vi.fn(),onRequirePro=vi.fn()
  render(<PersonalPresetsPanel editor={editor()} language="en" onChange={onChange} onRequirePro={onRequirePro} canNormalize={false} canAdvancedEffects={false} repository={repository}/>)
  return {repository,onChange,onRequirePro,user:userEvent.setup()}
}
describe('personal preset controls',()=>{
  it('applies real saved settings through the editor with selection-safe fades',async()=>{
    const {user,onChange}=setup()
    await user.click(screen.getByText('Personal Audio Presets'))
    await user.click(await screen.findByRole('button',{name:'Voice'}))
    expect(onChange).toHaveBeenCalledWith(expect.objectContaining({effects:{volume:.6,fadeIn:.5,fadeOut:.5,normalize:false}}))
  })
  it('respects the existing normalize gate instead of granting Pro access',async()=>{
    const preset=saved();preset.effects.normalize=true
    const {user,onChange,onRequirePro}=setup(preset)
    await user.click(screen.getByText('Personal Audio Presets'))
    await user.click(await screen.findByRole('button',{name:'Voice'}))
    expect(onRequirePro).toHaveBeenCalledOnce();expect(onChange).not.toHaveBeenCalled()
  })
  it('keeps the typed name and existing presets when saving fails',async()=>{
    const {repository,user,onChange}=setup()
    repository.saveAudioPreset.mockRejectedValueOnce(new DOMException('Quota exceeded','QuotaExceededError'))
    await user.click(screen.getByText('Personal Audio Presets'))
    await user.type(screen.getByLabelText('Preset name'),'New voice')
    await user.click(screen.getByRole('button',{name:'Save Current Settings'}))
    await waitFor(()=>expect(screen.getByRole('alert')).toBeInTheDocument())
    expect(screen.getByLabelText('Preset name')).toHaveValue('New voice')
    expect(screen.getByRole('button',{name:'Voice'})).toBeInTheDocument()
    expect(onChange).not.toHaveBeenCalled()
  })
  it('requires explicit deletion confirmation and allows cancellation',async()=>{
    const {repository,user}=setup()
    await user.click(screen.getByText('Personal Audio Presets'))
    await user.click(await screen.findByRole('button',{name:'Voice · Delete'}))
    expect(screen.getByRole('group',{name:'Delete personal preset?'})).toBeInTheDocument()
    await user.click(screen.getByRole('button',{name:'Cancel'}))
    expect(repository.deleteAudioPreset).not.toHaveBeenCalled()
    expect(screen.queryByRole('group',{name:'Delete personal preset?'})).not.toBeInTheDocument()
  })
})
