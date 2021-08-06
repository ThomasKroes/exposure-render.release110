/*
	Copyright (c) 2011, T. Kroes <t.kroes@tudelft.nl>
	All rights reserved.

	Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

	- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	- Neither the name of the <ORGANIZATION> nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
	
	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

*/
#pragma once

#include "Geometry.h"
#include "Scene.h"
#include "CudaUtilities.h"

#define KRNL_SS_BLOCK_W		16
#define KRNL_SS_BLOCK_H		8
#define KRNL_SS_BLOCK_SIZE	KRNL_SS_BLOCK_W * KRNL_SS_BLOCK_H

DEV inline bool SampleDistanceRM(CRay& R, CRNG& RNG, Vec3f& Ps)
{
	const int TID = threadIdx.y * blockDim.x + threadIdx.x;

	__shared__ float MinT[KRNL_SS_BLOCK_SIZE];
	__shared__ float MaxT[KRNL_SS_BLOCK_SIZE];

	if (!IntersectBox(R, &MinT[TID], &MaxT[TID]))
		return false;

	MinT[TID] = max(MinT[TID], R.m_MinT);
	MaxT[TID] = min(MaxT[TID], R.m_MaxT);

	const float S	= -log(RNG.Get1()) / gDensityScale;
	float Sum		= 0.0f;
	float SigmaT	= 0.0f;

	MinT[TID] += RNG.Get1() * gStepSize;

	while (Sum < S)
	{
		Ps = R.m_O + MinT[TID] * R.m_D;

		if (MinT[TID] > MaxT[TID])
			return false;
		
		SigmaT	= gDensityScale * GetOpacity(GetNormalizedIntensity(Ps));

		Sum			+= SigmaT * gStepSize;
		MinT[TID]	+= gStepSize;
	}

	return true;
}

DEV inline bool FreePathRM(const CRay& R, CRNG& RNG)
{
	const int TID = threadIdx.y * blockDim.x + threadIdx.x;

	__shared__ float MinT[KRNL_SS_BLOCK_SIZE];
	__shared__ float MaxT[KRNL_SS_BLOCK_SIZE];
	__shared__ Vec3f Ps[KRNL_SS_BLOCK_SIZE];

	if (!IntersectBox(R, &MinT[TID], &MaxT[TID]))
		return false;

	MinT[TID] = max(MinT[TID], R.m_MinT);
	MaxT[TID] = min(MaxT[TID], R.m_MaxT);

	const float S	= -log(RNG.Get1()) / gDensityScale;
	float Sum		= 0.0f;
	float SigmaT	= 0.0f;

	MinT[TID] += RNG.Get1() * gStepSizeShadow;

	while (Sum < S)
	{
		Ps[TID] = R.m_O + MinT[TID] * R.m_D;

		if (MinT[TID] > MaxT[TID])
			return false;
		
		SigmaT	= gDensityScale * GetOpacity(GetNormalizedIntensity(Ps[TID]));

		Sum			+= SigmaT * gStepSizeShadow;
		MinT[TID]	+= gStepSizeShadow;
	}

	return true;
}

DEV inline bool NearestIntersection(CRay R, CScene* pScene, float& T)
{
	float MinT = 0.0f, MaxT = 0.0f;

	if (!IntersectBox(R, &MinT, &MaxT))
		return false;

	MinT = max(MinT, R.m_MinT);
	MaxT = min(MaxT, R.m_MaxT);

	Vec3f Ps; 

	T = MinT;

	while (T < MaxT)
	{
		Ps = R.m_O + T * R.m_D;

		if (GetOpacity(GetNormalizedIntensity(Ps)) > 0.0f)
			return true;

		T += gStepSize;
	}

	return false;
}