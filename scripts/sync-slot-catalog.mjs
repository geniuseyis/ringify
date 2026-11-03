// Local StoreKit test catalogue only. Does not contact App Store Connect.
import {readFile,writeFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {resolve,join} from 'node:path';
const root=resolve(import.meta.dirname,'..');
const offering=JSON.parse(await readFile(join(root,'shared/pro-offering.json'),'utf8')).projectSlotOffering;
if(offering.maximumExtraSlots!==20||offering.priceMinor!==4999||offering.productType!=='nonConsumablePerSlot')throw Error('Unexpected approved slot policy');
const file=join(root,'ios/Ringify/Resources/Ringify.storekit'),store=JSON.parse(await readFile(file,'utf8'));
for(let index=1;index<=20;index++){
 const productID=offering.productIDPrefix+String(index).padStart(2,'0');
 const existing=store.products.find(product=>product.productID===productID);
 if(existing){if(existing.type!=='NonConsumable'||existing.displayPrice!=='49.99')throw Error('Conflicting slot product');continue}
 store.products.push({displayPrice:'49.99',familyShareable:false,internalID:randomUUID().toUpperCase(),localizations:[
  {description:'Pro etkinken 1 kalıcı proje yuvası. Proje silinince yeniden kullanılabilir; aynı Apple hesabıyla geri yüklenir.',displayName:`Ringify — Ek Proje Yuvası ${index}`,locale:'tr_TR'},
  {description:'One permanent extra project slot while Pro is active. Reusable after project deletion and restorable with the same Apple account.',displayName:`Ringify — Extra Project Slot ${index}`,locale:'en_US'}
 ],productID,referenceName:`Ringify Extra Slot ${index}`,type:'NonConsumable'});
}
await writeFile(file,JSON.stringify(store,null,2)+'\n');
console.log(JSON.stringify({localSlotProducts:20,publishedToAppStore:false}));
