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

class CRNG
{
public:
	HOD CRNG(unsigned int* pSeed0, unsigned int* pSeed1)
	{
		m_pSeed0 = pSeed0;
		m_pSeed1 = pSeed1;
	}

	HOD float Get1(void)
	{
		*m_pSeed0 = 36969 * ((*m_pSeed0) & 65535) + ((*m_pSeed0) >> 16);
		*m_pSeed1 = 18000 * ((*m_pSeed1) & 65535) + ((*m_pSeed1) >> 16);

		unsigned int ires = ((*m_pSeed0) << 16) + (*m_pSeed1);

		union
		{
			float f;
			unsigned int ui;
		} res;

		res.ui = (ires & 0x007fffff) | 0x40000000;

		return (res.f - 2.f) / 2.f;
	}

	HOD Vec2f Get2(void)
	{
		return Vec2f(Get1(), Get1());
	}

	HOD Vec3f Get3(void)
	{
		return Vec3f(Get1(), Get1(), Get1());
	}

private:
	unsigned int*	m_pSeed0;
	unsigned int*	m_pSeed1;
};