import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..'),read=path=>readFile(join(root,path),'utf8');
const before=JSON.parse(await read('design/review/apple-vercel-ingest-source-before.json'));
const report={checks:[]},check=(name,pass,evidence)=>report.checks.push({name,passed:!!pass,evidence});
const mismatches=[];for(const [path,hash] of Object.entries(before.hashes)){if(createHash('sha256').update(await readFile(join(root,path))).digest('hex')!==hash)mismatches.push(path)}
check('Protected audio/data/hooks/tests/native/Home/Studio/App/tokens/dependencies preserve bytes',!mismatches.length,{files:Object.keys(before.hashes).length,mismatches});
const capture=(await read('preview/src/screens/CaptureScreens.tsx')).replace(' av-screen av-capture av-import','').replace(' av-screen av-capture av-recorder','');
check('Capture screens only add scoped root classes',capture===before.captureOriginal);
const css=await read('preview/src/designSystem/appleVercel.css');check('Prior Home/Studio CSS is preserved unchanged',css.startsWith(before.cssOriginal));
const git=args=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();
check('No new commits or history change',git(['rev-list','--count','HEAD'])==='50'&&git(['rev-parse','HEAD'])==='9490d02071aa3be0add4821717f7b0b515bffa38');
check('Capture has no visual random meter',!css.slice(before.cssOriginal.length).includes('@keyframes'));
await writeFile(join(root,'design/review/apple-vercel-ingest-scope.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(report.checks.some(row=>!row.passed))process.exitCode=1;
