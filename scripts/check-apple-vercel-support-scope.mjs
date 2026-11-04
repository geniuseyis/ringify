import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..'),read=p=>readFile(join(root,p),'utf8');
const before=JSON.parse(await read('design/review/apple-vercel-support-source-before.json')),report={checks:[]};
const check=(name,pass,evidence)=>report.checks.push({name,passed:!!pass,evidence});
const mismatches=[];for(const [p,hash] of Object.entries(before.hashes))if(createHash('sha256').update(await readFile(join(root,p))).digest('hex')!==hash)mismatches.push(p);
check('Audio/data/tests/native/prior screens/App/tokens/prices/headers/modals unchanged',!mismatches.length,{files:Object.keys(before.hashes).length,mismatches});
for(const [p,original] of Object.entries(before.originals)){
 const value=await read(p);
 if(p.endsWith('.css'))check('Prior design CSS preserved',value.startsWith(original));
 else check(p+' only adds presentation scope',value.replaceAll(' av-screen av-support av-settings','').replaceAll(' av-screen av-support av-help','')===original);
}
const git=args=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();check('Published 50 commits and HEAD preserved',git(['rev-list','--count','HEAD'])==='50'&&git(['rev-parse','HEAD'])==='9490d02071aa3be0add4821717f7b0b515bffa38');
await writeFile(join(root,'design/review/apple-vercel-support-scope.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(report.checks.some(r=>!r.passed))process.exitCode=1;
