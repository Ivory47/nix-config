#include "lucentglass.hpp"

#include <cmath>
#include <string>
#include <typeinfo>

#include <QtQuick/QQuickWindow>
#include <QtWaylandClient/private/qwaylandshellsurface_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>
#include <wayland-client-core.h>
#include <wayland-lucent-glass-v1-client-protocol.h>

namespace {
// The newest version of the protocol this code speaks.
constexpr int kGlassVersion = 5;
// The oldest that does the job: regions with fractions and the whole look (layer surfaces), and
// glass behind the toplevel surface of a window (version 4; a plugin build that offers 3 only
// draws it behind layers, and would silently show a window nothing).
constexpr int kLayerVersion = 3;
constexpr int kToplevelVersion = 4;
} // namespace

LucentGlassManager::LucentGlassManager(): QWaylandClientExtensionTemplate(kGlassVersion) {
	// Qt lowers the extension's version to what a global offered and never raises it again: after
	// an older plugin build, a newer one would be bound at the old version for good. So when the
	// global goes away, ask for our own version again.
	QObject::connect(this, &QWaylandClientExtension::activeChanged, this, [this]() {
		if (!this->isActive()) this->setVersion(kGlassVersion);
	});
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
	QObject::connect(this, &LucentGlass::lookChanged, this, &QQuickItem::polish);
	// What QML reads first (before there is a window, so the lower requirement): availableChanged
	// is only sent when the answer differs from it.
	this->mAvailable = this->available();
}

LucentGlass::~LucentGlass() {
	this->drop(true);
}

// A window that is not a layer surface is a toplevel (an xdg_toplevel). Unknown (no shell surface
// yet, e.g. the window is not shown): treated as a layer, the lower requirement; this is asked
// again once the shell surface exists.
bool LucentGlass::isToplevel() const {
	auto* w = this->window();
	auto* wlw = w && w->handle() ? dynamic_cast<QtWaylandClient::QWaylandWindow*>(w->handle()) : nullptr;
	auto* shell = wlw ? wlw->shellSurface() : nullptr;
	if (!shell) return false;
	return std::string(typeid(*shell).name()).find("Layer") == std::string::npos;
}

// (An older plugin build offers a lower version: without the look, or without regions that are not
// on whole pixels, or, below 4, without glass behind windows. Not used.)
bool LucentGlass::available() const {
	auto* manager = LucentGlassManager::instance();
	// (The version the two sides agreed on when the global was bound.)
	return manager->isActive()
	    && manager->QWaylandClientExtension::version() >= (this->isToplevel() ? kToplevelVersion : kLayerVersion);
}

// available() depends on the window, which can change: tell QML when the answer did.
void LucentGlass::refreshAvailable() {
	const bool now = this->available();
	if (now == this->mAvailable) return;
	this->mAvailable = now;
	emit this->availableChanged();
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
	this->mAvailable = this->available();
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
	QObject::disconnect(this->mWindowVisible);
	this->drop(true);
	this->mWaylandWindow = nullptr;
	this->refreshAvailable();
	if (window) {
		// A window has no platform window (so no surface) until it is shown: the first polish can come
		// before that, and nothing else need follow it.
		this->mWindowVisible = QObject::connect(window, &QWindow::visibleChanged, this, &QQuickItem::polish);
		this->polish();
	}
}

// Before every frame of the window that follows a change: tell the compositor where the glass is.
// What is set here takes effect with the commit of that frame, so glass and content change
// together. (polish() also asks for the frame.)
void LucentGlass::updatePolish() {
	auto* w = this->window();
	auto* manager = LucentGlassManager::instance();
	// (The shell surface exists now, if the window has one: the version needed may have changed.)
	if (w) this->refreshAvailable();
	if (!w || !this->available()) return;

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
		// With fractions: a panel placed on whole pixels of an output with a fractional scale is
		// not on whole logical ones, and the glass must end exactly where the panel's border is.
		const auto topLeft = this->mapToScene(QPointF(0, 0));
		lucent_glass_v1_set_region_precise(
		    this->mGlass,
		    wl_fixed_from_double(topLeft.x()),
		    wl_fixed_from_double(topLeft.y()),
		    wl_fixed_from_double(this->width()),
		    wl_fixed_from_double(this->height())
		);
		lucent_glass_v1_set_blur(
		    this->mGlass,
		    wl_fixed_from_double(std::max(this->mBlurRadius, 0.0)),
		    uint32_t(std::max(this->mMaxTaps, 0))
		);
		this->sendLook();
	} else {
		lucent_glass_v1_set_region(this->mGlass, 0, 0, 0, 0);
	}

	// The state is applied by the surface's next commit: make sure there is one.
	w->update();
}

void LucentGlass::sendLook() {
	const auto fx = [](double v) { return wl_fixed_from_double(v); };
	auto* g = this->mGlass;

	uint32_t edges = 0;
	if (this->mEdges.x() > 0.5F) edges |= LUCENT_GLASS_V1_EDGE_LEFT;
	if (this->mEdges.y() > 0.5F) edges |= LUCENT_GLASS_V1_EDGE_TOP;
	if (this->mEdges.z() > 0.5F) edges |= LUCENT_GLASS_V1_EDGE_RIGHT;
	if (this->mEdges.w() > 0.5F) edges |= LUCENT_GLASS_V1_EDGE_BOTTOM;

	lucent_glass_v1_set_shape(g, fx(this->mCornerRadius), edges, fx(this->mBevel), fx(this->mThickness));
	// (A request newer than the object's version is a protocol error: an older plugin keeps its curve.)
	if (wl_proxy_get_version(reinterpret_cast<wl_proxy*>(g)) >= 5) lucent_glass_v1_set_bevel_profile(g, fx(this->mBevelProfile));
	lucent_glass_v1_set_refraction(g, fx(this->mRefraction), fx(this->mIor), fx(this->mDispersion));
	lucent_glass_v1_set_tone(g, fx(this->mFrost), fx(this->mBrightness), fx(this->mContrast), fx(this->mSaturation));
	lucent_glass_v1_set_tint(g, fx(this->mTint.redF()), fx(this->mTint.greenF()), fx(this->mTint.blueF()), fx(this->mTintStrength));
	lucent_glass_v1_set_light(g, fx(this->mShine), fx(this->mLightDir.x()), fx(this->mLightDir.y()));
	lucent_glass_v1_set_opacity(g, fx(this->mGlassOpacity));

	const QVector4D* rects[] = {&this->mHlRect0, &this->mHlRect1, &this->mHlRect2};
	const QVector4D* colors[] = {&this->mHlColor0, &this->mHlColor1, &this->mHlColor2};
	for (uint32_t i = 0; i < 3; i++) {
		const auto& r = *rects[i];
		const auto& c = *colors[i];
		lucent_glass_v1_set_highlight(g, i, fx(r.x()), fx(r.y()), fx(r.z()), fx(r.w()), fx(this->mHlRadius), fx(c.x()), fx(c.y()), fx(c.z()), fx(c.w()));
	}
	const auto& h = this->mHoleRect;
	lucent_glass_v1_set_hole(g, fx(h.x()), fx(h.y()), fx(h.z()), fx(h.w()), fx(this->mHoleRadius));
}
