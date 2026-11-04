import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..'),read=p=>readFile(join(root,p),'utf8');
const before=JSON.parse(await read('design/review/library-reference-source-before.json')),report={checks:[]};
const check=(name,pass,evidence)=>report.checks.push({name,passed:!!pass,evidence});
const changedTests=['preview/src/App.studioNavigation.test.tsx','preview/src/screens/LibraryScreens.test.tsx','preview/src/screens/ManagementScreens.test.tsx','preview/src/screens/LibraryTools.test.tsx'];
const mismatches=[];let count=0;for(const [p,hash] of Object.entries(before.hashes)){if(changedTests.includes(p))continue;count++;if(createHash('sha256').update(await readFile(join(root,p))).digest('hex')!==hash)mismatches.push(p)}
check('All other screens, audio/data/native/tokens/prices/dependencies preserve bytes',!mismatches.length,{files:count,mismatches});
check('Prior CSS is unchanged', (await read('preview/src/designSystem/appleVercel.css')).startsWith(before.originals['preview/src/designSystem/appleVercel.css']));
const body=text=>text.slice(text.indexOf('export function LibraryScreen'),text.indexOf('  return <'));
check('Library state/filtering/save/delete logic is unchanged',body(await read('preview/src/screens/ManagementScreens.tsx'))===body(before.originals['preview/src/screens/ManagementScreens.tsx']));
const testBefore={...before.originals,
 'preview/src/App.studioNavigation.test.tsx':await read('design/review/library-reference-App-test-original.txt'),
 'preview/src/screens/LibraryScreens.test.tsx':await read('design/review/library-reference-Library-test-original.txt')};
for(const p of changedTests){const pattern=/\b(?:it|test)\s*\(/g;check(p+' retains all test cases',(await read(p)).match(pattern)?.length===testBefore[p].match(pattern)?.length)}
const git=args=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();check('Published 50 commits and HEAD preserved',git(['rev-list','--count','HEAD'])==='50'&&git(['rev-parse','HEAD'])==='9490d02071aa3be0add4821717f7b0b515bffa38');
await writeFile(join(root,'design/review/library-reference-scope.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(report.checks.some(r=>!r.passed))process.exitCode=1;
