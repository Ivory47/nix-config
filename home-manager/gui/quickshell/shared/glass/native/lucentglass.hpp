#pragma once

// Glass drawn by the compositor (the Lucent Hyprland plugin, protocol lucent-glass-v1.xml).
//
// The live glass of GlassCapture blurs a screen capture, and a capture is of a finished frame: the
// glass is one compositor frame behind what it blurs at best. With this protocol the shell only says
// where the glass is, and the compositor draws it under the surface's own content while it makes the
// frame, from what is behind the surface in that very frame.
//
// lucent-glass-v1.xml here is a copy of ~/Documents/Code/Lucent/protocol/lucent-glass-v1.xml: keep
// the two the same.

#include <QtCore/QPointer>
#include <QtGui/QColor>
#include <QtGui/QVector2D>
#include <QtGui/QVector4D>
#include <QtQml/qqmlregistration.h>
#include <QtQuick/QQuickItem>

#include <QtWaylandClient/QWaylandClientExtension>
#include <qwayland-lucent-glass-v1.h>

struct lucent_glass_v1;
struct wl_surface;

namespace QtWaylandClient {
class QWaylandWindow;
}

// The compositor's global. Not active: the plugin is not loaded (or is a build without glass).
// Version 2 has the look of the glass (shape, refraction, tone, tint, light, highlights, hole);
// version 1 only blurred a rectangle. Version 3 takes regions with fractions.
class LucentGlassManager
    : public QWaylandClientExtensionTemplate<LucentGlassManager>
    , public QtWayland::lucent_glass_manager_v1 {
public:
	static LucentGlassManager* instance();

private:
	LucentGlassManager();
};

// One piece of compositor glass: the area of this item, behind the window's content. The window must
// leave that area transparent, or draw over it only what belongs on top of the glass.
class LucentGlass: public QQuickItem {
	Q_OBJECT
	QML_ELEMENT
	// The compositor offers the protocol, in a version that has the whole look. False: draw the
	// glass some other way.
	Q_PROPERTY(bool available READ available NOTIFY availableChanged)
	// Ask for the glass. (Without this, or while `available` is false, nothing is drawn.)
	Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
	// Blur strength: gaussian sigma in logical pixels.
	Q_PROPERTY(qreal blurRadius READ blurRadius WRITE setBlurRadius NOTIFY blurRadiusChanged)
	// Most samples per side of each blur pass (the blur's cost, see Theme.blurMaxTaps).
	Q_PROPERTY(int maxTaps READ maxTaps WRITE setMaxTaps NOTIFY maxTapsChanged)

	// The look: the same values, with the same meaning, as GlassPanel and GlassStyle have for the
	// shell's own glass (glass.frag; the compositor runs a copy of that shader). Lengths in logical
	// pixels. The defaults are the blurred background as it is.
	Q_PROPERTY(qreal frost MEMBER mFrost NOTIFY lookChanged)
	Q_PROPERTY(qreal bevel MEMBER mBevel NOTIFY lookChanged)
	Q_PROPERTY(qreal thickness MEMBER mThickness NOTIFY lookChanged)
	Q_PROPERTY(qreal cornerRadius MEMBER mCornerRadius NOTIFY lookChanged)
	// 1 where the edge is bevelled: left, top, right, bottom.
	Q_PROPERTY(QVector4D edges MEMBER mEdges NOTIFY lookChanged)
	Q_PROPERTY(qreal refraction MEMBER mRefraction NOTIFY lookChanged)
	Q_PROPERTY(qreal ior MEMBER mIor NOTIFY lookChanged)
	Q_PROPERTY(qreal dispersion MEMBER mDispersion NOTIFY lookChanged)
	Q_PROPERTY(QColor tint MEMBER mTint NOTIFY lookChanged)
	Q_PROPERTY(qreal tintStrength MEMBER mTintStrength NOTIFY lookChanged)
	Q_PROPERTY(qreal brightness MEMBER mBrightness NOTIFY lookChanged)
	Q_PROPERTY(qreal contrast MEMBER mContrast NOTIFY lookChanged)
	Q_PROPERTY(qreal saturation MEMBER mSaturation NOTIFY lookChanged)
	Q_PROPERTY(qreal shine MEMBER mShine NOTIFY lookChanged)
	Q_PROPERTY(QVector2D lightDir MEMBER mLightDir NOTIFY lookChanged)
	Q_PROPERTY(qreal glassOpacity MEMBER mGlassOpacity NOTIFY lookChanged)
	// Up to three rounded rectangles of colour in the glass: x, y, width, height relative to this
	// item, and rgb + strength.
	Q_PROPERTY(QVector4D hlRect0 MEMBER mHlRect0 NOTIFY lookChanged)
	Q_PROPERTY(QVector4D hlRect1 MEMBER mHlRect1 NOTIFY lookChanged)
	Q_PROPERTY(QVector4D hlRect2 MEMBER mHlRect2 NOTIFY lookChanged)
	Q_PROPERTY(QVector4D hlColor0 MEMBER mHlColor0 NOTIFY lookChanged)
	Q_PROPERTY(QVector4D hlColor1 MEMBER mHlColor1 NOTIFY lookChanged)
	Q_PROPERTY(QVector4D hlColor2 MEMBER mHlColor2 NOTIFY lookChanged)
	Q_PROPERTY(qreal hlRadius MEMBER mHlRadius NOTIFY lookChanged)
	// A rounded rectangle cut out of the glass, relative to this item (zero size: none).
	Q_PROPERTY(QVector4D holeRect MEMBER mHoleRect NOTIFY lookChanged)
	Q_PROPERTY(qreal holeRadius MEMBER mHoleRadius NOTIFY lookChanged)

public:
	explicit LucentGlass(QQuickItem* parent = nullptr);
	~LucentGlass() override;

	bool available() const;
	bool active() const { return this->mActive; }
	void setActive(bool active);
	qreal blurRadius() const { return this->mBlurRadius; }
	void setBlurRadius(qreal radius);
	int maxTaps() const { return this->mMaxTaps; }
	void setMaxTaps(int taps);

signals:
	void availableChanged();
	void activeChanged();
	void blurRadiusChanged();
	void maxTapsChanged();
	void lookChanged();

protected:
	void updatePolish() override;
	void geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) override;
	void itemChange(ItemChange change, const ItemChangeData& data) override;

private slots:
	void onAvailableChanged();
	void onSurfaceDestroyed();

private:
	void bindWindow(QQuickWindow* window);
	void drop(bool tellCompositor);

	void sendLook();

	bool mActive = false;
	qreal mBlurRadius = 0;
	int mMaxTaps = 0;

	qreal mFrost = 1;
	qreal mBevel = 0;
	qreal mThickness = 0;
	qreal mCornerRadius = 0;
	QVector4D mEdges;
	qreal mRefraction = 0;
	qreal mIor = 1.45;
	qreal mDispersion = 0;
	QColor mTint = QColor(0, 0, 0);
	qreal mTintStrength = 0;
	qreal mBrightness = 0;
	qreal mContrast = 1;
	qreal mSaturation = 1;
	qreal mShine = 0;
	QVector2D mLightDir = QVector2D(-0.4F, -0.9F);
	qreal mGlassOpacity = 1;
	QVector4D mHlRect0, mHlRect1, mHlRect2;
	QVector4D mHlColor0, mHlColor1, mHlColor2;
	qreal mHlRadius = 6;
	QVector4D mHoleRect;
	qreal mHoleRadius = 0;

	// The compositor's object for this piece of glass, and the surface it was made for.
	::lucent_glass_v1* mGlass = nullptr;
	::wl_surface* mSurface = nullptr;
	QPointer<QtWaylandClient::QWaylandWindow> mWaylandWindow;
	QMetaObject::Connection mSurfaceCreated;
	QMetaObject::Connection mSurfaceDestroyed;
};
