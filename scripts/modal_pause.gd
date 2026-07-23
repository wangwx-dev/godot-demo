extends RefCounted
## 模态菜单共享暂停令牌：只要还有一个持有者，场景树就保持暂停。

const OWNER_GROUP: StringName = &"_modal_pause_owner"
const PREVIOUS_PAUSE_META: StringName = &"_modal_pause_previous_state"


static func acquire(owner: Node) -> void:
	if not owner.is_inside_tree():
		return
	var tree: SceneTree = owner.get_tree()
	if owner.is_in_group(OWNER_GROUP):
		tree.paused = true
		return
	if tree.get_nodes_in_group(OWNER_GROUP).is_empty():
		tree.root.set_meta(PREVIOUS_PAUSE_META, tree.paused)
	owner.add_to_group(OWNER_GROUP)
	tree.paused = true


static func release(owner: Node) -> void:
	if not owner.is_inside_tree() or not owner.is_in_group(OWNER_GROUP):
		return
	var tree: SceneTree = owner.get_tree()
	owner.remove_from_group(OWNER_GROUP)
	if not tree.get_nodes_in_group(OWNER_GROUP).is_empty():
		tree.paused = true
		return
	var previous: bool = bool(tree.root.get_meta(PREVIOUS_PAUSE_META, false))
	tree.root.remove_meta(PREVIOUS_PAUSE_META)
	tree.paused = previous
