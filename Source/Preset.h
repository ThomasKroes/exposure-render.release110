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

#include <QObject>
#include <QDomDocument>
#include <QMessageBox>

class QPresetXML : public QObject
{
	Q_OBJECT

public:
	QPresetXML(QObject* pParent = NULL, const QString& Name = "");

	QPresetXML(const QPresetXML& Other)
	{
		m_Name = Other.m_Name;

		*this = Other;
	};

	QPresetXML& operator = (const QPresetXML& Other);

	virtual QString			GetName(void) const;
	virtual void			SetName(const QString& Name);
	virtual bool			GetDirty(void) const;
	virtual void			SetDirty(const bool& Dirty = true);
	virtual void			ReadXML(QDomElement& Parent);
	virtual QDomElement		WriteXML(QDomDocument& DOM, QDomElement& Parent);
	
private:
	QString		m_Name;
	bool		m_Dirty;
};

typedef QList<QPresetXML*> QPresetList;