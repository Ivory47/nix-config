#include "glasscapture.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>

#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>
#include <GLES2/gl2ext.h>
#include <drm_fourcc.h>
#include <fcntl.h>
#include <gbm.h>
#include <linux/dma-buf.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client-protocol.h>

#include <QtCore/QLoggingCategory>
#include <QtCore/QRunnable>
#include <QtGui/qguiapplication.h>
#include <QtQuick/QQuickWindow>
#include <QtQuick/QSGRendererInterface>
#include <QtQuick/qsgtexture.h>
#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandscreen_p.h>
#include <QtWaylandClient/private/qwaylandshm_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>

Q_LOGGING_CATEGORY(logGlass, "glass.capture", QtWarningMsg)

namespace {

constexpr int kDefaultPoolLimit = 12;
// How long the compositor may take to hand back a canceled capture's buffer, when nothing can
// tell us (no fence, or a capture that was canceled while the compositor was copying).
constexpr qint64 kHoldMs = 250;
// A capture that waits for a free buffer for longer than this is dropped (counted).
constexpr qint64 kBufferWaitMs = 100;
// After this long without success, dmabuf is tried again once it was given up on.
constexpr int kHealMs = 30000;

qint64 nowMs() {
	return std::chrono::duration_cast<std::chrono::milliseconds>(
	           std::chrono::steady_clock::now().time_since_epoch()
	)
	    .count();
}

QtWaylandClient::QWaylandWindow* waylandWindowOf(QQuickWindow* window) {
	if (!window || !window->handle()) return nullptr;
	return dynamic_cast<QtWaylandClient::QWaylandWindow*>(window->handle());
}

// The GPU the compositor renders on, as far as we can know: the first render node, or the one
// named by GLASS_RENDER_NODE.
gbm_device* glassGbm() {
	static gbm_device* device = nullptr;
	static bool tried = false;
	if (tried) return device;
	tried = true;

	QList<QByteArray> nodes;
	if (auto env = qgetenv("GLASS_RENDER_NODE"); !env.isEmpty()) nodes << env;
	else
		for (int i = 128; i < 136; i++) nodes << QByteArray("/dev/dri/renderD") + QByteArray::number(i);

	for (const auto& node: nodes) {
		int fd = open(node.constData(), O_RDWR | O_CLOEXEC);
		if (fd < 0) continue;
		device = gbm_create_device(fd);
		if (device) {
			qCInfo(logGlass) << "glass capture: allocating dmabufs on" << node;
			return device;
		}
		close(fd);
	}
	return nullptr;
}

PFNEGLCREATEIMAGEKHRPROC eglCreateImage_ = nullptr;
PFNEGLDESTROYIMAGEKHRPROC eglDestroyImage_ = nullptr;
PFNGLEGLIMAGETARGETTEXTURE2DOESPROC glImageTarget_ = nullptr;
PFNEGLCREATESYNCKHRPROC eglCreateSync_ = nullptr;
PFNEGLCLIENTWAITSYNCKHRPROC eglClientWaitSync_ = nullptr;
PFNEGLDESTROYSYNCKHRPROC eglDestroySync_ = nullptr;
bool fencesAvailable = false;

// Needs the EGL display of Qt's render thread.
bool loadGlFunctions(EGLDisplay dpy) {
	static bool loaded = false;
	if (!loaded) {
		loaded = true;
		eglCreateImage_ = reinterpret_cast<PFNEGLCREATEIMAGEKHRPROC>(eglGetProcAddress("eglCreateImageKHR"));
		eglDestroyImage_ = reinterpret_cast<PFNEGLDESTROYIMAGEKHRPROC>(eglGetProcAddress("eglDestroyImageKHR"));
		glImageTarget_ =
		    reinterpret_cast<PFNGLEGLIMAGETARGETTEXTURE2DOESPROC>(eglGetProcAddress("glEGLImageTargetTexture2DOES"));

		const char* extensions = dpy != EGL_NO_DISPLAY ? eglQueryString(dpy, EGL_EXTENSIONS) : nullptr;
		if (extensions && strstr(extensions, "EGL_KHR_fence_sync")) {
			eglCreateSync_ = reinterpret_cast<PFNEGLCREATESYNCKHRPROC>(eglGetProcAddress("eglCreateSyncKHR"));
			eglClientWaitSync_ = reinterpret_cast<PFNEGLCLIENTWAITSYNCKHRPROC>(eglGetProcAddress("eglClientWaitSyncKHR"));
			eglDestroySync_ = reinterpret_cast<PFNEGLDESTROYSYNCKHRPROC>(eglGetProcAddress("eglDestroySyncKHR"));
			fencesAvailable = eglCreateSync_ && eglClientWaitSync_ && eglDestroySync_;
		}
		if (!fencesAvailable)
			qCWarning(logGlass) << "glass capture: no EGL fences; retired buffers are held for" << kHoldMs << "ms instead";
	}
	return eglCreateImage_ && eglDestroyImage_ && glImageTarget_;
}

// Frees GL objects of dmabufs on the render thread.
class DestroyDmaJob: public QRunnable {
public:
	struct Item {
		void* image;
		unsigned int texture;
	};
	explicit DestroyDmaJob(std::vector<Item> items): items(std::move(items)) {}
	void run() override {
		auto dpy = eglGetCurrentDisplay();
		for (auto& item: this->items) {
			if (item.texture) glDeleteTextures(1, &item.texture);
			if (item.image && dpy != EGL_NO_DISPLAY && eglDestroyImage_) eglDestroyImage_(dpy, item.image);
		}
	}

private:
	std::vector<Item> items;
};

class DeleteProviderJob: public QRunnable {
public:
	explicit DeleteProviderJob(GlassTextureProvider* provider): provider(provider) {}
	void run() override { delete this->provider; }

private:
	GlassTextureProvider* provider;
};

} // namespace

// ---------------------------------------------------------------- managers

GlassScreencopyManager::GlassScreencopyManager(): QWaylandClientExtensionTemplate(3) {
	this->initialize();
}

GlassScreencopyManager* GlassScreencopyManager::instance() {
	static auto* instance = new GlassScreencopyManager();
	return instance;
}

GlassDmabufManager::GlassDmabufManager(): QWaylandClientExtensionTemplate(3) {
	this->initialize();
}

GlassDmabufManager* GlassDmabufManager::instance() {
	static auto* instance = new GlassDmabufManager();
	return instance;
}

void GlassDmabufManager::zwp_linux_dmabuf_v1_modifier(uint32_t format, uint32_t modifierHi, uint32_t modifierLo) {
	this->mModifiers[format].append((uint64_t(modifierHi) << 32) | modifierLo);
}

bool GlassDmabufManager::acceptsLinear(uint32_t format) const {
	const auto mods = this->mModifiers.value(format);
	return mods.contains(DRM_FORMAT_MOD_LINEAR) || mods.contains(DRM_FORMAT_MOD_INVALID);
}

// ------------------------------------------------------------------ frame

GlassFrame::~GlassFrame() {
	if (this->isInitialized()) this->destroy();
}

void GlassFrame::zwlr_screencopy_frame_v1_buffer(
    uint32_t format,
    uint32_t width,
    uint32_t height,
    uint32_t stride
) {
	// Only the usual formats (four bytes, blue first). The first one offered wins.
	if (this->formatOk) return;
	if (format != WL_SHM_FORMAT_ARGB8888 && format != WL_SHM_FORMAT_XRGB8888) return;
	this->format = format;
	this->width = width;
	this->height = height;
	this->stride = stride;
	this->formatOk = true;
}

void GlassFrame::zwlr_screencopy_frame_v1_flags(uint32_t flags) {
	this->yInvert = flags & ZWLR_SCREENCOPY_FRAME_V1_FLAGS_Y_INVERT;
}

// Hyprland 0.56.2 always reports the whole buffer here ("TODO: damage ring" in its source), so the
// events say nothing about what changed; they are counted to show that.
void GlassFrame::zwlr_screencopy_frame_v1_damage(uint32_t, uint32_t, uint32_t width, uint32_t height) {
	this->damageRects++;
	const uint32_t w = this->dmaOffered ? this->dmaWidth : this->width;
	const uint32_t h = this->dmaOffered ? this->dmaHeight : this->height;
	if (width >= w && height >= h) this->damageFull++;
}

void GlassFrame::zwlr_screencopy_frame_v1_linux_dmabuf(uint32_t format, uint32_t width, uint32_t height) {
	this->dmaOffered = true;
	this->dmaFormat = format;
	this->dmaWidth = width;
	this->dmaHeight = height;
}

void GlassFrame::zwlr_screencopy_frame_v1_buffer_done() {
	if (this->owner) this->owner->frameBufferDone(this);
}

void GlassFrame::zwlr_screencopy_frame_v1_ready(uint32_t, uint32_t, uint32_t) {
	if (this->owner) this->owner->frameReady(this);
}

void GlassFrame::zwlr_screencopy_frame_v1_failed() {
	if (this->owner) this->owner->frameFailed(this);
}

// ------------------------------------------------------------ capture item

GlassCapture::GlassCapture(QQuickItem* parent): QQuickItem(parent) {
	this->setFlag(QQuickItem::ItemHasContents, true);
	this->mTimer.setSingleShot(true);
	QObject::connect(&this->mTimer, &QTimer::timeout, this, &GlassCapture::pump);
	this->mBufferTimer.setSingleShot(true);
	QObject::connect(&this->mBufferTimer, &QTimer::timeout, this, &GlassCapture::retryWaiting);
	this->mWarmupTimer.setSingleShot(true);
	QObject::connect(&this->mWarmupTimer, &QTimer::timeout, this, &GlassCapture::warmupEnded);
	this->mHealTimer.setSingleShot(true);
	QObject::connect(&this->mHealTimer, &QTimer::timeout, this, &GlassCapture::healDmabuf);
}

GlassCapture::~GlassCapture() {
	this->cancelFrames();
	this->destroyDmaPool();
}

void GlassCapture::setActive(bool active) {
	if (active == this->mActive) return;
	this->mActive = active;
	if (!active) this->cancelFrames();
	else QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
	emit this->activeChanged();
}

void GlassCapture::setRegion(const QRectF& region) {
	if (region == this->mRegion) return;
	this->mRegion = region;
	// What is in flight was taken for another box.
	this->cancelFrames();
	emit this->regionChanged();
	if (this->mActive) QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
}

void GlassCapture::setMinInterval(int ms) {
	if (ms == this->mMinInterval) return;
	this->mMinInterval = ms;
	emit this->minIntervalChanged();
	emit this->statsChanged();
}

void GlassCapture::setDepth(int depth) {
	depth = std::clamp(depth, 1, 6);
	if (depth == this->mDepth) return;
	this->mDepth = depth;
	emit this->depthChanged();
}

void GlassCapture::setAllowDmabuf(bool allow) {
	if (allow == this->mAllowDmabuf) return;
	this->mAllowDmabuf = allow;
	this->mDmaBroken.store(false);
	this->mConsecutiveAllocFailures = 0;
	this->mConsecutiveImportFailures = 0;
	emit this->allowDmabufChanged();
}

void GlassCapture::setPublishing(bool publishing) {
	if (publishing == this->mPublishing) return;
	this->mPublishing = publishing;
	emit this->publishingChanged();
}

void GlassCapture::setWholeOutput(bool whole) {
	if (whole == this->mWholeOutput) return;
	this->mWholeOutput = whole;
	this->cancelFrames();
	emit this->wholeOutputChanged();
	if (this->mActive) QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
}

void GlassCapture::setHeld(bool held) {
	if (held == this->mHeld) return;
	this->mHeld = held;
	if (held) this->cancelFrames();
	else QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
	emit this->heldChanged();
}

void GlassCapture::setPoolLimit(int limit) {
	limit = std::max(limit, 0);
	if (limit == this->mPoolLimit) return;
	this->mPoolLimit = limit;
	emit this->poolLimitChanged();
}

// The compositor fades a layer in when it appears; what is unmixed from those first captures is
// not to be trusted. Until it is over, captures are published at most ten per second, and one more
// is published once it ends (see warmupEnded()).
bool GlassCapture::warming() const {
	return this->mReceived < 3 || (this->mBorn.isValid() && this->mBorn.elapsed() < 1500);
}

void GlassCapture::warmupEnded() {
	this->mForcePublish = true;
	// Make a frame, so that the capture that is waiting is answered even if nothing else changes.
	if (this->window()) this->window()->update();
}

qreal GlassCapture::effectiveInterval() const {
	if (this->mMinInterval > 0) return this->mMinInterval;
	auto* w = this->window();
	auto* screen = w ? w->screen() : nullptr;
	auto hz = screen ? screen->refreshRate() : 60.0;
	if (hz < 1.0) hz = 60.0;
	return 1000.0 / hz;
}

qreal GlassCapture::pixelRatio() const {
	auto* w = this->window();
	// devicePixelRatio(), not effectiveDevicePixelRatio(): that one is rounded up to a whole
	// number here (2), while the window really renders at the fractional scale (checked with
	// grabWindow(): 1920x68 for 1440x51 logical).
	return w ? w->devicePixelRatio() : 1.0;
}

QColor GlassCapture::readPixel(const QVariant& image, int x, int y) const {
	auto img = image.value<QImage>();
	if (img.isNull() || x < 0 || y < 0 || x >= img.width() || y >= img.height()) return QColor();
	return img.pixelColor(x, y);
}

void GlassCapture::nudge() {
	this->pump();
}

void GlassCapture::setStatus(const QString& status) {
	if (status == this->mStatus) return;
	this->mStatus = status;
	if (!status.isEmpty()) qCWarning(logGlass) << "glass capture:" << status;
	emit this->statusChanged();
}

QVariantMap GlassCapture::diagnostics() const {
	int free = 0, inFlight = 0, pending = 0, shown = 0, retiring = 0;
	for (auto* b: this->mDmaPool) {
		switch (b->state) {
		case GlassDmaBuffer::State::Free: free++; break;
		case GlassDmaBuffer::State::InFlight: inFlight++; break;
		case GlassDmaBuffer::State::Pending: pending++; break;
		case GlassDmaBuffer::State::Shown: shown++; break;
		case GlassDmaBuffer::State::Retiring: retiring++; break;
		}
	}

	QVariantMap m;
	// Requests and completions.
	m["requests"] = this->mRequests;
	m["copiesAsked"] = this->mCopiesAsked;
	m["completions"] = this->mReceived;
	m["compositorFailed"] = this->mFailed;
	m["cancelled"] = this->mCancelled;
	m["inFlight"] = int(this->mFrames.size());
	// What became of the completions.
	m["duplicates"] = this->mDuplicates;
	m["published"] = this->mSerial;
	m["warmupDropped"] = this->mWarmupDropped;
	// Damage events (Hyprland 0.56.2 always sends the whole buffer).
	m["damageEvents"] = this->mDamageEvents;
	m["damageFull"] = this->mDamageFull;
	// Buffers.
	m["poolSize"] = int(this->mDmaPool.size());
	m["poolFree"] = free;
	m["poolInFlight"] = inFlight;
	m["poolPending"] = pending;
	m["poolShown"] = shown;
	m["poolRetiring"] = retiring;
	m["poolExhausted"] = this->mPoolExhausted;
	m["bufferWaitTimeouts"] = this->mBufferWaitTimeouts;
	m["allocFailures"] = this->mAllocFailures;
	m["importFailures"] = this->mImportFailures;
	m["fallbackActivations"] = this->mFallbackActivations;
	m["heals"] = this->mHeals;
	m["fencesWaited"] = this->mFencesWaited;
	m["timedRetired"] = this->mTimedRetired;
	m["fencesAvailable"] = fencesAvailable;
	m["dmabufBroken"] = this->mDmaBroken.load();
	m["usingDmabuf"] = this->mUsingDmabuf;
	m["lastWholeOutput"] = this->mLastWholeOutput;
	m["frames"] = this->mFramesSwapped.load();
	m["latency"] = this->mLatency;
	m["setupLatency"] = this->mSetup;
	return m;
}

void GlassCapture::itemChange(ItemChange change, const ItemChangeData& data) {
	if (change == ItemSceneChange) this->bindWindow(data.window);
	this->QQuickItem::itemChange(change, data);
}

void GlassCapture::bindWindow(QQuickWindow* window) {
	QObject::disconnect(this->mSwapConnection);
	QObject::disconnect(this->mSyncConnection);
	if (!window) return;

	// Both signals come from the render thread (or the GUI thread with a basic render loop).
	// A scene synchronisation always happens between two frames of the render thread, so the
	// count read when a frame was swapped is the count of the synchronisation of that frame.
	this->mSyncConnection = QObject::connect(
	    window,
	    &QQuickWindow::beforeSynchronizing,
	    this,
	    [this]() { this->mSyncs.fetch_add(1); },
	    Qt::DirectConnection
	);
	this->mSwapConnection = QObject::connect(
	    window,
	    &QQuickWindow::frameSwapped,
	    this,
	    [this]() {
		    this->mFramesSwapped.fetch_add(1);
		    const int syncs = this->mSyncs.load();
		    QMetaObject::invokeMethod(
		        this,
		        [this, syncs]() { this->onFrameSwapped(syncs); },
		        Qt::QueuedConnection
		    );
	    },
	    Qt::DirectConnection
	);
	QObject::connect(window, &QWindow::screenChanged, this, &GlassCapture::pixelRatioChanged, Qt::UniqueConnection);
	QObject::connect(
	    window,
	    &QQuickWindow::sceneGraphInvalidated,
	    this,
	    [this]() { this->mProvider = nullptr; },
	    Qt::DirectConnection
	);
	emit this->pixelRatioChanged();
	if (this->mActive) QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
}

// The window learns its fractional scale after it has been created, and Qt does not say so.
void GlassCapture::checkRatio() {
	const auto ratio = this->pixelRatio();
	if (!qFuzzyCompare(ratio, this->mRatio)) {
		this->mRatio = ratio;
		emit this->pixelRatioChanged();
	}
}

void GlassCapture::onFrameSwapped(int syncSerial) {
	this->checkRatio();
	emit this->swapped(syncSerial);
	this->pump();
}

void GlassCapture::pump() {
	if (!this->mActive || this->mHeld) return;
	auto* w = this->window();
	if (!w) return;

	auto* wlw = waylandWindowOf(w);
	if (!wlw || !wlw->waylandScreen() || !wlw->waylandScreen()->output()) {
		this->setStatus(QStringLiteral("window not on an output yet"));
		this->mTimer.start(200);
		return;
	}

	auto* manager = GlassScreencopyManager::instance();
	if (!manager->isActive()) {
		this->setStatus(QStringLiteral("compositor does not offer zwlr_screencopy_manager_v1"));
		return;
	}

	// One capture is on its way at a time (a request that waits for a free buffer counts).
	if (this->mFrames.size() >= this->mDepth) return;

	// Not more than one per refresh period.
	if (this->mHasStarted) {
		auto left = this->effectiveInterval() - double(this->mSinceStart.nsecsElapsed()) / 1e6;
		if (left > 0.5) {
			this->mTimer.start(int(std::ceil(left)));
			return;
		}
	}

	this->start();
}

void GlassCapture::start() {
	auto* w = this->window();
	auto* wlw = waylandWindowOf(w);
	if (!wlw) return;
	auto* output = wlw->waylandScreen()->output();

	const auto r = this->mRegion.toAlignedRect();
	if (r.isEmpty()) {
		this->setStatus(QStringLiteral("empty capture region"));
		return;
	}

	auto* manager = GlassScreencopyManager::instance();
	// Always with damage: a plain copy makes Hyprland redraw the whole monitor.
	auto* frame = new GlassFrame(this, true);
	// overlay_cursor = 0: the glass does not refract the cursor, it goes on top.
	frame->wholeOutput = this->mWholeOutput && this->dmabufUsable();
	if (!frame->wholeOutput && !qFuzzyCompare(this->pixelRatio(), 1.0) && !this->mWarnedRegion) {
		this->mWarnedRegion = true;
		qCWarning(logGlass) << "glass capture: asking for a region at scale" << this->pixelRatio()
		                    << "- Hyprland 0.56 then makes a new screenshare session for every request and never frees it";
	}
	if (frame->wholeOutput) frame->init(manager->capture_output(0, output));
	else frame->init(manager->capture_output_region(0, output, r.x(), r.y(), r.width(), r.height()));
	frame->started.start();
	this->mFrames.append(frame);
	this->mRequests++;
	wl_display_flush(wlw->display()->wl_display());

	this->mSinceStart.start();
	this->mHasStarted = true;
	if (!this->mBorn.isValid()) {
		this->mBorn.start();
		this->mWarmupTimer.start(1500);
	}
	this->setStatus(QString());

	// Room for another one? (Only with a depth above one.)
	if (this->mFrames.size() < this->mDepth) this->mTimer.start(int(std::ceil(this->effectiveInterval())));
}

// ------------------------------------------------------------ buffers

bool GlassCapture::dmabufUsable() const {
	if (!this->mAllowDmabuf || this->mDmaBroken.load()) return false;
	auto* w = this->window();
	if (!w || !w->isSceneGraphInitialized()) return false;
	auto* ri = w->rendererInterface();
	if (!ri || ri->graphicsApi() != QSGRendererInterface::OpenGL) return false;
	if (!glassGbm()) return false;
	return GlassDmabufManager::instance()->isActive();
}

// Dmabuf is given up on only for hard reasons (a format or modifier the compositor does not take,
// allocation or import that keeps failing), never because the pool was in use. Shared memory then
// takes over, loudly, and dmabuf is tried again after a while.
void GlassCapture::giveUpOnDmabuf(const QString& why) {
	if (this->mDmaBroken.exchange(true)) return;
	this->mFallbackActivations++;
	qCWarning(logGlass) << "glass capture: giving up on dmabuf (" << why << ") - falling back to shared memory, trying again in" << kHealMs / 1000 << "s";
	this->mHealTimer.start(kHealMs);
	emit this->statsChanged();
}

void GlassCapture::healDmabuf() {
	if (!this->mDmaBroken.exchange(false)) return;
	this->mHeals++;
	this->mConsecutiveAllocFailures = 0;
	this->mConsecutiveImportFailures = 0;
	qCWarning(logGlass) << "glass capture: trying dmabuf again";
	this->cancelFrames();
	this->pump();
}

// Gives back the retired buffers that nothing can be using any more.
void GlassCapture::reapRetired() {
	const auto now = nowMs();
	auto* dpy = this->mEglDisplay.load();
	for (auto* b: this->mDmaPool) {
		if (b->state != GlassDmaBuffer::State::Retiring) continue;
		if (b->fence) {
			if (!dpy || !eglClientWaitSync_) continue;
			// Zero timeout: a poll. Signalled means every GPU command issued before the fence was
			// made, the ones that read this buffer included, has finished.
			if (eglClientWaitSync_(dpy, b->fence, 0, 0) == EGL_CONDITION_SATISFIED_KHR) {
				eglDestroySync_(dpy, b->fence);
				b->fence = nullptr;
				b->state = GlassDmaBuffer::State::Free;
				this->mFencesWaited++;
			}
		} else if (b->holdUntilMs && now >= b->holdUntilMs) {
			b->holdUntilMs = 0;
			b->state = GlassDmaBuffer::State::Free;
			this->mTimedRetired++;
		}
	}
}

// Render thread, in the scene synchronisation that replaces the texture: a fence made now signals
// when everything the GPU was given before, the frames that sampled `buffer` included, is done.
void GlassCapture::retireOnRenderThread(GlassDmaBuffer* buffer) {
	buffer->state = GlassDmaBuffer::State::Retiring;
	buffer->fence = nullptr;
	buffer->holdUntilMs = 0;
	auto dpy = eglGetCurrentDisplay();
	if (fencesAvailable && dpy != EGL_NO_DISPLAY) {
		buffer->fence = eglCreateSync_(dpy, EGL_SYNC_FENCE_KHR, nullptr);
		// Without this the fence might not be submitted until something else flushes.
		glFlush();
	}
	if (!buffer->fence) buffer->holdUntilMs = nowMs() + kHoldMs;
}

GlassDmaBuffer* GlassCapture::acquireDma(uint32_t format, uint32_t width, uint32_t height, DmaResult* result) {
	this->reapRetired();
	for (auto* b: this->mDmaPool) {
		if (b->state != GlassDmaBuffer::State::Free || b->format != format || b->width != width || b->height != height) continue;
		b->state = GlassDmaBuffer::State::InFlight;
		*result = DmaResult::Ok;
		return b;
	}
	// Buffers of another size (the mode or the monitor changed) are of no use any more.
	this->trimDmaPool(format, width, height);

	const int limit = this->mPoolLimit > 0 ? this->mPoolLimit : kDefaultPoolLimit;
	if (int(this->mDmaPool.size()) >= limit) {
		*result = DmaResult::Exhausted;
		return nullptr;
	}

	*result = DmaResult::AllocFailed;
	auto* dev = glassGbm();
	auto* bo = gbm_bo_create(dev, width, height, format, GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR);
	if (!bo) return nullptr;
	if (gbm_bo_get_plane_count(bo) != 1) {
		gbm_bo_destroy(bo);
		return nullptr;
	}

	auto* b = new GlassDmaBuffer();
	b->bo = bo;
	b->format = format;
	b->width = width;
	b->height = height;
	b->stride = gbm_bo_get_stride(bo);
	b->offset = gbm_bo_get_offset(bo, 0);
	b->modifier = gbm_bo_get_modifier(bo);
	b->fd = gbm_bo_get_fd(bo);
	if (b->fd < 0) {
		gbm_bo_destroy(bo);
		delete b;
		return nullptr;
	}

	auto* params = GlassDmabufManager::instance()->create_params();
	zwp_linux_buffer_params_v1_add(params, b->fd, 0, b->offset, b->stride, uint32_t(b->modifier >> 32), uint32_t(b->modifier & 0xffffffff));
	b->buffer = zwp_linux_buffer_params_v1_create_immed(params, int(width), int(height), format, 0);
	zwp_linux_buffer_params_v1_destroy(params);
	if (!b->buffer) {
		close(b->fd);
		gbm_bo_destroy(bo);
		delete b;
		return nullptr;
	}

	// A look at it from the CPU, to tell whether anything changed (linear: this is cheap to do).
	b->mapLength = size_t(b->stride) * height;
	void* map = mmap(nullptr, b->mapLength, PROT_READ, MAP_SHARED, b->fd, 0);
	if (map != MAP_FAILED) b->map = static_cast<const uchar*>(map);

	b->state = GlassDmaBuffer::State::InFlight;
	this->mDmaPool.push_back(b);
	*result = DmaResult::Ok;
	return b;
}

void GlassCapture::trimDmaPool(uint32_t format, uint32_t width, uint32_t height) {
	std::vector<DestroyDmaJob::Item> items;
	for (auto it = this->mDmaPool.begin(); it != this->mDmaPool.end();) {
		auto* b = *it;
		const bool other = b->format != format || b->width != width || b->height != height;
		if (!other || b->state != GlassDmaBuffer::State::Free) {
			++it;
			continue;
		}
		if (b->eglImage || b->texture) items.push_back({b->eglImage, b->texture});
		if (b->map) munmap(const_cast<uchar*>(b->map), b->mapLength);
		if (b->buffer) wl_buffer_destroy(b->buffer);
		if (b->fd >= 0) close(b->fd);
		if (b->bo) gbm_bo_destroy(b->bo);
		delete b;
		it = this->mDmaPool.erase(it);
	}
	if (!items.empty() && this->window())
		this->window()->scheduleRenderJob(new DestroyDmaJob(std::move(items)), QQuickWindow::AfterSynchronizingStage);
}

void GlassCapture::destroyDmaPool() {
	std::vector<DestroyDmaJob::Item> items;
	auto* dpy = this->mEglDisplay.load();
	for (auto* b: this->mDmaPool) {
		if (b->fence && dpy && eglDestroySync_) eglDestroySync_(dpy, b->fence);
		if (b->eglImage || b->texture) items.push_back({b->eglImage, b->texture});
		if (b->map) munmap(const_cast<uchar*>(b->map), b->mapLength);
		if (b->buffer) wl_buffer_destroy(b->buffer);
		if (b->fd >= 0) close(b->fd);
		if (b->bo) gbm_bo_destroy(b->bo);
		delete b;
	}
	this->mDmaPool.clear();
	this->mCurrentDma = nullptr;
	this->mPendingDma = nullptr;
	if (!items.empty() && this->window())
		this->window()->scheduleRenderJob(new DestroyDmaJob(std::move(items)), QQuickWindow::AfterSynchronizingStage);
}

GlassCapture::DmaResult GlassCapture::ensureDmaBuffer(GlassFrame* frame) {
	if (!frame->dmaOffered) return DmaResult::Unsupported;
	if (frame->dmaFormat != DRM_FORMAT_XRGB8888 && frame->dmaFormat != DRM_FORMAT_ARGB8888) return DmaResult::Unsupported;
	if (!GlassDmabufManager::instance()->acceptsLinear(frame->dmaFormat)) return DmaResult::Unsupported;

	auto result = DmaResult::AllocFailed;
	frame->dma = this->acquireDma(frame->dmaFormat, frame->dmaWidth, frame->dmaHeight, &result);
	return result;
}

bool GlassCapture::ensureShmBuffer(GlassFrame* frame) {
	if (!frame->formatOk) return false;
	if (frame->buffer) return true;

	auto* wlw = waylandWindowOf(this->window());
	if (!wlw || !wlw->display() || !wlw->display()->shm()) return false;
	auto* shm = wlw->display()->shm()->object();
	if (!shm) return false;

	const size_t length = size_t(frame->stride) * frame->height;
	int fd = memfd_create("glass-capture", MFD_CLOEXEC);
	if (fd < 0) return false;
	if (ftruncate(fd, off_t(length)) != 0) {
		close(fd);
		return false;
	}
	void* data = mmap(nullptr, length, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (data == MAP_FAILED) {
		close(fd);
		return false;
	}

	auto* pool = wl_shm_create_pool(shm, fd, int(length));
	close(fd);
	if (!pool) {
		munmap(data, length);
		return false;
	}
	auto* buffer = wl_shm_pool_create_buffer(
	    pool,
	    0,
	    int(frame->width),
	    int(frame->height),
	    int(frame->stride),
	    frame->format
	);
	wl_shm_pool_destroy(pool);
	if (!buffer) {
		munmap(data, length);
		return false;
	}

	frame->data = static_cast<uchar*>(data);
	frame->length = length;
	frame->buffer = buffer;
	return true;
}

// Forgets a capture: it is destroyed (the compositor drops it if it is not done). A buffer the
// compositor may still be writing into is held back for a while; one it never touched, or one it
// has finished, is free at once.
void GlassCapture::dropFrame(GlassFrame* frame) {
	this->mFrames.removeOne(frame);
	if (this->mWaiting == frame) this->mWaiting = nullptr;
	frame->owner = nullptr;
	const bool maybeBusy = frame->copyAsked && !frame->done;

	if (frame->dma) {
		auto* dma = frame->dma;
		frame->dma = nullptr;
		if (maybeBusy) {
			dma->state = GlassDmaBuffer::State::Retiring;
			dma->fence = nullptr;
			dma->holdUntilMs = nowMs() + kHoldMs;
		} else {
			dma->state = GlassDmaBuffer::State::Free;
		}
	}

	auto* buffer = frame->buffer;
	auto* data = frame->data;
	const auto length = frame->length;
	delete frame;

	if (!buffer) return;
	auto release = [buffer, data, length]() {
		wl_buffer_destroy(buffer);
		munmap(data, length);
	};
	if (maybeBusy && qApp) QTimer::singleShot(1000, qApp, release);
	else release();
}

void GlassCapture::cancelFrames() {
	while (!this->mFrames.isEmpty()) {
		this->mCancelled++;
		this->dropFrame(this->mFrames.first());
	}
}

// The compositor has named the buffer it wants. Dmabuf: take one from the pool; none free is no
// reason to give up, the capture waits a moment for one. Shared memory only for a region capture
// (dmabuf given up on, or not available at all).
bool GlassCapture::prepareBuffer(GlassFrame* frame) {
	if (frame->wholeOutput || this->dmabufUsable()) {
		if (!this->dmabufUsable()) {
			// Dmabuf was given up on while this whole-output capture was on its way.
			this->mCancelled++;
			this->dropFrame(frame);
			this->mTimer.start(10);
			return false;
		}

		switch (this->ensureDmaBuffer(frame)) {
		case DmaResult::Ok: this->mConsecutiveAllocFailures = 0; return true;
		case DmaResult::Exhausted:
			this->mPoolExhausted++;
			frame->waiting = true;
			frame->waitStarted.start();
			this->mWaiting = frame;
			this->mBufferTimer.start(2);
			return false;
		case DmaResult::Unsupported:
			this->giveUpOnDmabuf(QStringLiteral("the compositor offers no usable dmabuf format"));
			this->mCancelled++;
			this->dropFrame(frame);
			this->mTimer.start(10);
			return false;
		case DmaResult::AllocFailed:
			this->mAllocFailures++;
			if (++this->mConsecutiveAllocFailures >= 4) this->giveUpOnDmabuf(QStringLiteral("allocation keeps failing"));
			this->frameFailed(frame);
			return false;
		}
		return false;
	}

	if (this->ensureShmBuffer(frame)) return true;
	this->frameFailed(frame);
	return false;
}

void GlassCapture::askCopy(GlassFrame* frame) {
	frame->copyAsked = true;
	this->mCopiesAsked++;
	auto* buffer = frame->dma ? frame->dma->buffer : frame->buffer;
	if (frame->onDamage) frame->copy_with_damage(buffer);
	else frame->copy(buffer);

	if (auto* wlw = waylandWindowOf(this->window())) wl_display_flush(wlw->display()->wl_display());
}

void GlassCapture::frameBufferDone(GlassFrame* frame) {
	if (!this->mFrames.contains(frame)) return;
	this->mSetup = double(frame->started.nsecsElapsed()) / 1e6;
	if (!this->prepareBuffer(frame)) return;
	this->askCopy(frame);
}

// A capture that was waiting for a free buffer tries again.
void GlassCapture::retryWaiting() {
	auto* frame = this->mWaiting;
	if (!frame || !this->mFrames.contains(frame)) {
		this->mWaiting = nullptr;
		return;
	}

	if (frame->waitStarted.elapsed() > kBufferWaitMs) {
		// Counted, dropped, and asked for again: the glass keeps what it has meanwhile.
		this->mBufferWaitTimeouts++;
		this->mCancelled++;
		this->dropFrame(frame);
		this->mTimer.start(10);
		return;
	}

	switch (this->ensureDmaBuffer(frame)) {
	case DmaResult::Ok:
		frame->waiting = false;
		this->mWaiting = nullptr;
		this->mConsecutiveAllocFailures = 0;
		this->askCopy(frame);
		return;
	case DmaResult::Exhausted: this->mBufferTimer.start(2); return;
	case DmaResult::Unsupported:
		this->giveUpOnDmabuf(QStringLiteral("the compositor offers no usable dmabuf format"));
		this->mCancelled++;
		this->dropFrame(frame);
		this->mTimer.start(10);
		return;
	case DmaResult::AllocFailed:
		this->mAllocFailures++;
		if (++this->mConsecutiveAllocFailures >= 4) this->giveUpOnDmabuf(QStringLiteral("allocation keeps failing"));
		this->frameFailed(frame);
		return;
	}
}

void GlassCapture::frameFailed(GlassFrame* frame) {
	if (!this->mFrames.contains(frame)) return;
	this->dropFrame(frame);
	this->mFailed++;
	emit this->statsChanged();
	// Try again soon, but not in a hot loop.
	this->mTimer.start(100);
}

// Has anything changed since the capture that is shown? A few thousand bytes are compared; a
// small change that does not touch any of them is caught by the next one that does.
bool GlassCapture::sameAsBefore(const uchar* bits, qsizetype bytes, QSize size, bool linear, int stride, QRect crop) {
	std::vector<uchar> sample;
	if (linear) {
		// Inside the crop: every second row, every 61st pixel.
		const int rowStep = 2;
		const int pixelStep = 61;
		for (int y = crop.top(); y <= crop.bottom(); y += rowStep) {
			const uchar* row = bits + size_t(y) * stride;
			for (int x = crop.left(); x <= crop.right(); x += pixelStep) sample.push_back(row[x * 4 + 1]);
		}
	} else {
		sample.reserve(size_t(bytes / 13) + 1);
		for (qsizetype i = 0; i < bytes; i += 13) sample.push_back(bits[i]);
	}

	bool same = !this->mCaptureSize.isEmpty() && sample.size() == this->mSample.size()
	         && this->mRegion == this->mSampleRegion && crop.size() == this->mCaptureSize;
	if (same) {
		for (size_t i = 0; i < sample.size(); i++) {
			if (std::abs(int(sample[i]) - int(this->mSample[i])) > 3) {
				same = false;
				break;
			}
		}
	}
	this->mNewSample = std::move(sample);
	return same;
}

// Where the region is inside a capture of `buffer` pixels: the capture is of the whole output (the
// region scaled by the buffer over the output's logical size) or of the region itself.
QRect GlassCapture::cropFor(QSize buffer, bool wholeOutput) const {
	const QRect all(QPoint(0, 0), buffer);
	if (!wholeOutput) return all;
	auto* wlw = waylandWindowOf(this->window());
	if (!wlw || !wlw->waylandScreen()) return all;
	const auto logical = wlw->waylandScreen()->geometry().size();
	if (logical.isEmpty()) return all;
	const double sx = double(buffer.width()) / logical.width();
	const double sy = double(buffer.height()) / logical.height();
	const auto r = this->mRegion.toAlignedRect();
	QRect crop(qRound(r.x() * sx), qRound(r.y() * sy), qRound(r.width() * sx), qRound(r.height() * sy));
	return crop.intersected(all);
}

void GlassCapture::publish(QSize size, QRectF cropUv) {
	this->mSample = std::move(this->mNewSample);
	this->mSampleRegion = this->mRegion;
	this->mCaptureSize = size;
	this->mCropUv = cropUv;
	this->mTextureDirty = true;
	this->mSerial++;
	this->mLastPublish.start();
	this->update();
	emit this->serialChanged();
	emit this->statsChanged();
	emit this->captured(this->mSerial);
}

void GlassCapture::frameReady(GlassFrame* frame) {
	if (!this->mFrames.contains(frame)) return;

	frame->done = true;
	this->mLatency = double(frame->started.nsecsElapsed()) / 1e6;
	this->mLastWholeOutput = frame->wholeOutput;
	this->mReceived++;
	this->mDamageEvents += frame->damageRects;
	this->mDamageFull += frame->damageFull;
	if (this->mLastReady.isValid()) this->mCycle = double(this->mLastReady.nsecsElapsed()) / 1e6;
	this->mLastReady.start();

	if (!this->mPublishing) {
		// Measuring: the capture arrived, and that is all.
		this->dropFrame(frame);
		emit this->statsChanged();
		this->pump();
		return;
	}

	const bool warm = this->warming();
	const bool forced = this->mForcePublish && !warm;

	if (frame->dma) {
		auto* dma = frame->dma;
		frame->dma = nullptr;
		const QSize buffer(int(dma->width), int(dma->height));
		const QRect crop = this->cropFor(buffer, frame->wholeOutput);
		bool same = false;
		if (dma->map) {
			dma_buf_sync sync {};
			sync.flags = DMA_BUF_SYNC_START | DMA_BUF_SYNC_READ;
			ioctl(dma->fd, DMA_BUF_IOCTL_SYNC, &sync);
			same = this->sameAsBefore(dma->map, qsizetype(dma->mapLength), buffer, true, int(dma->stride), crop);
			sync.flags = DMA_BUF_SYNC_END | DMA_BUF_SYNC_READ;
			ioctl(dma->fd, DMA_BUF_IOCTL_SYNC, &sync);
		} else {
			this->mNewSample.clear();
		}
		this->dropFrame(frame);

		if (same && !forced) {
			// The compositor is done with it and the GPU never saw it: free at once.
			dma->state = GlassDmaBuffer::State::Free;
			this->mDuplicates++;
			emit this->statsChanged();
			this->pump();
			return;
		}

		if (warm && this->mSerial > 0 && this->mLastPublish.isValid() && this->mLastPublish.elapsed() < 100) {
			// During the warm-up at most ten captures a second are published.
			dma->state = GlassDmaBuffer::State::Free;
			this->mWarmupDropped++;
			emit this->statsChanged();
			this->pump();
			return;
		}

		// Published. A capture that was published but not yet imported is replaced by this one:
		// the GPU never saw it either.
		if (this->mPendingDma) this->mPendingDma->state = GlassDmaBuffer::State::Free;
		this->mPendingDma = dma;
		dma->state = GlassDmaBuffer::State::Pending;
		this->mImage = QImage();
		this->mUsingDmabuf = true;
		if (!warm) this->mForcePublish = false;
		this->publish(crop.size(), QRectF(double(crop.x()) / buffer.width(), double(crop.y()) / buffer.height(), double(crop.width()) / buffer.width(), double(crop.height()) / buffer.height()));
		this->pump();
		return;
	}

	const auto fmt = frame->format == WL_SHM_FORMAT_ARGB8888 ? QImage::Format_ARGB32_Premultiplied
	                                                         : QImage::Format_RGB32;
	QImage shared(frame->data, int(frame->width), int(frame->height), int(frame->stride), fmt);
	QImage image = shared.copy();
	if (frame->yInvert) image = image.flipped(Qt::Vertical);
	this->dropFrame(frame);

	const bool same = this->sameAsBefore(image.constBits(), image.sizeInBytes(), image.size(), false, int(image.bytesPerLine()), QRect(QPoint(0, 0), image.size()));
	if (same && !forced) {
		this->mDuplicates++;
		emit this->statsChanged();
		this->pump();
		return;
	}
	if (warm && this->mSerial > 0 && this->mLastPublish.isValid() && this->mLastPublish.elapsed() < 100) {
		this->mWarmupDropped++;
		emit this->statsChanged();
		this->pump();
		return;
	}

	if (this->mPendingDma) {
		this->mPendingDma->state = GlassDmaBuffer::State::Free;
		this->mPendingDma = nullptr;
	}
	// The dmabuf that was shown is retired by the render thread when the image replaces it.
	this->mDropShownForImage = this->mCurrentDma != nullptr;
	this->mImage = image;
	this->mUsingDmabuf = false;
	if (!warm) this->mForcePublish = false;
	this->publish(image.size(), QRectF(0, 0, 1, 1));
	this->pump();
}

// ---------------------------------------------------------------- texture

QSGTextureProvider* GlassCapture::textureProvider() const {
	auto* w = this->window();
	if (!w || !w->isSceneGraphInitialized()) return nullptr;
	if (!this->mProvider) this->mProvider = new GlassTextureProvider();
	return this->mProvider;
}

// Render thread, with the GUI thread blocked (the scene synchronisation).
QSGNode* GlassCapture::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) {
	if (this->mTextureDirty && this->window()) {
		if (!this->mProvider) this->mProvider = new GlassTextureProvider();

		if (this->mPendingDma) {
			auto* dma = this->mPendingDma;
			auto dpy = eglGetCurrentDisplay();
			this->mEglDisplay.store(dpy);
			bool ok = loadGlFunctions(dpy);

			if (ok && !dma->texture) {
				const EGLint attrs[] = {
				    EGL_WIDTH, EGLint(dma->width),
				    EGL_HEIGHT, EGLint(dma->height),
				    EGL_LINUX_DRM_FOURCC_EXT, EGLint(dma->format),
				    EGL_DMA_BUF_PLANE0_FD_EXT, dma->fd,
				    EGL_DMA_BUF_PLANE0_OFFSET_EXT, EGLint(dma->offset),
				    EGL_DMA_BUF_PLANE0_PITCH_EXT, EGLint(dma->stride),
				    EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, EGLint(dma->modifier & 0xffffffff),
				    EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT, EGLint(dma->modifier >> 32),
				    EGL_NONE,
				};
				auto* image = dpy == EGL_NO_DISPLAY ? nullptr : eglCreateImage_(dpy, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, nullptr, attrs);
				if (image) {
					GLint previous = 0;
					glGetIntegerv(GL_TEXTURE_BINDING_2D, &previous);
					GLuint texture = 0;
					glGenTextures(1, &texture);
					glBindTexture(GL_TEXTURE_2D, texture);
					glImageTarget_(GL_TEXTURE_2D, image);
					glBindTexture(GL_TEXTURE_2D, GLuint(previous));
					dma->eglImage = image;
					dma->texture = texture;
				} else {
					qCWarning(logGlass) << "glass capture: eglCreateImage failed, error" << Qt::hex << eglGetError();
					ok = false;
				}
			}

			if (ok && dma->texture && dma->eglImage) {
				// The compositor wrote into this buffer since it was last used as a texture: bind the
				// image again, so that the driver does not go on with what it saw before.
				GLint previous = 0;
				glGetIntegerv(GL_TEXTURE_BINDING_2D, &previous);
				glBindTexture(GL_TEXTURE_2D, dma->texture);
				glImageTarget_(GL_TEXTURE_2D, dma->eglImage);
				glBindTexture(GL_TEXTURE_2D, GLuint(previous));

				auto flags = QQuickWindow::CreateTextureOptions();
				if (dma->format == DRM_FORMAT_XRGB8888) flags |= QQuickWindow::TextureIsOpaque;
				auto* texture = QNativeInterface::QSGOpenGLTexture::fromNative(dma->texture, this->window(), QSize(int(dma->width), int(dma->height)), flags);
				this->mProvider->setTexture(texture);
				// The one shown until now can go once the GPU is done with the frames that used it.
				if (this->mCurrentDma && this->mCurrentDma != dma) this->retireOnRenderThread(this->mCurrentDma);
				this->mCurrentDma = dma;
				dma->state = GlassDmaBuffer::State::Shown;
				this->mConsecutiveImportFailures = 0;
			} else {
				// The previous texture stays: the glass keeps what it had. The buffer was never
				// sampled, so it is free again.
				this->mImportFailures++;
				dma->state = GlassDmaBuffer::State::Free;
				if (++this->mConsecutiveImportFailures >= 3) {
					QMetaObject::invokeMethod(this, [this]() {
						this->giveUpOnDmabuf(QStringLiteral("importing the buffer into Qt keeps failing"));
					}, Qt::QueuedConnection);
				}
			}
			this->mPendingDma = nullptr;
			this->mTextureDirty = false;
		} else if (!this->mImage.isNull()) {
			if (this->mDropShownForImage && this->mCurrentDma) {
				this->retireOnRenderThread(this->mCurrentDma);
				this->mCurrentDma = nullptr;
			}
			this->mDropShownForImage = false;
			auto flags = QQuickWindow::CreateTextureOptions();
			if (!this->mImage.hasAlphaChannel()) flags |= QQuickWindow::TextureIsOpaque;
			auto* texture = this->window()->createTextureFromImage(this->mImage, flags);
			this->mProvider->setTexture(texture);
			this->mTextureDirty = false;
		} else {
			this->mTextureDirty = false;
		}
	}
	// Nothing is drawn by this item itself: it only provides a texture.
	delete oldNode;
	return nullptr;
}

void GlassCapture::releaseResources() {
	if (this->mProvider && this->window()) {
		auto* provider = this->mProvider;
		this->mProvider = nullptr;
		this->window()->scheduleRenderJob(new DeleteProviderJob(provider), QQuickWindow::AfterSynchronizingStage);
	}
}
