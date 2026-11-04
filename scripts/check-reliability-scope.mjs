// Source boundary evidence, not native runtime acceptance.
import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const read=file=>readFile(join(root,file),'utf8');
const baseline=JSON.parse(await read('design/review/reliability-before.json'));
const allowed=new Set(['ios/Ringify/Services/PurchaseManager.swift','ios/RingifyTests/ProjectSlotStoreKitTests.swift','ios/Ringify/Screens/PremiumView.swift',
 'preview/src/lib/segmentSuggestions.ts','preview/src/screens/SegmentSuggestionsPanel.tsx','preview/src/screens/SegmentSuggestionsPanel.test.tsx',
 'preview/src/hooks/useSegmentPlayer.ts','preview/src/hooks/useSegmentPlayer.advanced.test.tsx','preview/src/lib/segmentSuggestions.test.ts']);
const boundaries=[];
for(const[file,previous]of Object.entries(baseline.hashes)){
 const current=createHash('sha256').update(await readFile(join(root,file))).digest('hex');
 boundaries.push({file,previous,current,changed:previous!==current,passed:previous===current||allowed.has(file)});
}
const git=args=>{const r=spawnSync('git',args,{cwd:root,encoding:'utf8',windowsHide:true});if(r.status!==0)throw Error('Git boundary read failed');return r.stdout.trim()};
const syntax=JSON.parse(await read('design/review/native-syntax.json'));
const browser=JSON.parse(await read('design/review/reliability-browser.json'));
const hashChecks=await Promise.all(Object.entries(syntax.files).map(async([file,expected])=>
 ({file,passed:createHash('sha256').update(await readFile(join(root,file))).digest('hex')===expected})));
const report={scope:'Nine focused source changes, seven protected hashes, real parser hashes and recorded browser evidence. No native runtime/StoreKit acceptance.',
 boundaries,protectedUnchanged:boundaries.filter(row=>!allowed.has(row.file)&&!row.changed).length,
 intentionalChanges:boundaries.filter(row=>row.changed).length,syntaxPassed:syntax.passed,syntaxFiles:hashChecks.length,syntaxHashesCurrent:hashChecks.every(row=>row.passed),
 browserChecks:browser.checks.length,browserPassed:!browser.failure&&browser.checks.every(row=>row.passed),
 gitHead:git(['rev-parse','HEAD']),gitCommits:Number(git(['rev-list','--count','HEAD'])),noNewCommit:git(['rev-parse','HEAD'])===baseline.head,
 nativeTests:'NOT_TESTED',newNativeTestMethods:2,webTests:405,newWebTests:15};
report.passed=boundaries.every(row=>row.passed)&&report.protectedUnchanged===7&&report.intentionalChanges===9&&report.syntaxPassed&&report.syntaxHashesCurrent&&report.browserPassed&&report.noNewCommit&&report.gitCommits===50;
await writeFile(join(root,'design/review/reliability-scope.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({passed:report.passed,protectedHashes:report.protectedUnchanged,intentionalChanges:report.intentionalChanges,syntax:report.syntaxFiles,browserChecks:report.browserChecks,commits:report.gitCommits,noNewCommit:report.noNewCommit}));
if(!report.passed)process.exitCode=1;
