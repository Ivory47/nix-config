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
#include <QtQml/qqmlregistration.h>
#include <QtQuick/QQuickItem>

#include <QtWaylandClient/QWaylandClientExtension>
#include <qwayland-lucent-glass-v1.h>

struct lucent_glass_v1;
struct wl_surface;

namespace QtWaylandClient {
class QWaylandWindow;
}

// The compositor's global. Not active: the plugin is not loaded (or is an older build).
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
	// The compositor offers the protocol. False: draw the glass some other way.
	Q_PROPERTY(bool available READ available NOTIFY availableChanged)
	// Ask for the glass. (Without this, or while `available` is false, nothing is drawn.)
	Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
	// Blur strength: gaussian sigma in logical pixels.
	Q_PROPERTY(qreal blurRadius READ blurRadius WRITE setBlurRadius NOTIFY blurRadiusChanged)
	// Most samples per side of each blur pass (the blur's cost, see Theme.blurMaxTaps).
	Q_PROPERTY(int maxTaps READ maxTaps WRITE setMaxTaps NOTIFY maxTapsChanged)

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

	bool mActive = false;
	qreal mBlurRadius = 0;
	int mMaxTaps = 0;

	// The compositor's object for this piece of glass, and the surface it was made for.
	::lucent_glass_v1* mGlass = nullptr;
	::wl_surface* mSurface = nullptr;
	QPointer<QtWaylandClient::QWaylandWindow> mWaylandWindow;
	QMetaObject::Connection mSurfaceCreated;
	QMetaObject::Connection mSurfaceDestroyed;
};
