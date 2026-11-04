import test from 'node:test';
import assert from 'node:assert/strict';
import {selectIOSSimulator} from './select-ios-simulator.mjs';
const oldID = '00000000-0000-0000-0000-000000000001';
const newID = '00000000-0000-0000-0000-000000000002';
const device = (udid, more = {}) => ({name: 'iPhone 17', isAvailable: true, state: 'Shutdown', udid, ...more});

test('selects newest available iOS rather than a booted older runtime', () => {
  assert.equal(selectIOSSimulator({devices: {
    'com.apple.CoreSimulator.SimRuntime.iOS-18-5': [device(oldID, {state: 'Booted'})],
    'com.apple.CoreSimulator.SimRuntime.iOS-26-5': [device(newID)]
  }}), newID);
});
test('ignores non-iPhone, unavailable, non-iOS and malformed identifiers', () => {
  assert.equal(selectIOSSimulator({devices: {
    'com.apple.CoreSimulator.SimRuntime.tvOS-99-0': [device(oldID)],
    'com.apple.CoreSimulator.SimRuntime.iOS-26-5': [device(oldID, {isAvailable: false}),
      device(oldID, {name: 'iPad Pro'}), device('not-a-uuid'), device(newID)]
  }}), newID);
});
test('reuses booted iPhone within the newest runtime', () => {
  assert.equal(selectIOSSimulator({devices: {
    'com.apple.CoreSimulator.SimRuntime.iOS-26-5': [device(oldID), device(newID, {state: 'Booted'})]
  }}), newID);
});
test('fails clearly when the device list is invalid or empty', () => {
  for (const payload of [null, {}, {devices: null}, {devices: []}, {devices: {}}]) {
    assert.throws(() => selectIOSSimulator(payload));
  }
});

test('honors an explicit runtime even when a newer iPhone is booted',()=>{
  const devices={'com.apple.CoreSimulator.SimRuntime.iOS-26-2':[device(oldID)],'com.apple.CoreSimulator.SimRuntime.iOS-26-5':[device(newID,{state:'Booted'})]};
  assert.equal(selectIOSSimulator({devices},'26.2'),oldID);
});

test('fails instead of silently substituting an unavailable or malformed requested runtime',()=>{
  const payload={devices:{'com.apple.CoreSimulator.SimRuntime.iOS-26-5':[device(newID)]}};
  assert.throws(()=>selectIOSSimulator(payload,'26.2'),/for iOS 26.2/);
  for(const value of ['', 'latest', '26.2;echo', '26'])assert.throws(()=>selectIOSSimulator(payload,value),/Invalid requested/);
});

test('selects the latest available patch within a requested major/minor',()=>{
  const devices={'com.apple.CoreSimulator.SimRuntime.iOS-26-2':[device(oldID)],'com.apple.CoreSimulator.SimRuntime.iOS-26-2-1':[device(newID)]};
  assert.equal(selectIOSSimulator({devices},'26.2'),newID);
  assert.equal(selectIOSSimulator({devices},'26.2.0'),oldID);
});
