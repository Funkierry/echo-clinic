shader_type canvas_item;
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float phase = 0.0;
uniform vec2 pointer = vec2(0.5);
uniform vec4 accent : source_color = vec4(0.43, 0.91, 0.79, 1.0);
void fragment() {
    vec2 uv = UV;
    float sweep = pow(max(0.0, 1.0 - abs(fract(uv.x * 0.46 + uv.y * 0.24 - TIME * 0.12 + phase) - 0.5) * 6.0), 3.0);
    float bands = sin((uv.x + uv.y) * 42.0 + TIME + phase * 5.0) * 0.5 + 0.5;
    vec3 rainbow = 0.5 + 0.5 * cos(6.28318 * (uv.x * 0.45 + uv.y * 0.4 + TIME * 0.04 + vec3(0.0, 0.33, 0.67)));
    float grid = step(0.96, fract(uv.x * 26.0)) + step(0.96, fract(uv.y * 30.0));
    float edge = 1.0 - smoothstep(0.0, 0.09, min(min(uv.x, 1.0-uv.x), min(uv.y, 1.0-uv.y)));
    vec3 col = mix(accent.rgb, rainbow, 0.34 + hover * 0.3);
    COLOR = vec4(col, (sweep * 0.11 + grid * 0.018 + edge * 0.045 + bands * 0.012) * (0.5 + hover));
}

