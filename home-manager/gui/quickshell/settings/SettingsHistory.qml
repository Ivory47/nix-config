pragma Singleton

import QtQuick
import Quickshell

// Undo and redo for everything the settings app changes, one stack for all of it (Ctrl+Z undoes the
// last change, whichever page it was made on).
//
// How a store takes part (nothing else in the app needs to know about undo):
//  - once: `SettingsHistory.register(store, () => <its whole state>, state => <put it back and commit()>)`
//    (the state must be plain data: it is compared and kept as JSON);
//  - in its `commit()` (the call every change of the store already ends with): `SettingsHistory.committed(store)`;
//  - optionally a fourth function, `locate(from, to)`: what the step changed, as `{ catId, key }` for
//    SettingsView.jumpTo (the page's scrollTo knows what to open and outline), or null. After an undo or
//    redo the view then shows the setting that changed (`revealRequested`);
//  - when state arrives from outside (a file read, a migration): `SettingsHistory.rebase(store)`, so it is
//    not an undoable step.
// A step is one commit. Commits of one store less than `mergeMs` apart are one step (typing in a field,
// a slider's burst). A drag is a step too: preview() changes do not commit, so the step starts at the
// state before the drag.
Singleton {
    id: root

    readonly property int mergeMs: 600
    readonly property int limit: 100

    // The registered stores: [{ store, snapshot, restore, baseline }] (baseline: JSON of the state at the
    // last commit / rebase).
    property var stores: []
    // The steps: [{ entry, before, after }] (JSON strings); `redoSteps` the undone ones.
    property var undoSteps: []
    property var redoSteps: []
    property double lastAt: 0
    property bool applying: false

    // An undo or redo changed this setting: show it (SettingsView).
    signal revealRequested(string catId, string key)

    readonly property bool canUndo: undoSteps.length > 0
    readonly property bool canRedo: redoSteps.length > 0

    function entryOf(store) {
        return stores.find(e => e.store === store)
    }

    function register(store, snapshot, restore, locate) {
        stores = stores.filter(e => e.store !== store).concat([{
            store: store, snapshot: snapshot, restore: restore, locate: locate || null,
            baseline: JSON.stringify(snapshot())
        }])
    }

    // The state came from outside: the new starting point, not a step.
    function rebase(store) {
        const e = entryOf(store)
        if (e)
            e.baseline = JSON.stringify(e.snapshot())
    }

    // The store changed something and is about to write it.
    function committed(store) {
        const e = entryOf(store)
        if (!e || applying)
            return
        const now = JSON.stringify(e.snapshot())
        if (now === e.baseline)
            return
        const last = undoSteps[undoSteps.length - 1]
        const at = Date.now()
        if (last && last.entry === e && at - lastAt < mergeMs) {
            last.after = now
            // (Back to where the step began: nothing changed after all.)
            if (last.after === last.before)
                undoSteps = undoSteps.slice(0, -1)
        } else {
            undoSteps = undoSteps.concat([{ entry: e, before: e.baseline, after: now }]).slice(-limit)
        }
        redoSteps = []
        lastAt = at
        e.baseline = now
    }

    function apply(step, from, state) {
        applying = true
        step.entry.restore(JSON.parse(state))
        applying = false
        step.entry.baseline = state
        lastAt = 0
        const where = step.entry.locate ? step.entry.locate(JSON.parse(from), JSON.parse(state)) : null
        if (where)
            revealRequested(where.catId, where.key)
    }

    function undo() {
        const step = undoSteps[undoSteps.length - 1]
        if (!step)
            return
        undoSteps = undoSteps.slice(0, -1)
        redoSteps = redoSteps.concat([step])
        apply(step, step.after, step.before)
    }

    function redo() {
        const step = redoSteps[redoSteps.length - 1]
        if (!step)
            return
        redoSteps = redoSteps.slice(0, -1)
        undoSteps = undoSteps.concat([step])
        apply(step, step.before, step.after)
    }
}
