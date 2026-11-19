class_name CivicModalInputGuard
extends RefCounted
## UI-002: presentation-only modal transitions. Main retains modal arbitration.

static func release_touch_controls(tree: SceneTree) -> void:
    if tree == null:
        return
    for node in tree.get_nodes_in_group("civic_touch_controls"):
        if is_instance_valid(node) and node.has_method("cancel_active_touches"):
            node.call("cancel_active_touches")

static func remember_focus(viewport: Viewport, modal: Control) -> WeakRef:
    if viewport == null:
        return null
    var focused: Control = viewport.gui_get_focus_owner()
    if focused == null or not is_instance_valid(focused):
        return null
    if is_inside(focused, modal):
        return null
    return weakref(focused)

static func is_inside(control: Control, ancestor: Control) -> bool:
    if control == null or ancestor == null:
        return false
    var cursor: Node = control
    while cursor != null:
        if cursor == ancestor:
            return true
        cursor = cursor.get_parent()
    return false

## Never steal focus from a different modal and never focus hidden controls.
static func restore_focus(viewport: Viewport, saved: WeakRef, closing_modal: Control) -> void:
    if viewport == null:
        return
    var current: Control = viewport.gui_get_focus_owner()
    if current != null and is_instance_valid(current):
        if not is_inside(current, closing_modal):
            return
        current.release_focus()
    if saved == null:
        return
    var target: Variant = saved.get_ref()
    if target is Control and is_instance_valid(target):
        var control: Control = target as Control
        if control.is_inside_tree() and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
            control.grab_focus()
