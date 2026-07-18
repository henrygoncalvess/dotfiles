#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    pixColor.b *= 0.7; // reduz o azul
    fragColor = pixColor;
}
