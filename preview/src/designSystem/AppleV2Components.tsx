import type {ReactNode} from 'react'
import {ChevronRight,FileAudio,Music2} from 'lucide-react'
import type {Language,ProjectSummary} from '../types'
import {formatDate} from '../lib/format'
import {formatStudioTime} from './tokens'

export function GroupedSection({title,action,children,className=''}:{title:string;action?:ReactNode;children:ReactNode;className?:string}){
  return <section className={`n3-section ${className}`} aria-label={title}><div className="n3-section-heading"><h2>{title}</h2>{action}</div>{children}</section>
}

export function ProjectListRow({project,language,onOpen}:{project:ProjectSummary;language:Language;onOpen:()=>void}){
  const isTr=language==='tr',ready=project.status==='exported'
  return <button type="button" className="n3-project r-project" onClick={onOpen}>
    <span className={`n3-file-art ${ready?'is-exported':''}`} aria-hidden="true">{ready?<Music2 size={23}/>:<FileAudio size={23}/>}</span>
    <span className="n3-project-copy"><strong>{project.name}</strong><small>{formatStudioTime(project.duration)} · {ready?(isTr?'Zil sesi':'Ringtone'):(isTr?'Taslak':'Draft')} · {formatDate(project.updatedAt,isTr?'tr-TR':'en-US')}</small></span>
    <ChevronRight size={18} className="n3-chevron" aria-hidden="true"/>
  </button>
}
