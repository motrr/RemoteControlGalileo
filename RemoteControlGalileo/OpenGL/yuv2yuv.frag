precision mediump float;

uniform sampler2D yPlane;
uniform sampler2D uvPlane;

varying highp vec2 coordinate;

void main()
{
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0); 
	color.r = texture2D(yPlane, coordinate).r;
	color.gb = texture2D(uvPlane, coordinate).ra;
    
	gl_FragColor = color;
}
