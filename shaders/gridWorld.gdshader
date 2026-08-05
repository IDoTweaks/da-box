shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 baseColor : source_color = vec3(.87,.88,.9);
uniform vec3 lineColor : source_color = vec3(.45,.48,.55);
uniform vec3 majorColor : source_color = vec3(.14,.16,.22);
uniform float cellSize = 2.0;
uniform float majorEvery = 8.0;
uniform float lineWidth = 1.1;
uniform float majorWidth = 2.0;
uniform float lineStrength : hint_range(0.,1.) = .55;
uniform float majorStrength : hint_range(0.,1.) = .8;
uniform float fadeStart = 70.0;
uniform float fadeEnd = 260.0;
uniform float surfaceRoughness : hint_range(0.,1.) = .4;
uniform float heightTint = 0.0;

varying vec3 worldPos;
varying vec3 worldNormal;

void vertex(){
	worldPos = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz;
	worldNormal = normalize((MODEL_MATRIX * vec4(NORMAL,0.)).xyz);
}

float _gridLines(vec2 planePos, float spacing, float widthPixels){
	vec2 cellCoord = planePos / spacing;
	vec2 edgeDistance = abs(fract(cellCoord - .5) - .5) / max(fwidth(cellCoord),vec2(.00001));
	return 1. - smoothstep(0., widthPixels, min(edgeDistance.x,edgeDistance.y));
}

void fragment(){
	vec3 axisWeight = abs(worldNormal);
	vec2 planePos = axisWeight.y > .5 ? worldPos.xz : (axisWeight.x > .5 ? worldPos.zy : worldPos.xy);
	float cameraDistance = distance(worldPos,CAMERA_POSITION_WORLD);
	float distanceFade = 1. - smoothstep(fadeStart,fadeEnd,cameraDistance);
	float minorLines = _gridLines(planePos,cellSize,lineWidth) * distanceFade;
	float majorLines = _gridLines(planePos,cellSize * majorEvery,majorWidth);
	vec3 surfaceColor = mix(baseColor,lineColor,minorLines * lineStrength);
	surfaceColor = mix(surfaceColor,majorColor,majorLines * majorStrength);
	surfaceColor *= 1. - clamp(worldPos.y * heightTint,0.,.35);
	ALBEDO = surfaceColor;
	ROUGHNESS = mix(surfaceRoughness,clamp(surfaceRoughness + .3,0.,1.),max(minorLines,majorLines));
	METALLIC = 0.0;
	SPECULAR = .5;
}
