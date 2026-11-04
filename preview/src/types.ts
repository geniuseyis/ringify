export type ScreenId =
  | 'splash'
  | 'onboarding'
  | 'home'
  | 'studio'
  | 'import'
  | 'conversion'
  | 'recorder'
  | 'editor'
  | 'effects'
  | 'ringtonePreview'
  | 'export'
  | 'guide'
  | 'library'
  | 'premium'
  | 'settings'
  | 'help'

export type ThemePreference = 'system' | 'light' | 'dark'
export type Language = 'tr' | 'en'

export interface ProjectSummary {
  favorite?:boolean
  collectionIDs?:string[]
  id: string
  name: string
  sourceName: string
  duration: number
  trimStart: number
  trimEnd: number
  updatedAt: string
  status: 'draft' | 'exported'
  isDemo?: boolean
}

export interface StudioEffects {
  low:number;mid:number;high:number;highPass:number;lowPass:number
  channels:'original'|'mono'|'stereo';limiter:boolean;ceiling:number
}
export interface AudioEffects {
  loopCrossfade?: number
  volume: number
  fadeIn: number
  fadeOut: number
  normalize: boolean
  studio?:StudioEffects
}

export interface AudioAsset {
  fileName: string
  duration: number
  peaks: number[]
  buffer: AudioBuffer | null
  sourceBlob?: Blob
  isDemo: boolean
}

export interface AudioMarker {id:string;time:number;label:string}
export interface EditorState {
  markers?: AudioMarker[]
  projectID?: string
  asset: AudioAsset
  trimStart: number
  trimEnd: number
  effects: AudioEffects
  projectName: string
}

export interface AppSettings {
  theme: ThemePreference
  language: Language
  exportFormat: 'wav-demo' | 'm4a-ios'
  onboardingSeen: boolean
  isProDemo: boolean
}

export interface ToastMessage {
  id: number
  message: string
  tone?: 'neutral' | 'success' | 'error'
}
