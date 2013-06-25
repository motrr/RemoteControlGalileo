attribute highp vec4 position;
attribute highp vec4 textureCoordinate;

varying highp vec2 coordinate;

void main()
{
	gl_Position = position;
	coordinate = textureCoordinate.xy;
}