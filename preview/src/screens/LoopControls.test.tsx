import {afterEach,it,expect,vi} from 'vitest'
import {cleanup,render,screen,fireEvent} from '@testing-library/react'
import {EffectsScreen} from './LegacyFinishingScreens'
import type {EditorState} from '../types'
afterEach(cleanup)
it('exposes a real free loop setting without granting advanced effects or normalize access',()=>{
  const editor:EditorState={projectName:'Tone',projectID:'one',trimStart:0,trimEnd:3,
    asset:{fileName:'tone.wav',duration:3,peaks:[.1,.2],buffer:null,isDemo:false},effects:{volume:1,fadeIn:0,fadeOut:0,normalize:false}}
  const onChange=vi.fn(),onRequirePro=vi.fn()
  render(<EffectsScreen language="en" editor={editor} onChange={onChange} onBack={vi.fn()} onContinue={vi.fn()}
    canNormalize={false} canAdvancedEffects={false} onRequirePro={onRequirePro}/>)
  fireEvent.click(screen.getByRole('switch',{name:'Smooth loop'}))
  expect(onChange).toHaveBeenCalledWith(expect.objectContaining({effects:expect.objectContaining({loopCrossfade:.03,normalize:false})}))
  expect(onRequirePro).not.toHaveBeenCalled()
})
