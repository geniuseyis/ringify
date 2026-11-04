import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..'),read=p=>readFile(join(root,p),'utf8');
const before=JSON.parse(await read('design/review/apple-vercel-library-pro-source-before.json')),report={checks:[]};
const check=(name,pass,evidence)=>report.checks.push({name,passed:!!pass,evidence});
const mismatches=[];for(const [p,hash] of Object.entries(before.hashes))if(createHash('sha256').update(await readFile(join(root,p))).digest('hex')!==hash)mismatches.push(p);
check('Audio/data/tests/native/prior screens/App/tokens/prices/dependencies unchanged',!mismatches.length,{files:Object.keys(before.hashes).length,mismatches});
for(const [p,original] of Object.entries(before.originals)){
 const value=await read(p);
 if(p.endsWith('.css'))check('Prior design CSS preserved',value.startsWith(original));
 else check(p+' only adds presentation scope',value.replaceAll(' av-screen av-manage av-library','').replaceAll(' av-screen av-manage av-pro','')===original);
}
const catalog=JSON.parse(await read('shared/pro-offering.json'));check('Approved prices, quotas and 20 permanent extra slots preserved',catalog.freeProjectLimit===1&&catalog.proProjectLimit===3&&JSON.stringify(catalog.plans.map(p=>p.priceMinor))==='[12499,34999,249999,449999]'&&catalog.projectSlotOffering.priceMinor===4999&&catalog.projectSlotOffering.maximumExtraSlots===20&&catalog.projectSlotOffering.productType==='nonConsumablePerSlot');
const git=args=>execFileSync('git',args,{cwd:root,encoding:'utf8'}).trim();check('Published 50 commits and HEAD preserved',git(['rev-list','--count','HEAD'])==='50'&&git(['rev-parse','HEAD'])==='9490d02071aa3be0add4821717f7b0b515bffa38');
await writeFile(join(root,'design/review/apple-vercel-library-pro-scope.json'),JSON.stringify(report,null,2)+'\n');console.log(JSON.stringify(report));if(report.checks.some(r=>!r.passed))process.exitCode=1;
