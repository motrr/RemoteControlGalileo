attribute mediump vec4 position;
attribute mediump vec4 texCoord;

varying mediump vec2 coordinate;

void main()
{
	gl_Position = position;
	coordinate = texCoord.xy;
}