import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..'),read=p=>readFile(join(root,p),'utf8');const before=JSON.parse(await read('design/review/finishing-extras-source-before.json')),report={checks:[]};
const check=(name,passed,evidence)=>report.checks.push({name,passed:!!passed,evidence});const mismatches=[];
for(const [p,hash] of Object.entries(before.hashes))if(createHash('sha256').update(await readFile(join(root,p))).digest('hex')!==hash)mismatches.push(p);
check('Audio/data/native/prices/fixtures/Library/approved entry screens and tests unchanged',!mismatches.length,{files:Object.keys(before.hashes).length,mismatches});
for(const [p,original] of Object.entries(before.originals)){const value=await read(p);check(p+' scope is preserved',p.endsWith('.css')?value.startsWith(original):value.replace(' av-screen av-finish av-guide','').replace(' av-screen av-finish av-conversion','')===original)}
const git=args=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();check('Published 50 commits and HEAD unchanged',git(['rev-list','--count','HEAD'])==='50'&&git(['rev-parse','HEAD'])==='9490d02071aa3be0add4821717f7b0b515bffa38');await writeFile(join(root,'design/review/finishing-extras-scope.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(report.checks.some(x=>!x.passed))process.exitCode=1;
