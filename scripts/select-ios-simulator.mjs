import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

export function selectIOSSimulator(payload) {
  if (!payload || typeof payload.devices !== 'object' || payload.devices === null || Array.isArray(payload.devices)) {
    throw Error('simctl returned an invalid device list.');
  }
  const candidates = [];
  for (const [runtime, devices] of Object.entries(payload.devices)) {
    const version = runtime.match(/\.iOS-(\d+)-(\d+)(?:-(\d+))?$/);
    if (!version || !Array.isArray(devices)) continue;
    for (const device of devices) {
      if (device?.isAvailable !== true || typeof device.name !== 'string' || !device.name.startsWith('iPhone ')) continue;
      if (typeof device.udid !== 'string' || !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(device.udid)) continue;
      candidates.push({udid: device.udid, state: device.state, version: version.slice(1).map(part => Number(part ?? 0))});
    }
  }
  candidates.sort((a, b) => {
    for (let i = 0; i < 3; i++) { if (a.version[i] !== b.version[i]) return b.version[i] - a.version[i]; }
    if ((a.state === 'Booted') !== (b.state === 'Booted')) return a.state === 'Booted' ? -1 : 1;
    return a.udid.localeCompare(b.udid);
  });
  if (!candidates.length) throw Error('No available iPhone Simulator found; inspect artifacts/simulators.json.');
  return candidates[0].udid;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { console.log(selectIOSSimulator(JSON.parse(readFileSync(0, 'utf8')))); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
