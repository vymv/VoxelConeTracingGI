#ifndef VOXELIZATION_GEOM_GLSL
#define VOXELIZATION_GEOM_GLSL
#extension GL_ARB_shading_language_include : enable
#extension GL_ARB_shader_image_load_store : require

#include "/voxelConeTracing/voxelization.glsl"

uniform mat4 u_viewProj[3];
uniform mat4 u_viewProjInv[3];
uniform vec2 u_viewportSizes[3];

#ifdef CONSERVATIVE_VOXELIZATION
out ConservativeVoxelizationFragmentInput
{
	vec3 posW;
    vec3 posClip;
    flat vec4 triangleAABB;
	flat vec3[3] trianglePosW; // 保存原来三角形的位置，用于后面的光线三角形相交测试
	flat int faceIdx;
	flat int faceIdx;
} out_cvFrag;

// Coservative Voxelization based on "Conservative Rasterization", GPU Gems 2 Chapter 42 by Jon Hasselgren, Tomas Akenine-Möller and Lennart Ohlsson:
// http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter42.html
void cvGeometryPass(out vec4 positionsClip[3])
{
	// 三角面片的主轴
	int idx = getDominantAxisIdx(gl_in[0].gl_Position.xyz, gl_in[1].gl_Position.xyz, gl_in[2].gl_Position.xyz);
	// geometry shader的特殊内置输出变量
	gl_ViewportIndex = idx;
    
	// 把原三角形的顶点位置变换到垂直于主轴，之后用cvEmitVertex发射
    positionsClip = vec4[3](
        u_viewProj[idx] * gl_in[0].gl_Position,
        u_viewProj[idx] * gl_in[1].gl_Position,
        u_viewProj[idx] * gl_in[2].gl_Position
    );

    vec2 hPixel = 1.0 / u_viewportSizes[idx];
	
	vec3 triangleNormalClip = normalize(cross(positionsClip[1].xyz - positionsClip[0].xyz, positionsClip[2].xyz - positionsClip[0].xyz));
	computeExtendedTriangle(hPixel, triangleNormalClip, positionsClip, out_cvFrag.triangleAABB);
	
	out_cvFrag.faceIdx = idx * 2;
	if (triangleNormalClip.z > 0.0)
		out_cvFrag.faceIdx += 1;
	
	// 保存原来三角形的位置，用于后面的光线三角形相交测试
	// Using the original triangle for the intersection tests introduces a slight underestimation
	out_cvFrag.trianglePosW[0] = gl_in[0].gl_Position.xyz;
	out_cvFrag.trianglePosW[1] = gl_in[1].gl_Position.xyz;
	out_cvFrag.trianglePosW[2] = gl_in[2].gl_Position.xyz;
	
	// Using the extended triangle for the intersection tests introduces an overestimation that might be unacceptable for high voxel sizes
	//out_cvFrag.trianglePosW[0] = (u_viewProjInv[idx] * pos[0]).xyz;
	//out_cvFrag.trianglePosW[1] = (u_viewProjInv[idx] * pos[1]).xyz;
	//out_cvFrag.trianglePosW[2] = (u_viewProjInv[idx] * pos[2]).xyz;
}

void cvEmitVertex(vec4 posClip)
{
	// 三角形里的三个顶点的输出，只有posW，posClip，gl_Position不一样，其他共享
	gl_Position = posClip;
	out_cvFrag.posW = (u_viewProjInv[gl_ViewportIndex] * posClip).xyz; // 原来的位置
	out_cvFrag.posClip = posClip.xyz; // 变换后的位置
	
	EmitVertex();
}
#endif // CONSERVATIVE_VOXELIZATION

#endif // VOXELIZATION_GEOM_GLSL