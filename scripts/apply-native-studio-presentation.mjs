import {readFile,writeFile} from 'node:fs/promises';
import {join,resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const names=['HomeView','AudioEditorView','VoiceRecorderView','AudioEffectsView','RingtonePreviewView','ExportView','RingtoneGuideView','ImportSourceView','PremiumView','SettingsView','HelpAndErrorStatesView','AudioConversionView'];
const edits=[];
for(const name of names){const path=`ios/Ringify/Screens/${name}.swift`,original=await readFile(join(root,path),'utf8');let value=original;
 if(value.includes('.ringifyStudioAppearance()'))throw Error('Already migrated: '+name);
 value=value.replaceAll('RingifyTheme.AppleV2.','RingifyTheme.Studio.').replaceAll('RingifyTheme.pageBackground','RingifyTheme.Studio.background').replaceAll('RingifyTheme.elevatedSurface','RingifyTheme.Studio.raised').replaceAll('RingifyTheme.surface','RingifyTheme.Studio.surface').replaceAll('RingifyTheme.accent','RingifyTheme.Studio.accent');
 value=value.replaceAll('.navigationTitle(','.ringifyStudioAppearance()\n        .navigationTitle(');
 if(!value.includes('.ringifyStudioAppearance()'))throw Error('Missing root navigation anchor: '+name);
 edits.push({path,original,value});
}
for(const {path,value} of edits)await writeFile(join(root,path),value);
console.log('Presentation roles migrated in '+edits.length+' screen sources. Actions, bindings and services are unchanged.');
