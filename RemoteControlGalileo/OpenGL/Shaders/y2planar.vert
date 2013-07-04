attribute highp vec4 position;
attribute highp vec4 texCoord;

varying highp vec2 coordinate;

void main()
{
	gl_Position = position;
	coordinate = texCoord.xy;
}