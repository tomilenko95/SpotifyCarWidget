import json
import subprocess
import sys

devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))['devices']
for runtime, values in sorted(devices.items(), reverse=True):
    if 'iOS-' not in runtime:
        continue
    major = int(runtime.split('iOS-')[1].split('-')[0])
    if major < 26:
        continue
    for device in values:
        if device['name'].startswith('iPhone') and device.get('isAvailable'):
            print(device['udid'])
            sys.exit(0)
sys.exit('Install an iOS 26+ iPhone simulator runtime in the selected Xcode image.')
