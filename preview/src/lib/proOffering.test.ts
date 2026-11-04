import {describe,expect,it} from 'vitest'
import {annualSavings,billingDisclosure,comparisonFeatures,freeProjectLimit,planFor,price,proPlans,proProjectLimit,projectSlotOffering} from './proOffering'
import {canChangeNormalization,canCreateProject,ProjectLimitError} from './proAccess'

describe('Pro plan and Normal access policy',()=>{
  it('prices each reusable slot separately without claiming a working add-on purchase',()=>{
    expect(projectSlotOffering).toMatchObject({priceMinor:4999,slotsPerPurchase:1,payment:'oneTime',requiresActivePro:true,reusableAfterDeletion:true,
      purchaseStatus:'notAvailableInPreview',nativeStatus:'IMPLEMENTED_NOT_TESTED',productType:'nonConsumablePerSlot',maximumExtraSlots:20})
  })
  it('retains the existing lifetime identifier and three distinct subscription periods',()=>{
    expect(planFor('lifetime').productID).toBe('com.ringify.app.pro.lifetime')
    expect(proPlans.map(p=>p.period)).toEqual(['P1W','P1M','P1Y',null])
    expect(new Set(proPlans.map(p=>p.productID)).size).toBe(4)
    expect(proPlans.every(p=>Number.isSafeInteger(p.priceMinor)&&p.priceMinor>0)).toBe(true)
    expect(proPlans.map(p=>p.priceMinor)).toEqual([12499,34999,249999,449999])
  })
  it('computes the annual discount from twelve monthly charges, not a fictitious old price',()=>{
    expect(annualSavings()).toBe(40)
    expect(Math.round(planFor('yearly').priceMinor/12)).toBe(20833)
    expect(price(Math.round(planFor('yearly').priceMinor/12),'tr')).toBe('₺208,33')
    expect(billingDisclosure('lifetime','tr')).toContain('Otomatik yenileme yok')
    expect(billingDisclosure('monthly','en')).toContain('Renews automatically')
  })
  it('rejects invalid price inputs and never silently formats NaN as a charge',()=>{
    for(const n of [NaN,Infinity,-1])expect(()=>price(n,'tr')).toThrow(RangeError)
  })
  it('does not mark unimplemented Pro tools as available',()=>{
    expect(comparisonFeatures.filter(f=>f.status==='planned').every(f=>f.pro==='planned'&&f.normal==='no')).toBe(true)
    expect(comparisonFeatures.find(f=>f.id==='normalize')).toMatchObject({normal:'no',pro:'yes'})
    expect(comparisonFeatures.find(f=>f.id==='projects')).toMatchObject({normal:'1',pro:'3'})
  })
  it('limits only new projects to one Normal or three verified Pro records',()=>{
    expect(freeProjectLimit).toBe(1)
    expect(proProjectLimit).toBe(3)
    expect(canCreateProject(0,false)).toBe(true)
    expect(canCreateProject(1,false)).toBe(false)
    expect(canCreateProject(2,false)).toBe(false)
    expect(canCreateProject(3,false)).toBe(false)
    expect(canCreateProject(10,false)).toBe(false)
    expect(canCreateProject(0,true)).toBe(true)
    expect(canCreateProject(1,true)).toBe(true)
    expect(canCreateProject(2,true)).toBe(true)
    expect(canCreateProject(3,true)).toBe(false)
    expect(canCreateProject(100,true)).toBe(false)
    for(const n of [-1,NaN,Infinity,2.5,Number.MAX_SAFE_INTEGER+1]){
      expect(canCreateProject(n,true)).toBe(false)
      expect(canCreateProject(n,false)).toBe(false)
    }
  })
  it('describes the current plan limit without implying that existing projects will be removed',()=>{
    expect(new ProjectLimitError('tr').message).toContain('Normal planda 1 proje')
    const proError=new ProjectLimitError('tr',true)
    expect(proError.name).toBe('ProjectLimitError')
    expect(proError.message).toContain('3 proje sınırına ulaştın')
    expect(proError.message).toContain('ek proje yuvası')
    expect(proError.message).toContain('Mevcut projeler korunur')
    expect(new ProjectLimitError('en',true).message).toContain('3-project limit')
  })
  it('preserves prior normalization, permits turning it off, and requires Pro to enable it anew',()=>{
    expect(canChangeNormalization(true,true,false)).toBe(true)
    expect(canChangeNormalization(true,false,false)).toBe(true)
    expect(canChangeNormalization(false,true,false)).toBe(false)
    expect(canChangeNormalization(false,true,true)).toBe(true)
  })
})
