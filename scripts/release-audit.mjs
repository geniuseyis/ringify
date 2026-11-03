import {readFile,readdir,writeFile} from 'node:fs/promises';
import {join,resolve,relative} from 'node:path';
const root=resolve(import.meta.dirname,'..'),checks=[];
function check(name,passed,evidence){checks.push({name,passed:!!passed,evidence});}
const read=path=>readFile(join(root,path),'utf8');
const offering=JSON.parse(await read('shared/pro-offering.json')),store=JSON.parse(await read('ios/Ringify/Resources/Ringify.storekit'));
check('Approved prices and base quotas retained',offering.freeProjectLimit===1&&offering.proProjectLimit===3&&JSON.stringify(offering.plans.map(row=>row.priceMinor))==='[12499,34999,249999,449999]'&&offering.projectSlotOffering.priceMinor===4999);
check('Slots remain unavailable in preview and await native acceptance',offering.projectSlotOffering.purchaseStatus==='notAvailableInPreview'
 &&offering.projectSlotOffering.nativeStatus==='IMPLEMENTED_NOT_TESTED'&&offering.projectSlotOffering.maximumExtraSlots===20);
const slots=store.products.filter(product=>product.productID.startsWith(offering.projectSlotOffering.productIDPrefix));
check('Twenty distinct individually restorable slots: approved local prices/types',slots.length===20&&new Set(slots.map(x=>x.productID)).size===20
 &&slots.every(x=>x.type==='NonConsumable'&&x.displayPrice==='49.99'&&!x.familyShareable)
 &&Array.from({length:20},(_,i)=>offering.projectSlotOffering.productIDPrefix+String(i+1).padStart(2,'0')).every(id=>slots.some(x=>x.productID===id)));
check('StoreKit catalogue parses (not SDK verification)',!!store.identifier&&Array.isArray(store.products)&&Array.isArray(store.subscriptionGroups));
const locales=await Promise.all(['tr','en'].map(async language=>{
 const text=await read(`ios/Ringify/Resources/${language}.lproj/Localizable.strings`),keys=[...text.matchAll(/^"([^"]+)"\s*=/gm)].map(row=>row[1]);
 check(language+' locale has no duplicate keys',new Set(keys).size===keys.length,{keys:keys.length});
 check(language+' locale includes Studio/trim accessibility labels',['tab.studio','editor.zoom','editor.trimStart','editor.trimEnd'].every(key=>keys.includes(key)));
 return keys;
}));
check('TR/EN localization keys agree',JSON.stringify([...locales[0]].sort())===JSON.stringify([...locales[1]].sort()));
const navigation=await read('ios/Ringify/App/RootView.swift');check('Four native tabs are present in source',['home','studio','library','settings'].every(tab=>navigation.includes(`.tag(AppTab.${tab})`)));
const project=await read('ios/project.yml'),icon=await readFile(join(root,'ios/Ringify/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'));
check('Icon is 1024px RGB and configured',icon.readUInt32BE(16)===1024&&icon.readUInt32BE(20)===1024&&icon[25]===2&&project.includes('ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon'));
async function files(path){const items=await readdir(path,{withFileTypes:true});const nested=await Promise.all(items.map(row=>row.isDirectory()?files(join(path,row.name)):Promise.resolve([join(path,row.name)])));return nested.flat();}
const paths=(await Promise.all(['ios/Ringify','packages/RingifyCore/Sources','preview/src'].map(path=>files(join(root,path))))).flat().filter(path=>/\.(swift|ts|tsx)$/.test(path)&&!path.includes('.test.'));
const rules=[/AKIA[0-9A-Z]{16}/,/-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/,/\bsk_live_[a-zA-Z0-9]{20,}/];
const suspects=[];for(const path of paths){const text=await readFile(path,'utf8');if(rules.some(rule=>rule.test(text)))suspects.push(relative(root,path));}
check('Limited known secret signature scan',suspects.length===0,{scannedFiles:paths.length,suspectFiles:suspects});
const coreFiles=paths.filter(path=>path.includes('RingifyCore')&&path.endsWith('.swift'));const imports=await Promise.all(coreFiles.map(path=>readFile(path,'utf8')));
check('Core has no Apple UI/media/persistence/payment imports',imports.every(text=>!/^import (SwiftUI|UIKit|AVFoundation|StoreKit|SwiftData)\b/m.test(text)));
check('No web demo entitlement grant',!(await read('preview/src/App.tsx')).includes('hasVerifiedPro=true'));
const report={scope:'Static source/configuration controls only. Not native compilation, runtime security or App Store acceptance.',checks,releaseReady:false,blocked:['Core manifest build: stdlib.h/SwiftShims toolchain headers','macOS/Xcode/device/StoreKit acceptance','Native DSP/Library/screen runtime and visual parity not accepted','Twenty permanent-slot products: App Store Connect setup and purchase/refund/restore acceptance','Published privacy/support URLs and App Store Connect metadata']};
await writeFile(join(root,'design/review/release-audit.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({checks:checks.length,passed:checks.filter(row=>row.passed).length,releaseReady:false}));
if(checks.some(row=>!row.passed))process.exitCode=1;
