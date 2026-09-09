/*
	Copyright (c) 2011, T. Kroes <t.kroes@tudelft.nl>
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

	- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	- Neither the name of the <ORGANIZATION> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "Core.cuh"

// Texture references were removed in CUDA 12. The kernels still address these by
// name, so the texture objects live in constant memory where the references used
// to sit; only the fetch syntax in the .cuh files had to change.
__constant__ cudaTextureObject_t	gTexDensity;
__constant__ cudaTextureObject_t	gTexGradientMagnitude;
__constant__ cudaTextureObject_t	gTexExtinction;
__constant__ cudaTextureObject_t	gTexOpacity;
__constant__ cudaTextureObject_t	gTexDiffuse;
__constant__ cudaTextureObject_t	gTexSpecular;
__constant__ cudaTextureObject_t	gTexRoughness;
__constant__ cudaTextureObject_t	gTexEmission;
__constant__ cudaTextureObject_t	gTexRunningEstimateRgba;

// Host-side handles, kept only so the objects can be destroyed again.
static cudaTextureObject_t	ghTexDensity				= 0;
static cudaTextureObject_t	ghTexGradientMagnitude		= 0;
static cudaTextureObject_t	ghTexOpacity				= 0;
static cudaTextureObject_t	ghTexDiffuse				= 0;
static cudaTextureObject_t	ghTexSpecular				= 0;
static cudaTextureObject_t	ghTexRoughness				= 0;
static cudaTextureObject_t	ghTexEmission				= 0;
static cudaTextureObject_t	ghTexRunningEstimateRgba	= 0;

cudaArray* gpDensityArray				= NULL;
cudaArray* gpGradientMagnitudeArray		= NULL;
cudaArray* gpOpacityArray				= NULL;
cudaArray* gpDiffuseArray				= NULL;
cudaArray* gpSpecularArray				= NULL;
cudaArray* gpRoughnessArray				= NULL;
cudaArray* gpEmissionArray				= NULL;

CD float3		gAaBbMin;
CD float3		gAaBbMax;
CD float3		gInvAaBbMin;
CD float3		gInvAaBbMax;
CD float		gIntensityMin;
CD float		gIntensityMax;
CD float		gIntensityRange;
CD float		gIntensityInvRange;
CD float		gStepSize;
CD float		gStepSizeShadow;
CD float		gDensityScale;
CD float		gGradientDelta;
CD float		gInvGradientDelta;
CD float3		gGradientDeltaX;
CD float3		gGradientDeltaY;
CD float3		gGradientDeltaZ;
CD int			gFilmWidth;
CD int			gFilmHeight;
CD int			gFilmNoPixels;
CD int			gFilterWidth;
CD float		gFilterWeights[10];
CD float		gExposure;
CD float		gInvExposure;
CD float		gGamma;
CD float		gInvGamma;
CD float		gDenoiseEnabled;
CD float		gDenoiseWindowRadius;
CD float		gDenoiseInvWindowArea;
CD float		gDenoiseNoise;
CD float		gDenoiseWeightThreshold;
CD float		gDenoiseLerpThreshold;
CD float		gDenoiseLerpC;
CD float		gNoIterations;
CD float		gInvNoIterations;

#define TF_NO_SAMPLES		128
#define INV_TF_NO_SAMPLES	1.0f / (float)TF_NO_SAMPLES

#include "Model.cuh"
#include "View.cuh"
#include "Blur.cuh"
#include "Denoise.cuh"
#include "Estimate.cuh"
#include "Utilities.cuh"
#include "SingleScattering.cuh"
#include "NearestIntersection.cuh"
#include "SpecularBloom.cuh"
#include "ToneMap.cuh"

CCudaModel	gModel;
CCudaView	gRenderCanvasView;
CCudaView	gNavigatorView;

// Creates a texture object over a cudaArray with the sampling state the old
// texture references carried in their member fields.
static cudaTextureObject_t CreateArrayTextureObject(cudaArray_t Array, cudaTextureReadMode ReadMode, cudaTextureFilterMode FilterMode, bool Normalized, int NoDimensions)
{
	cudaResourceDesc ResourceDesc;
	memset(&ResourceDesc, 0, sizeof(ResourceDesc));

	ResourceDesc.resType			= cudaResourceTypeArray;
	ResourceDesc.res.array.array	= Array;

	cudaTextureDesc TextureDesc;
	memset(&TextureDesc, 0, sizeof(TextureDesc));

	TextureDesc.readMode			= ReadMode;
	TextureDesc.filterMode			= FilterMode;
	TextureDesc.normalizedCoords	= Normalized ? 1 : 0;

	for (int i = 0; i < NoDimensions; i++)
		TextureDesc.addressMode[i] = cudaAddressModeClamp;

	cudaTextureObject_t TextureObject = 0;

	HandleCudaError(cudaCreateTextureObject(&TextureObject, &ResourceDesc, &TextureDesc, NULL));

	return TextureObject;
}

static void DestroyTextureObject(cudaTextureObject_t& TextureObject)
{
	if (TextureObject == 0)
		return;

	HandleCudaError(cudaDestroyTextureObject(TextureObject));

	TextureObject = 0;
}

void BindDensityBuffer(short* pBuffer, cudaExtent Extent)
{
	cudaChannelFormatDesc ChannelDesc = cudaCreateChannelDesc<short>();

	HandleCudaError(cudaMalloc3DArray(&gpDensityArray, &ChannelDesc, Extent));

	cudaMemcpy3DParms CopyParams = {0};

	CopyParams.srcPtr	= make_cudaPitchedPtr(pBuffer, Extent.width * sizeof(short), Extent.width, Extent.height);
	CopyParams.dstArray	= gpDensityArray;
	CopyParams.extent	= Extent;
	CopyParams.kind		= cudaMemcpyHostToDevice;
	
	HandleCudaError(cudaMemcpy3D(&CopyParams));

	DestroyTextureObject(ghTexDensity);

	ghTexDensity = CreateArrayTextureObject(gpDensityArray, cudaReadModeNormalizedFloat, cudaFilterModeLinear, true, 3);

	HandleCudaError(cudaMemcpyToSymbol(gTexDensity, &ghTexDensity, sizeof(ghTexDensity)));
}

void BindGradientMagnitudeBuffer(short* pBuffer, cudaExtent Extent)
{
	cudaChannelFormatDesc ChannelDesc = cudaCreateChannelDesc<short>();
	HandleCudaError(cudaMalloc3DArray(&gpGradientMagnitudeArray, &ChannelDesc, Extent));

	cudaMemcpy3DParms CopyParams = {0};

	CopyParams.srcPtr	= make_cudaPitchedPtr(pBuffer, Extent.width * sizeof(short), Extent.width, Extent.height);
	CopyParams.dstArray	= gpGradientMagnitudeArray;
	CopyParams.extent	= Extent;
	CopyParams.kind		= cudaMemcpyHostToDevice;
	
	HandleCudaError(cudaMemcpy3D(&CopyParams));

	DestroyTextureObject(ghTexGradientMagnitude);

	ghTexGradientMagnitude = CreateArrayTextureObject(gpGradientMagnitudeArray, cudaReadModeNormalizedFloat, cudaFilterModeLinear, true, 3);

	HandleCudaError(cudaMemcpyToSymbol(gTexGradientMagnitude, &ghTexGradientMagnitude, sizeof(ghTexGradientMagnitude)));
}

void UnbindDensityBuffer(void)
{
	HandleCudaError(cudaFreeArray(gpDensityArray));
	gpDensityArray = NULL;
	DestroyTextureObject(ghTexDensity);
}

void UnbindGradientMagnitudeBuffer(void)
{
	HandleCudaError(cudaFreeArray(gpGradientMagnitudeArray));
	gpGradientMagnitudeArray = NULL;
	DestroyTextureObject(ghTexGradientMagnitude);
}

void BindRenderCanvasView(const CResolution2D& Resolution)
{
	gRenderCanvasView.Resize(Resolution);

	cudaChannelFormatDesc Channel;
	
	Channel = cudaCreateChannelDesc<uchar4>();

	// The running estimate lives in pitched linear memory, not a cudaArray. The
	// old texture reference set none of its sampling fields, so it inherited the
	// texture-reference defaults: unnormalised coordinates and point sampling.
	// Denoise.cuh addresses it in pixels (X + 0.5f), which relies on exactly that.
	DestroyTextureObject(ghTexRunningEstimateRgba);

	cudaResourceDesc ResourceDesc;
	memset(&ResourceDesc, 0, sizeof(ResourceDesc));

	ResourceDesc.resType					= cudaResourceTypePitch2D;
	ResourceDesc.res.pitch2D.devPtr			= gRenderCanvasView.m_EstimateRgbaLdr.GetPtr();
	ResourceDesc.res.pitch2D.desc			= Channel;
	ResourceDesc.res.pitch2D.width			= gRenderCanvasView.GetWidth();
	ResourceDesc.res.pitch2D.height			= gRenderCanvasView.GetHeight();
	ResourceDesc.res.pitch2D.pitchInBytes	= gRenderCanvasView.m_EstimateRgbaLdr.GetPitch();

	cudaTextureDesc TextureDesc;
	memset(&TextureDesc, 0, sizeof(TextureDesc));

	TextureDesc.readMode			= cudaReadModeNormalizedFloat;
	TextureDesc.filterMode			= cudaFilterModePoint;
	TextureDesc.normalizedCoords	= 0;
	TextureDesc.addressMode[0]		= cudaAddressModeClamp;
	TextureDesc.addressMode[1]		= cudaAddressModeClamp;

	HandleCudaError(cudaCreateTextureObject(&ghTexRunningEstimateRgba, &ResourceDesc, &TextureDesc, NULL));
	HandleCudaError(cudaMemcpyToSymbol(gTexRunningEstimateRgba, &ghTexRunningEstimateRgba, sizeof(ghTexRunningEstimateRgba)));
}

void ResetRenderCanvasView(void)
{
	gRenderCanvasView.Reset();
}

void FreeRenderCanvasView(void)
{
	DestroyTextureObject(ghTexRunningEstimateRgba);

	gRenderCanvasView.Free();
}

unsigned char* GetDisplayEstimate(void)
{
	return (unsigned char*)gRenderCanvasView.m_DisplayEstimateRgbLdr.GetPtr(0, 0);
}

void BindTransferFunctionOpacity(CTransferFunction& TransferFunctionOpacity)
{
	float Opacity[TF_NO_SAMPLES];

	for (int i = 0; i < TF_NO_SAMPLES; i++)
		Opacity[i] = TransferFunctionOpacity.F((float)i * INV_TF_NO_SAMPLES).r;
	
	cudaChannelFormatDesc ChannelDesc = cudaCreateChannelDesc<float>();

	if (gpOpacityArray == NULL)
		HandleCudaError(cudaMallocArray(&gpOpacityArray, &ChannelDesc, TF_NO_SAMPLES, 1));

	HandleCudaError(cudaMemcpy2DToArray(gpOpacityArray, 0, 0, Opacity, TF_NO_SAMPLES * sizeof(float), TF_NO_SAMPLES * sizeof(float), 1, cudaMemcpyHostToDevice));
	DestroyTextureObject(ghTexOpacity);

	ghTexOpacity = CreateArrayTextureObject(gpOpacityArray, cudaReadModeElementType, cudaFilterModeLinear, true, 1);

	HandleCudaError(cudaMemcpyToSymbol(gTexOpacity, &ghTexOpacity, sizeof(ghTexOpacity)));
}

void UnbindTransferFunctionOpacity(void)
{
	HandleCudaError(cudaFreeArray(gpOpacityArray));
	gpOpacityArray = NULL;
	DestroyTextureObject(ghTexOpacity);
}

void BindTransferFunctionDiffuse(CTransferFunction& TransferFunctionDiffuse)
{
	float4 Diffuse[TF_NO_SAMPLES];

	for (int i = 0; i < TF_NO_SAMPLES; i++)
	{
		Diffuse[i].x = TransferFunctionDiffuse.F((float)i * INV_TF_NO_SAMPLES).r;
		Diffuse[i].y = TransferFunctionDiffuse.F((float)i * INV_TF_NO_SAMPLES).g;
		Diffuse[i].z = TransferFunctionDiffuse.F((float)i * INV_TF_NO_SAMPLES).b;
	}

	cudaChannelFormatDesc ChannelDesc = cudaCreateChannelDesc<float4>();
	
	if (gpDiffuseArray == NULL)
		HandleCudaError(cudaMallocArray(&gpDiffuseArray, &ChannelDesc, TF_NO_SAMPLES, 1));

	HandleCudaError(cudaMemcpy2DToArray(gpDiffuseArray, 0, 0, Diffuse, TF_NO_SAMPLES * sizeof(float4), TF_NO_SAMPLES * sizeof(float4), 1, cudaMemcpyHostToDevice));
	DestroyTextureObject(ghTexDiffuse);

	ghTexDiffuse = CreateArrayTextureObject(gpDiffuseArray, cudaReadModeElementType, cudaFilterModeLinear, true, 1);

	HandleCudaError(cudaMemcpyToSymbol(gTexDiffuse, &ghTexDiffuse, sizeof(ghTexDiffuse)));
}

void UnbindTransferFunctionDiffuse(void)
{
	HandleCudaError(cudaFreeArray(gpDiffuseArray));
	gpDiffuseArray = NULL;
	DestroyTextureObject(ghTexDiffuse);
}

void BindTransferFunctionSpecular(CTransferFunction& TransferFunctionSpecular)
{
	float4 Specular[TF_NO_SAMPLES];

	for (int i = 0; i < TF_NO_SAMPLES; i++)
	{
		Specular[i].x = TransferFunctionSpecular.F((float)i * INV_TF_NO_SAMPLES).r;
		Specular[i].y = TransferFunctionSpecular.F((float)i * INV_TF_NO_SAMPLES).g;
		Specular[i].z = TransferFunctionSpecular.F((float)i * INV_TF_NO_SAMPLES).b;
	}

	cudaChannelFormatDesc ChannelDesc = cudaCreateChannelDesc<float4>();
	
	if (gpSpecularArray == NULL)
		HandleCudaError(cudaMallocArray(&gpSpecularArray, &ChannelDesc, TF_NO_SAMPLES, 1));

	HandleCudaError(cudaMemcpy2DToArray(gpSpecularArray, 0, 0, Specular, TF_NO_SAMPLES * sizeof(float4), TF_NO_SAMPLES * sizeof(float4), 1, cudaMemcpyHostToDevice));
	DestroyTextureObject(ghTexSpecular);

	ghTexSpecular = CreateArrayTextureObject(gpSpecularArray, cudaReadModeElementType, cudaFilterModeLinear, true, 1);

	HandleCudaError(cudaMemcpyToSymbol(gTexSpecular, &ghTexSpecular, sizeof(ghTexSpecular)));
}

void UnbindTransferFunctionSpecular(void)
{
	HandleCudaError(cudaFreeArray(gpSpecularArray));
	gpSpecularArray = NULL;
	DestroyTextureObject(ghTexSpecular);
}

void BindTransferFunctionRoughness(CTransferFunction& TransferFunctionRoughness)
{
	float Roughness[TF_NO_SAMPLES];

	for (int i = 0; i < TF_NO_SAMPLES; i++)
		Roughness[i] = TransferFunctionRoughness.F((float)i * INV_TF_NO_SAMPLES).r;
	
	cudaChannelFormatDesc ChannelDesc = cudaCreateChannelDesc<float>();

	if (gpRoughnessArray == NULL)
		HandleCudaError(cudaMallocArray(&gpRoughnessArray, &ChannelDesc, TF_NO_SAMPLES, 1));

	HandleCudaError(cudaMemcpy2DToArray(gpRoughnessArray, 0, 0, Roughness, TF_NO_SAMPLES * sizeof(float), TF_NO_SAMPLES * sizeof(float), 1, cudaMemcpyHostToDevice));
	DestroyTextureObject(ghTexRoughness);

	ghTexRoughness = CreateArrayTextureObject(gpRoughnessArray, cudaReadModeElementType, cudaFilterModeLinear, true, 1);

	HandleCudaError(cudaMemcpyToSymbol(gTexRoughness, &ghTexRoughness, sizeof(ghTexRoughness)));
}

void UnbindTransferFunctionRoughness(void)
{
	HandleCudaError(cudaFreeArray(gpRoughnessArray));
	gpRoughnessArray = NULL;
	DestroyTextureObject(ghTexRoughness);
}

void BindTransferFunctionEmission(CTransferFunction& TransferFunctionEmission)
{
	float4 Emission[TF_NO_SAMPLES];

	for (int i = 0; i < TF_NO_SAMPLES; i++)
	{
		Emission[i].x = TransferFunctionEmission.F((float)i * INV_TF_NO_SAMPLES).r;
		Emission[i].y = TransferFunctionEmission.F((float)i * INV_TF_NO_SAMPLES).g;
		Emission[i].z = TransferFunctionEmission.F((float)i * INV_TF_NO_SAMPLES).b;
	}

	cudaChannelFormatDesc ChannelDesc = cudaCreateChannelDesc<float4>();
	
	if (gpEmissionArray == NULL)
		HandleCudaError(cudaMallocArray(&gpEmissionArray, &ChannelDesc, TF_NO_SAMPLES, 1));

	HandleCudaError(cudaMemcpy2DToArray(gpEmissionArray, 0, 0, Emission, TF_NO_SAMPLES * sizeof(float4), TF_NO_SAMPLES * sizeof(float4), 1, cudaMemcpyHostToDevice));
	DestroyTextureObject(ghTexEmission);

	ghTexEmission = CreateArrayTextureObject(gpEmissionArray, cudaReadModeElementType, cudaFilterModeLinear, true, 1);

	HandleCudaError(cudaMemcpyToSymbol(gTexEmission, &ghTexEmission, sizeof(ghTexEmission)));
}

void UnbindTransferFunctionEmission(void)
{
	HandleCudaError(cudaFreeArray(gpEmissionArray));
	gpEmissionArray = NULL;
	DestroyTextureObject(ghTexEmission);
}

void BindConstants(CScene* pScene)
{
	const float3 AaBbMin = make_float3(pScene->m_BoundingBox.GetMinP().x, pScene->m_BoundingBox.GetMinP().y, pScene->m_BoundingBox.GetMinP().z);
	const float3 AaBbMax = make_float3(pScene->m_BoundingBox.GetMaxP().x, pScene->m_BoundingBox.GetMaxP().y, pScene->m_BoundingBox.GetMaxP().z);

	HandleCudaError(cudaMemcpyToSymbol(gAaBbMin, &AaBbMin, sizeof(float3)));
	HandleCudaError(cudaMemcpyToSymbol(gAaBbMax, &AaBbMax, sizeof(float3)));

	const float3 InvAaBbMin = make_float3(pScene->m_BoundingBox.GetInvMinP().x, pScene->m_BoundingBox.GetInvMinP().y, pScene->m_BoundingBox.GetInvMinP().z);
	const float3 InvAaBbMax = make_float3(pScene->m_BoundingBox.GetInvMaxP().x, pScene->m_BoundingBox.GetInvMaxP().y, pScene->m_BoundingBox.GetInvMaxP().z);

	HandleCudaError(cudaMemcpyToSymbol(gInvAaBbMin, &InvAaBbMin, sizeof(float3)));
	HandleCudaError(cudaMemcpyToSymbol(gInvAaBbMax, &InvAaBbMax, sizeof(float3)));

	const float IntensityMin		= pScene->m_IntensityRange.GetMin();
	const float IntensityMax		= pScene->m_IntensityRange.GetMax();
	const float IntensityRange		= pScene->m_IntensityRange.GetRange();
	const float IntensityInvRange	= 1.0f / IntensityRange;

	HandleCudaError(cudaMemcpyToSymbol(gIntensityMin, &IntensityMin, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gIntensityMax, &IntensityMax, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gIntensityRange, &IntensityRange, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gIntensityInvRange, &IntensityInvRange, sizeof(float)));

	const float StepSize		= pScene->m_StepSizeFactor * pScene->m_GradientDelta;
	const float StepSizeShadow	= pScene->m_StepSizeFactorShadow * pScene->m_GradientDelta;

	HandleCudaError(cudaMemcpyToSymbol(gStepSize, &StepSize, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gStepSizeShadow, &StepSizeShadow, sizeof(float)));

	const float DensityScale = pScene->m_DensityScale;

	HandleCudaError(cudaMemcpyToSymbol(gDensityScale, &DensityScale, sizeof(float)));
	
	const float GradientDelta		= 1.0f * pScene->m_GradientDelta;
	const float InvGradientDelta	= 1.0f / GradientDelta;
	const Vec3f GradientDeltaX(GradientDelta, 0.0f, 0.0f);
	const Vec3f GradientDeltaY(0.0f, GradientDelta, 0.0f);
	const Vec3f GradientDeltaZ(0.0f, 0.0f, GradientDelta);
	
	HandleCudaError(cudaMemcpyToSymbol(gGradientDelta, &GradientDelta, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gInvGradientDelta, &InvGradientDelta, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gGradientDeltaX, &GradientDeltaX, sizeof(Vec3f)));
	HandleCudaError(cudaMemcpyToSymbol(gGradientDeltaY, &GradientDeltaY, sizeof(Vec3f)));
	HandleCudaError(cudaMemcpyToSymbol(gGradientDeltaZ, &GradientDeltaZ, sizeof(Vec3f)));
	
	const int FilmWidth		= pScene->m_Camera.m_Film.GetWidth();
	const int Filmheight	= pScene->m_Camera.m_Film.GetHeight();
	const int FilmNoPixels	= pScene->m_Camera.m_Film.m_Resolution.GetNoElements();

	HandleCudaError(cudaMemcpyToSymbol(gFilmWidth, &FilmWidth, sizeof(int)));
	HandleCudaError(cudaMemcpyToSymbol(gFilmHeight, &Filmheight, sizeof(int)));
	HandleCudaError(cudaMemcpyToSymbol(gFilmNoPixels, &FilmNoPixels, sizeof(int)));

	const int FilterWidth = 1;

	HandleCudaError(cudaMemcpyToSymbol(gFilterWidth, &FilterWidth, sizeof(int)));

	const float FilterWeights[10] = { 0.11411459588254977f, 0.08176668094332218f, 0.03008028089187349f, 0.01f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f };

	HandleCudaError(cudaMemcpyToSymbol(gFilterWeights, &FilterWeights, 10 * sizeof(float)));

	const float Gamma		= pScene->m_Camera.m_Film.m_Gamma;
	const float InvGamma	= 1.0f / Gamma;
	const float Exposure	= pScene->m_Camera.m_Film.m_Exposure;
	const float InvExposure	= 1.0f / Exposure;

	HandleCudaError(cudaMemcpyToSymbol(gExposure, &Exposure, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gInvExposure, &InvExposure, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gGamma, &Gamma, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gInvGamma, &InvGamma, sizeof(float)));

	HandleCudaError(cudaMemcpyToSymbol(gDenoiseEnabled, &pScene->m_DenoiseParams.m_Enabled, sizeof(bool)));
	HandleCudaError(cudaMemcpyToSymbol(gDenoiseWindowRadius, &pScene->m_DenoiseParams.m_WindowRadius, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gDenoiseInvWindowArea, &pScene->m_DenoiseParams.m_InvWindowArea, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gDenoiseNoise, &pScene->m_DenoiseParams.m_Noise, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gDenoiseWeightThreshold, &pScene->m_DenoiseParams.m_WeightThreshold, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gDenoiseLerpThreshold, &pScene->m_DenoiseParams.m_LerpThreshold, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gDenoiseLerpC, &pScene->m_DenoiseParams.m_LerpC, sizeof(float)));

	const float NoIterations	= pScene->GetNoIterations();
	const float InvNoIterations = 1.0f / max(1.0f, NoIterations);

	HandleCudaError(cudaMemcpyToSymbol(gNoIterations, &NoIterations, sizeof(float)));
	HandleCudaError(cudaMemcpyToSymbol(gInvNoIterations, &InvNoIterations, sizeof(float)));
}

void Render(const int& Type, CScene& Scene, CTiming& RenderImage, CTiming& BlurImage, CTiming& PostProcessImage, CTiming& DenoiseImage)
{
	CScene* pDevScene = NULL;

	HandleCudaError(cudaMalloc(&pDevScene, sizeof(CScene)));
	HandleCudaError(cudaMemcpy(pDevScene, &Scene, sizeof(CScene), cudaMemcpyHostToDevice));

	if (Scene.m_Camera.m_Focus.m_Type == 0)
		Scene.m_Camera.m_Focus.m_FocalDistance = NearestIntersection(pDevScene);

	HandleCudaError(cudaMemcpy(pDevScene, &Scene, sizeof(CScene), cudaMemcpyHostToDevice));

	CCudaView* pDevView = NULL;

	HandleCudaError(cudaMalloc(&pDevView, sizeof(CCudaView)));
	HandleCudaError(cudaMemcpy(pDevView, &gRenderCanvasView, sizeof(CCudaView), cudaMemcpyHostToDevice));

	
	CCudaTimer TmrRender;
	
	switch (Type)
	{
		case 0:
		{
			SingleScattering(&Scene, pDevScene, pDevView);
			break;
		}

		case 1:
		{
//			MultipleScattering(&Scene, pDevScene);
			break;
		}
	}

	RenderImage.AddDuration(TmrRender.ElapsedTime());
	
 	CCudaTimer TmrBlur;
	Blur(&Scene, pDevScene, pDevView);
	BlurImage.AddDuration(TmrBlur.ElapsedTime());

	CCudaTimer TmrPostProcess;
	Estimate(&Scene, pDevScene, pDevView);
	PostProcessImage.AddDuration(TmrPostProcess.ElapsedTime());

	ToneMap(&Scene, pDevScene, pDevView);

	CCudaTimer TmrDenoise;
	Denoise(&Scene, pDevScene, pDevView);
	DenoiseImage.AddDuration(TmrDenoise.ElapsedTime());
	

	HandleCudaError(cudaFree(pDevScene));
	HandleCudaError(cudaFree(pDevView));
}