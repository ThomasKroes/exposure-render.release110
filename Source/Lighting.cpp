
#include "Lighting.h"
#include "Scene.h"

QLighting gLighting;

QLight::QLight(QObject* pParent) :
	QPresetXML(pParent),
	m_Theta(),
	m_Phi(),
	m_Distance(),
	m_Width(),
	m_Height(),
	m_LockSize(),
	m_Color(),
	m_Intensity()
{
}

float QLight::GetTheta(void) const
{
	return m_Theta;
}

void QLight::SetTheta(const float& Theta)
{
	m_Theta = Theta;

	emit LightPropertiesChanged(this);
}

float QLight::GetPhi(void) const
{
	return m_Phi;
}

void QLight::SetPhi(const float& Phi)
{
	m_Phi = Phi;

	emit LightPropertiesChanged(this);
}

float QLight::GetWidth(void) const
{
	return m_Width;
}

void QLight::SetWidth(const float& Width)
{
	m_Width = Width;

	emit LightPropertiesChanged(this);
}

float QLight::GetHeight(void) const
{
	return m_Height;
}

void QLight::SetHeight(const float& Height)
{
	m_Height = Height;

	emit LightPropertiesChanged(this);
}

bool QLight::GetLockSize(void) const
{
	return m_LockSize;
}

void QLight::SetLockSize(const bool& LockSize)
{
	m_LockSize = LockSize;
}

float QLight::GetDistance(void) const
{
	return m_Distance;
}

void QLight::SetDistance(const float& Distance)
{
	m_Distance = Distance;

	emit LightPropertiesChanged(this);
}

QColor QLight::GetColor(void) const
{
	return m_Color;
}

void QLight::SetColor(const QColor& Color)
{
	m_Color = Color;

	emit LightPropertiesChanged(this);
}

float QLight::GetIntensity(void) const
{
	return m_Intensity;
}

void QLight::SetIntensity(const float& Intensity)
{
	m_Intensity = Intensity;

	emit LightPropertiesChanged(this);
}

void QLight::ReadXML(QDomElement& Parent)
{
	QPresetXML::ReadXML(Parent);

	m_Theta		= Parent.firstChildElement("Theta").attribute("Value").toFloat();
	m_Phi		= Parent.firstChildElement("Phi").attribute("Value").toFloat();
	m_Distance	= Parent.firstChildElement("Distance").attribute("Value").toFloat();
	m_Width		= Parent.firstChildElement("Width").attribute("Value").toFloat();
	m_Height	= Parent.firstChildElement("Height").attribute("Value").toFloat();
	m_LockSize	= Parent.firstChildElement("LockSize").attribute("Value").toInt();

	QDomElement Color = Parent.firstChildElement("Color");

	m_Color.setRed(Color.attribute("R").toInt());
	m_Color.setGreen(Color.attribute("G").toInt());
	m_Color.setBlue(Color.attribute("B").toInt());

	m_Intensity = Parent.firstChildElement("Intensity").attribute("Value").toFloat();
}

QDomElement QLight::WriteXML(QDomDocument& DOM, QDomElement& Parent)
{
	// Light
	QDomElement Light = DOM.createElement("Light");
	Parent.appendChild(Light);

	QPresetXML::WriteXML(DOM, Light);

	// Theta
	QDomElement Theta = DOM.createElement("Theta");
	Theta.setAttribute("Value", m_Theta);
	Light.appendChild(Theta);

	// Phi
	QDomElement Phi = DOM.createElement("Phi");
	Phi.setAttribute("Value", m_Phi);
	Light.appendChild(Phi);

	// Distance
	QDomElement Distance = DOM.createElement("Distance");
	Distance.setAttribute("Value", m_Distance);
	Light.appendChild(Distance);

	// Width
	QDomElement Width = DOM.createElement("Width");
	Width.setAttribute("Value", m_Width);
	Light.appendChild(Width);

	// Height
	QDomElement Height = DOM.createElement("Height");
	Height.setAttribute("Value", m_Height);
	Light.appendChild(Height);

	// LockSize
	QDomElement LockSize = DOM.createElement("LockSize");
	LockSize.setAttribute("Value", m_LockSize);
	Light.appendChild(LockSize);

	// Color
	QDomElement Color = DOM.createElement("Color");
	Color.setAttribute("R", m_Color.red());
	Color.setAttribute("G", m_Color.green());
	Color.setAttribute("B", m_Color.blue());
	Light.appendChild(Color);

	// Intensity
	QDomElement Intensity = DOM.createElement("Intensity");
	Intensity.setAttribute("Value", m_Intensity);
	Light.appendChild(Intensity);

	return Light;
}

QBackground::QBackground(QObject* pParent) :
	QPresetXML(pParent),
	m_Enable(true),
	m_Color(Qt::white),
	m_Intensity(100.0),
	m_UseTexture(false),
	m_File("")
{
}

bool QBackground::GetEnabled(void) const
{
	return m_Enable;
}

void QBackground::SetEnabled(const bool& Enable)
{
	m_Enable = Enable;

	emit BackgroundChanged();
}

QColor QBackground::GetColor(void) const
{
	return m_Color;
}

void QBackground::SetColor(const QColor& Color)
{
	m_Color = Color;

	emit BackgroundChanged();
}

float QBackground::GetIntensity(void) const
{
	return m_Intensity;
}

void QBackground::SetIntensity(const float& Intensity)
{
	m_Intensity = Intensity;

	emit BackgroundChanged();
}

bool QBackground::GetUseTexture(void) const
{
	return m_UseTexture;
}

void QBackground::SetUseTexture(const bool& Texture)
{
	m_UseTexture = Texture;

	emit BackgroundChanged();
}

QString QBackground::GetFile(void) const
{
	return m_File;
}

void QBackground::SetFile(const QString& File)
{
	m_File = File;

	emit BackgroundChanged();
}

void QBackground::ReadXML(QDomElement& Parent)
{
	QPresetXML::ReadXML(Parent);

	SetEnabled(Parent.firstChildElement("Enable").attribute("Value").toInt());
	
	QDomElement Color = Parent.firstChildElement("Color");

	SetColor(QColor(Color.attribute("R").toInt(), Color.attribute("G").toInt(), Color.attribute("B").toInt()));

	SetIntensity(Parent.firstChildElement("Intensity").attribute("Value").toFloat());
	SetUseTexture(Parent.firstChildElement("UseTexture").attribute("Value").toInt());
	SetFile(Parent.firstChildElement("Height").attribute("Value"));
}

QDomElement QBackground::WriteXML(QDomDocument& DOM, QDomElement& Parent)
{
	// Background
	QDomElement Background = DOM.createElement("Background");
	Parent.appendChild(Background);

//	QPresetXML::WriteXML(DOM, Background);

	// Enable
	QDomElement Enable = DOM.createElement("Enable");
	Enable.setAttribute("Value", m_Enable);
	Background.appendChild(Enable);

	// Color
	QDomElement Color = DOM.createElement("Color");
	Color.setAttribute("R", m_Color.red());
	Color.setAttribute("G", m_Color.green());
	Color.setAttribute("B", m_Color.blue());
	Background.appendChild(Color);

	// Intensity
	QDomElement Intensity = DOM.createElement("Intensity");
	Intensity.setAttribute("Value", m_Intensity);
	Background.appendChild(Intensity);

	// Use texture
	QDomElement UseTexture = DOM.createElement("UseTexture");
	UseTexture.setAttribute("Value", m_UseTexture);
	Background.appendChild(UseTexture);

	// File
	QDomElement File = DOM.createElement("File");
	File.setAttribute("Value", m_File);
	Background.appendChild(File);

	return Background;
}

QLighting::QLighting(QObject* pParent /*= NULL*/) :
	QPresetXML(pParent),
	m_Lights(),
	m_Background()
{
	connect(&m_Background, SIGNAL(BackgroundChanged()), this, SLOT(Update()));
}

void QLighting::ReadXML(QDomElement& Parent)
{
	QPresetXML::ReadXML(Parent);

	QDomElement Lights = Parent.firstChild().toElement();

	// Read child nodes
	for (QDomNode DomNode = Lights.firstChild(); !DomNode.isNull(); DomNode = DomNode.nextSibling())
	{
		// Create new node
		QLight Preset(this);

		m_Lights.append(Preset);

		// Load preset into it
		m_Lights.back().ReadXML(DomNode.toElement());
	}

	QDomElement Background = Parent.firstChildElement("Background").toElement();
	m_Background.ReadXML(Background);
}

QDomElement QLighting::WriteXML(QDomDocument& DOM, QDomElement& Parent)
{
	// Preset
	QDomElement Preset = DOM.createElement("Preset");
	Parent.appendChild(Preset);

	QPresetXML::WriteXML(DOM, Preset);

	QDomElement Lights = DOM.createElement("Lights");
	Preset.appendChild(Lights);

	for (int i = 0; i < m_Lights.size(); i++)
		m_Lights[i].WriteXML(DOM, Lights);
	
	m_Background.WriteXML(DOM, Preset);

	return Preset;
}

void QLighting::OnLightPropertiesChanged(QLight* pLight)
{
	Update();
}

void QLighting::Update(void)
{
	if (gLighting.m_Lights.isEmpty())
		return;

	gpScene->m_Lighting.m_NoLights = gLighting.m_Lights.size();

	for (int i = 0; i < gLighting.m_Lights.size(); i++)
	{
		QLight& Light = gLighting.m_Lights[i];

		CLight NewLight;

		NewLight.m_Theta	= Light.GetTheta();
		NewLight.m_Phi		= Light.GetPhi();
		NewLight.m_Distance	= Light.GetDistance();
		NewLight.m_Width	= Light.GetWidth();
		NewLight.m_Height	= Light.GetHeight();
		NewLight.m_Color.r	= Light.GetColor().red() * Light.GetIntensity();
		NewLight.m_Color.g	= Light.GetColor().green() * Light.GetIntensity();
		NewLight.m_Color.b	= Light.GetColor().blue() * Light.GetIntensity();

		gpScene->m_Lighting.m_Lights[i] = NewLight;
	}

	// Flag the lights as dirty, this will restart the rendering
	gpScene->m_DirtyFlags.SetFlag(LightsDirty);
}

void QLighting::AddLight(QLight& Light)
{
	m_Lights.append(Light);

	connect(&m_Lights.back(), SIGNAL(LightPropertiesChanged(QLight*)), this, SLOT(OnLightPropertiesChanged(QLight*)));
}

QBackground& QLighting::Background(void)
{
	return m_Background;
}