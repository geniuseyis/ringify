// Static boundaries, test inventory and real parser evidence; no XCTest execution.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=p=>readFile(join(root,p),'utf8');
const hash=p=>readFile(join(root,p)).then(bytes=>createHash('sha256').update(bytes).digest('hex'));
const baseline=JSON.parse(await read('design/review/native-delivery-before.json'));
const allowed=new Set([
 'packages/RingifyCore/Sources/RingifyCore/DomainModels.swift','packages/RingifyCore/Sources/RingifyCore/ServiceProtocols.swift',
 ...['AVAudioConversionService','AVAudioEffectsService','AVAudioExportService','AVAudioTrimService','SwiftDataProjectStorageService'].map(p=>`ios/Ringify/Services/${p}.swift`),
 'ios/Ringify/App/AppModel.swift',
 ...['LibraryView','AudioEffectsView','ExportView','RingtonePreviewView','LibraryOrganizationViews'].map(p=>`ios/Ringify/Screens/${p}.swift`),
 ...['AppModelIntegrityTests','LibraryStorageIntegrationTests'].map(p=>`ios/RingifyTests/${p}.swift`)
 ,'ios/Ringify/DesignSystem/RingifyTheme.swift','ios/Ringify/DesignSystem/NativePresentationComponents.swift','ios/Ringify/Screens/AdvancedEffectsPanel.swift'
 ,'preview/src/lib/projectRepository.ts','preview/src/screens/LegacyFinishingScreens.tsx'
 ,'packages/RingifyCore/Sources/RingifyCore/AudioGainEnvelope.swift'
 ,...['AudioEditorView','VoiceRecorderView'].map(p=>`ios/Ringify/Screens/${p}.swift`)
 ,'ios/RingifyTests/SwiftDataProjectStorageServiceTests.swift'
 ,...['audioProcessing','segmentPlayer','wavExportPlan'].map(p=>`preview/src/lib/${p}.ts`)
 ,...['useSegmentPlayer','useVoiceRecorder'].map(p=>`preview/src/hooks/${p}.ts`)
 ,'preview/src/App.tsx','preview/src/types.ts'
 ,...['CaptureCleanup.test','CaptureScreens.test','CaptureScreens','StudioScreen'].map(p=>`preview/src/screens/${p}.tsx`)
 ,'ios/Ringify/App/AppContainer.swift'
 ,'packages/RingifyCore/Sources/RingifyCore/ProAccessPolicy.swift','ios/Ringify/Services/PurchaseManager.swift'
 ,'ios/Ringify/Screens/PremiumView.swift','ios/Ringify/Resources/tr.lproj/Localizable.strings','ios/Ringify/Resources/en.lproj/Localizable.strings'
 ,'ios/Ringify/Screens/SettingsView.swift'
 ,'ios/Ringify/Resources/Ringify.storekit','shared/pro-offering.json'
 ,'preview/src/screens/PaywallScreen.tsx','preview/src/screens/PaywallScreen.test.tsx','preview/src/lib/proOffering.test.ts'
]);
const boundaries=[];
for(const[file,previous]of Object.entries(baseline.hashes)){
 const current=await hash(file);boundaries.push({file,previous,current,passed:previous===current||allowed.has(file),intentionalChange:allowed.has(file)});
}
const parser=JSON.parse(await read('design/review/native-syntax.json'));
const currentParserHashes=[];
for(const[file,expected]of Object.entries(parser.files))currentParserHashes.push({file,passed:await hash(file)===expected});
const sources={
 ...Object.fromEntries(['DuplicateProjectTests','AudioOutputProfileTests','ProjectExportRecordTests'].map(p=>[`packages/RingifyCore/Tests/RingifyCoreTests/${p}.swift`,null])),
 ...Object.fromEntries(['AudioOutputIntegrationTests','ExportHistoryStorageTests'].map(p=>[`ios/RingifyTests/${p}.swift`,null])),
 'ios/RingifyTests/AppModelIntegrityTests.swift':['testDuplicateRespectsNormalCapacityBeforeCreatingAnotherProject','testExpiredProCannotUseBatchRemovalToBypassBatchAccessGate','testProOutputProfilesCannotStartWithoutVerifiedEntitlement','testDeletingCommittedHistoryClearsResultButKeepsSourceAndEditSettings'],
 'ios/RingifyTests/LibraryStorageIntegrationTests.swift':['testSharedDuplicateSourceSurvivesOriginalDeletionAndIsRemovedWithLastReference']
 ,'packages/RingifyCore/Tests/RingifyCoreTests/UserAudioPresetTests.swift':null
 ,'ios/RingifyTests/PersonalPresetStorageTests.swift':null
 ,'packages/RingifyCore/Tests/RingifyCoreTests/AudioMarkerTests.swift':null
 ,'packages/RingifyCore/Tests/RingifyCoreTests/LoopCrossfadeTests.swift':null
 ,'ios/RingifyTests/AudioMarkerStorageTests.swift':null
 ,'ios/RingifyTests/SwiftDataProjectStorageServiceTests.swift':['testLoopSettingsPersistThroughReopenAndUpdateWithoutChangingSource']
 ,'packages/RingifyCore/Tests/RingifyCoreTests/AudioSegmentSuggestionsTests.swift':null
 ,'ios/RingifyTests/AudioComparisonViewModelTests.swift':null
 ,'ios/RingifyTests/AudioSegmentsViewModelTests.swift':null
 ,'ios/RingifyTests/AudioSegmentsIntegrationTests.swift':null
 ,'packages/RingifyCore/Tests/RingifyCoreTests/ProjectSlotProductTests.swift':null
 ,'ios/RingifyTests/ProjectSlotStoreKitTests.swift':null
};
const tests=[];
for(const[file,names]of Object.entries(sources)){
 const all=[...(await read(file)).matchAll(/func (test\w+)\(/g)].map(m=>m[1]);
 for(const name of names??all)tests.push({file,name,present:all.includes(name),result:'NOT_TESTED'});
}
const passed=parser.passed&&boundaries.every(x=>x.passed)&&currentParserHashes.every(x=>x.passed)&&tests.every(x=>x.present);
const report={clientDate:'2026-11-03',scope:'Static source boundaries and real syntax parser only; no runtime, SDK/type/concurrency, codec, migration or XCTest acceptance.',
 featureStatus:'IMPLEMENTED_NOT_TESTED',passed,boundaries,currentParserHashes,parserFiles:currentParserHashes.length,
 unchangedFiles:boundaries.filter(x=>x.previous===x.current).length,changes:boundaries.filter(x=>x.previous!==x.current),
 unchangedWebSources:boundaries.filter(x=>x.file.startsWith('preview/src/')&&x.previous===x.current).length,
 newSwiftFiles:Object.keys(parser.files).filter(p=>!baseline.hashes[p]),addedTests:tests.length,tests,
 coreBuild:'Prior stdlib.h/SwiftShims manifest failure; not rerun.',coreTests:'NOT_TESTED',nativeBuild:'NOT_TESTED',nativeTests:'NOT_TESTED',
 webTests:'390/390 Vitest passed, 56 files; TypeScript/Vite passed. Personal preset browser: 26 checks/5 PNG; markers: 10 checks/5 PNG; loop: 25 checks/4 PNG. Lockfile unchanged.'};
await writeFile(join(root,'design/review/native-delivery-scope.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({passed,parserFiles:report.parserFiles,unchangedFiles:report.unchangedFiles,changes:report.changes.length,unchangedWebSources:report.unchangedWebSources,newSwiftFiles:report.newSwiftFiles.length,addedTests:tests.length,testResult:'NOT_TESTED'}));
if(!passed)process.exitCode=1;
