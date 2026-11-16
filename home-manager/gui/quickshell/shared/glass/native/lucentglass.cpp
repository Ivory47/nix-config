#include "lucentglass.hpp"

#include <cmath>

#include <QtQuick/QQuickWindow>
#include <QtWaylandClient/private/qwaylandwindow_p.h>
#include <wayland-client-core.h>
#include <wayland-lucent-glass-v1-client-protocol.h>

LucentGlassManager::LucentGlassManager(): QWaylandClientExtensionTemplate(1) {
	this->initialize();
}

LucentGlassManager* LucentGlassManager::instance() {
	static auto* instance = new LucentGlassManager();
	return instance;
}

LucentGlass::LucentGlass(QQuickItem* parent): QQuickItem(parent) {
	QObject::connect(
	    LucentGlassManager::instance(),
	    &QWaylandClientExtension::activeChanged,
	    this,
	    &LucentGlass::onAvailableChanged
	);
}

LucentGlass::~LucentGlass() {
	this->drop(true);
}

bool LucentGlass::available() const {
	return LucentGlassManager::instance()->isActive();
}

void LucentGlass::setActive(bool active) {
	if (active == this->mActive) return;
	this->mActive = active;
	emit this->activeChanged();
	this->polish();
}

void LucentGlass::setBlurRadius(qreal radius) {
	if (qFuzzyCompare(radius, this->mBlurRadius)) return;
	this->mBlurRadius = radius;
	emit this->blurRadiusChanged();
	this->polish();
}

void LucentGlass::setMaxTaps(int taps) {
	if (taps == this->mMaxTaps) return;
	this->mMaxTaps = taps;
	emit this->maxTapsChanged();
	this->polish();
}

// The plugin was loaded or unloaded. When it goes, the compositor has already destroyed its side of
// our object: it must only be forgotten here (a request on it would be a protocol error, which
// ends the whole shell).
void LucentGlass::onAvailableChanged() {
	if (!this->available()) this->drop(false);
	emit this->availableChanged();
	this->polish();
}

void LucentGlass::onSurfaceDestroyed() {
	this->drop(this->available());
}

void LucentGlass::drop(bool tellCompositor) {
	if (!this->mGlass) return;
	if (tellCompositor && this->available()) lucent_glass_v1_destroy(this->mGlass);
	else wl_proxy_destroy(reinterpret_cast<wl_proxy*>(this->mGlass));
	this->mGlass = nullptr;
	this->mSurface = nullptr;
}

void LucentGlass::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
	this->QQuickItem::geometryChange(newGeometry, oldGeometry);
	this->polish();
}

void LucentGlass::itemChange(ItemChange change, const ItemChangeData& data) {
	if (change == ItemSceneChange) this->bindWindow(data.window);
	if (change == ItemVisibleHasChanged) this->polish();
	this->QQuickItem::itemChange(change, data);
}

void LucentGlass::bindWindow(QQuickWindow* window) {
	QObject::disconnect(this->mSurfaceCreated);
	QObject::disconnect(this->mSurfaceDestroyed);
	this->drop(true);
	this->mWaylandWindow = nullptr;
	if (window) this->polish();
}

// Before every frame of the window that follows a change: tell the compositor where the glass is.
// What is set here takes effect with the commit of that frame, so glass and content change
// together. (polish() also asks for the frame.)
void LucentGlass::updatePolish() {
	auto* w = this->window();
	auto* manager = LucentGlassManager::instance();
	if (!w || !manager->isActive()) return;

	auto* wlw = w->handle() ? dynamic_cast<QtWaylandClient::QWaylandWindow*>(w->handle()) : nullptr;
	if (wlw != this->mWaylandWindow) {
		QObject::disconnect(this->mSurfaceCreated);
		QObject::disconnect(this->mSurfaceDestroyed);
		this->drop(true);
		this->mWaylandWindow = wlw;
		if (wlw) {
			// The surface of a window can be made anew (hidden and shown again).
			this->mSurfaceCreated = QObject::connect(wlw, &QtWaylandClient::QWaylandWindow::wlSurfaceCreated, this, &QQuickItem::polish);
			this->mSurfaceDestroyed = QObject::connect(wlw, &QtWaylandClient::QWaylandWindow::wlSurfaceDestroyed, this, &LucentGlass::onSurfaceDestroyed);
		}
	}

	auto* surface = wlw ? wlw->wlSurface() : nullptr;
	if (surface != this->mSurface) this->drop(true);
	if (!surface) return;

	const bool shown = this->mActive && this->isVisible() && this->width() > 0 && this->height() > 0;
	if (!this->mGlass) {
		if (!shown) return;
		this->mGlass = lucent_glass_manager_v1_get_glass(manager->object(), surface);
		this->mSurface = surface;
		if (!this->mGlass) return;
	}

	if (shown) {
		const auto topLeft = this->mapToScene(QPointF(0, 0));
		lucent_glass_v1_set_region(
		    this->mGlass,
		    qRound(topLeft.x()),
		    qRound(topLeft.y()),
		    qRound(this->width()),
		    qRound(this->height())
		);
		lucent_glass_v1_set_blur(
		    this->mGlass,
		    wl_fixed_from_double(std::max(this->mBlurRadius, 0.0)),
		    uint32_t(std::max(this->mMaxTaps, 0))
		);
	} else {
		lucent_glass_v1_set_region(this->mGlass, 0, 0, 0, 0);
	}

	// The state is applied by the surface's next commit: make sure there is one.
	w->update();
}
