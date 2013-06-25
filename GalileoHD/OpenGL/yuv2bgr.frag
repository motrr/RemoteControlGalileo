precision mediump float;

uniform sampler2D yPlane;
uniform sampler2D uPlane;
uniform sampler2D vPlane;

varying highp vec2 coordinate;

void main()
{
	float y = texture2D(yPlane, coordinate).r;
	float u = texture2D(uPlane, coordinate).r;
	float v = texture2D(vPlane, coordinate).r;
    
	y = 1.16438355 * (y - 0.0625);
	u = u - 0.5;
	v = v - 0.5;
    
	float r = clamp(y + 1.596 * v, 0.0, 1.0);
	float g = clamp(y - 0.391 * u - 0.813 * v, 0.0, 1.0);
	float b = clamp(y + 2.018 * u, 0.0, 1.0);
    
	gl_FragColor = vec4(b, g, r, 1.0);
	//gl_FragColor = vec4(y, y, y, 1.0);
}
