#!/bin/bash
# Sets up the upload point on this Mac: "My brain" in Finder's right-click menu (select files or folders,
# right-click, Quick Actions, then My brain), as Send to, My brain is on a Windows PC. It's a Quick Action,
# ~/Library/Services/My brain.workflow, that runs upload-point.sh from this folder in the brain's copy, so a
# change to it reaches the Mac with the next sync. No password needed, and safe to run again. The kit's
# installer runs it after putting the brain on the Mac; otherwise:
#   bash ~/AI-Brain-Link/<repo name>/skills/upload-point/setup-upload-point.sh
# It prints one line, and exits 1 if it couldn't. How the upload point works: SKILL.md in this folder.
# macOS's own bash 3.2, and the Python 3 that comes with Apple's command line tools.

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
script="$here/upload-point.sh"
workflow="$HOME/Library/Services/My brain.workflow"
fail() { echo "The upload point isn't set up: $1"; exit 1; }
[ -f "$script" ] || fail "upload-point.sh isn't next to this script, in $here"
python3 -c 'import plistlib' 2>/dev/null || fail "Python 3 doesn't run (it comes with Apple's command line tools)"

python3 - "$workflow" "$script" <<'PY' || fail "couldn't write $workflow"
import os, plistlib, shlex, shutil, sys, uuid
workflow, script = sys.argv[1], sys.argv[2]
command = "/bin/bash " + shlex.quote(script) + ' "$@"'
info = {"NSServices": [{
    "NSBackgroundColorName": "background",
    "NSIconName": "NSActionTemplate",
    "NSMenuItem": {"default": "My brain"},
    "NSMessage": "runWorkflowAsService",
    "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
    "NSSendFileTypes": ["public.item"],
}]}
def u():
    return str(uuid.uuid4()).upper()
def arg(name, default, n):
    return {"default value": default, "name": name, "required": "0", "type": "0", "uuid": str(n)}
action = {
    "AMAccepts": {"Container": "List", "Optional": True, "Types": ["com.apple.cocoa.string"]},
    "AMActionVersion": "2.0.3",
    "AMApplication": ["Automator"],
    "AMParameterProperties": {k: {} for k in ("COMMAND_STRING", "CheckedForUserDefaultShell", "inputMethod", "shell", "source")},
    "AMProvides": {"Container": "List", "Types": ["com.apple.cocoa.string"]},
    "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
    "ActionName": "Run Shell Script",
    # inputMethod 1: the selected items come in as arguments, "$@".
    "ActionParameters": {"COMMAND_STRING": command, "CheckedForUserDefaultShell": True, "inputMethod": 1,
                         "shell": "/bin/bash", "source": ""},
    "BundleIdentifier": "com.apple.RunShellScript",
    "CFBundleVersion": "2.0.3",
    "CanShowSelectedItemsWhenRun": False,
    "CanShowWhenRun": True,
    "Category": ["AMCategoryUtilities"],
    "Class Name": "RunShellScriptAction",
    "InputUUID": u(),
    "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
    "OutputUUID": u(),
    "UUID": u(),
    "UnlocalizedApplications": ["Automator"],
    "arguments": {"0": arg("inputMethod", 0, 0), "1": arg("CheckedForUserDefaultShell", False, 1),
                  "2": arg("source", "", 2), "3": arg("COMMAND_STRING", "", 3), "4": arg("shell", "/bin/sh", 4)},
    "isViewVisible": 1,
    "location": "309.000000:253.000000",
    "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
}
document = {
    "AMApplicationBuild": "523",
    "AMApplicationVersion": "2.10",
    "AMDocumentVersion": "2",
    "actions": [{"action": action, "isViewVisible": 1}],
    "connectors": {},
    "workflowMetaData": {
        "applicationBundleIDsByPath": {},
        "applicationPaths": [],
        "inputTypeIdentifier": "com.apple.Automator.fileSystemObject",
        "outputTypeIdentifier": "com.apple.Automator.nothing",
        "presentationMode": 15,
        "processesInput": False,
        "serviceApplicationBundleID": "com.apple.finder",
        "serviceApplicationPath": "/System/Library/CoreServices/Finder.app",
        "serviceInputTypeIdentifier": "com.apple.Automator.fileSystemObject",
        "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceProcessesInput": False,
        "systemImageName": "NSActionTemplate",
        "useAutomaticInputType": False,
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    },
}
if os.path.isdir(workflow):
    shutil.rmtree(workflow)
os.makedirs(os.path.join(workflow, "Contents"))
with open(os.path.join(workflow, "Contents", "Info.plist"), "wb") as f:
    plistlib.dump(info, f)
with open(os.path.join(workflow, "Contents", "document.wflow"), "wb") as f:
    plistlib.dump(document, f)
PY
# So Finder lists it now, not after the next login.
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1
echo 'Upload point ready: right-click files or folders in Finder, then Quick Actions, My brain.'
exit 0
