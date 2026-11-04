import {readFile,writeFile,readdir,access} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join,resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'),target=join(root,'design/review/native-studio-before.json');
try{await access(target);throw Error('Preserve existing baseline')}catch(error){if(error.code!=='ENOENT')throw error}
async function walk(dir){return(await Promise.all((await readdir(join(root,dir),{withFileTypes:true})).filter(x=>!['node_modules','dist','.build','.swiftpm'].includes(x.name)).map(x=>x.isDirectory()?walk(dir+'/'+x.name):[dir+'/'+x.name]))).flat()}
const files=[...(await walk('ios/Ringify')),...(await walk('ios/RingifyTests')),...(await walk('preview/src')),...(await walk('packages/RingifyCore/Sources')),...(await walk('packages/RingifyCore/Tests')),'design/tokens.json','shared/pro-offering.json','ios/project.yml','preview/package.json','preview/package-lock.json'];
const hashes={},originals={};for(const p of files){const bytes=await readFile(join(root,p));hashes[p]=createHash('sha256').update(bytes).digest('hex');if(p.endsWith('.swift')&&p.startsWith('ios/Ringify/')&&(p.includes('/Screens/')||p.includes('/DesignSystem/')||p.endsWith('/RootView.swift')))originals[p]=bytes.toString('utf8')}
await writeFile(target,JSON.stringify({hashes,originals},null,2)+'\n');console.log(JSON.stringify({files:files.length,originals:Object.keys(originals).length}));
