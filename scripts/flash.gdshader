shader_type canvas_item;
// 受击闪白：amount=1 时整体变白（modulate 只能变暗，做不了变白，所以用 shader）
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, vec3(1.0), amount), tex.a) * COLOR;
}
