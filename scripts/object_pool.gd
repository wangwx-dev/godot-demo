class_name ObjectPool
extends Node
## 通用对象池（enemy-design：掉落经验球用对象池）。
## 使用方负责在 acquire 后初始化、用完调 release——池只管生命周期不管状态。

@export var scene: PackedScene

var _free_nodes: Array[Node] = []


func acquire() -> Node:
	if _free_nodes.is_empty():
		var node: Node = scene.instantiate()
		add_child(node)
		return node
	return _free_nodes.pop_back()


func release(node: Node) -> void:
	_free_nodes.append(node)
