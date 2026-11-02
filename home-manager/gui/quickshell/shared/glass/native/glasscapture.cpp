#include "glasscapture.hpp"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>

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

bool loadGlFunctions() {
	static bool loaded = false;
	if (loaded) return eglCreateImage_ && eglDestroyImage_ && glImageTarget_;
	loaded = true;
	eglCreateImage_ = reinterpret_cast<PFNEGLCREATEIMAGEKHRPROC>(eglGetProcAddress("eglCreateImageKHR"));
	eglDestroyImage_ = reinterpret_cast<PFNEGLDESTROYIMAGEKHRPROC>(eglGetProcAddress("eglDestroyImageKHR"));
	glImageTarget_ =
	    reinterpret_cast<PFNGLEGLIMAGETARGETTEXTURE2DOESPROC>(eglGetProcAddress("glEGLImageTargetTexture2DOES"));
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
	emit this->allowDmabufChanged();
}

void GlassCapture::setPublishing(bool publishing) {
	if (publishing == this->mPublishing) return;
	this->mPublishing = publishing;
	emit this->publishingChanged();
}

void GlassCapture::setHeld(bool held) {
	if (held == this->mHeld) return;
	this->mHeld = held;
	if (held) this->cancelFrames();
	else QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
	emit this->heldChanged();
}

// The compositor fades a layer in when it appears; what is unmixed from those first
// captures is wrong. Never skip them for a little while.
bool GlassCapture::warming() const {
	return this->mReceived < 3 || (this->mBorn.isValid() && this->mBorn.elapsed() < 1500);
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

	// Captures are on their way all the time. The compositor answers each with the next frame
	// it draws, and draws none while nothing changes.
	if (this->mFrames.size() >= this->mDepth) return;

	// Not more than one per refresh period, so that a depth of three does not mean three at once.
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
	frame->init(manager->capture_output_region(0, output, r.x(), r.y(), r.width(), r.height()));
	frame->started.start();
	this->mFrames.append(frame);
	this->mRequests++;
	wl_display_flush(wlw->display()->wl_display());

	this->mSinceStart.start();
	this->mHasStarted = true;
	if (!this->mBorn.isValid()) this->mBorn.start();
	this->setStatus(QString());

	// Room for another one? (Not at once: the interval above decides when.)
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

GlassDmaBuffer* GlassCapture::acquireDma(uint32_t format, uint32_t width, uint32_t height) {
	const auto now = nowMs();
	const int syncs = this->mSyncs.load();
	for (auto* b: this->mDmaPool) {
		if (b->busy || b->format != format || b->width != width || b->height != height) continue;
		if (b->freeAtSync > syncs || b->freeAtMs > now) continue;
		b->busy = true;
		return b;
	}
	if (this->mDmaPool.size() >= 10) return nullptr;

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

	b->busy = true;
	this->mDmaPool.push_back(b);
	return b;
}

void GlassCapture::destroyDmaPool() {
	std::vector<DestroyDmaJob::Item> items;
	for (auto* b: this->mDmaPool) {
		if (b->eglImage || b->texture) items.push_back({b->eglImage, b->texture});
		if (b->map) munmap(const_cast<uchar*>(b->map), b->mapLength);
		if (b->buffer) wl_buffer_destroy(b->buffer);
		if (b->fd >= 0) close(b->fd);
		if (b->bo) gbm_bo_destroy(b->bo);
		delete b;
	}
	this->mDmaPool.clear();
	this->mCurrentDma = nullptr;
	if (!items.empty()) {
		if (this->window()) this->window()->scheduleRenderJob(new DestroyDmaJob(std::move(items)), QQuickWindow::AfterSynchronizingStage);
	}
}

bool GlassCapture::ensureDmaBuffer(GlassFrame* frame) {
	if (!frame->dmaOffered) return false;
	if (frame->dmaFormat != DRM_FORMAT_XRGB8888 && frame->dmaFormat != DRM_FORMAT_ARGB8888) return false;
	if (!GlassDmabufManager::instance()->acceptsLinear(frame->dmaFormat)) return false;
	frame->dma = this->acquireDma(frame->dmaFormat, frame->dmaWidth, frame->dmaHeight);
	return frame->dma != nullptr;
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

// Forgets a capture: it is destroyed (the compositor drops it if it is not done), and so is
// its memory, a little later if the compositor may still be writing into it.
void GlassCapture::dropFrame(GlassFrame* frame) {
	this->mFrames.removeOne(frame);
	frame->owner = nullptr;
	const bool maybeBusy = frame->copyAsked;

	if (frame->dma) {
		// Back to the pool, but not to be used again at once if the compositor may still write.
		frame->dma->busy = false;
		if (maybeBusy) frame->dma->freeAtMs = nowMs() + 1000;
		frame->dma = nullptr;
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

void GlassCapture::frameBufferDone(GlassFrame* frame) {
	if (!this->mFrames.contains(frame)) return;
	this->mSetup = double(frame->started.nsecsElapsed()) / 1e6;

	bool ok = false;
	if (this->dmabufUsable()) ok = this->ensureDmaBuffer(frame);
	if (!ok) ok = this->ensureShmBuffer(frame);
	if (!ok) {
		this->frameFailed(frame);
		return;
	}

	frame->copyAsked = true;
	this->mCopiesAsked++;
	auto* buffer = frame->dma ? frame->dma->buffer : frame->buffer;
	if (frame->onDamage) frame->copy_with_damage(buffer);
	else frame->copy(buffer);

	if (auto* wlw = waylandWindowOf(this->window())) wl_display_flush(wlw->display()->wl_display());
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
bool GlassCapture::sameAsBefore(const uchar* bits, qsizetype bytes, QSize size, bool linear, int stride, uint32_t height) {
	std::vector<uchar> sample;
	if (linear) {
		// Every second row, every 61st pixel.
		const int rowStep = 2;
		const int pixelStep = 61;
		for (uint32_t y = 0; y < height; y += rowStep) {
			const uchar* row = bits + size_t(y) * stride;
			for (int x = 0; x < size.width(); x += pixelStep) sample.push_back(row[x * 4 + 1]);
		}
	} else {
		sample.reserve(size_t(bytes / 13) + 1);
		for (qsizetype i = 0; i < bytes; i += 13) sample.push_back(bits[i]);
	}

	bool same = !this->mCaptureSize.isEmpty() && sample.size() == this->mSample.size()
	         && this->mRegion == this->mSampleRegion && size == this->mCaptureSize;
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

void GlassCapture::publish(QSize size) {
	this->mSample = std::move(this->mNewSample);
	this->mSampleRegion = this->mRegion;
	this->mCaptureSize = size;
	this->mTextureDirty = true;
	this->mSerial++;
	this->update();
	emit this->serialChanged();
	emit this->statsChanged();
	emit this->captured(this->mSerial);
}

void GlassCapture::frameReady(GlassFrame* frame) {
	if (!this->mFrames.contains(frame)) return;

	this->mLatency = double(frame->started.nsecsElapsed()) / 1e6;
	this->mReceived++;
	if (this->mLastReady.isValid()) this->mCycle = double(this->mLastReady.nsecsElapsed()) / 1e6;
	this->mLastReady.start();

	if (!this->mPublishing) {
		// Measuring: the capture arrived, and that is all.
		this->dropFrame(frame);
		emit this->statsChanged();
		this->pump();
		return;
	}

	if (frame->dma) {
		auto* dma = frame->dma;
		bool same = false;
		if (dma->map) {
			dma_buf_sync sync {};
			sync.flags = DMA_BUF_SYNC_START | DMA_BUF_SYNC_READ;
			ioctl(dma->fd, DMA_BUF_IOCTL_SYNC, &sync);
			same = this->sameAsBefore(dma->map, qsizetype(dma->mapLength), QSize(int(dma->width), int(dma->height)), true, int(dma->stride), dma->height);
			sync.flags = DMA_BUF_SYNC_END | DMA_BUF_SYNC_READ;
			ioctl(dma->fd, DMA_BUF_IOCTL_SYNC, &sync);
		} else {
			this->mNewSample.clear();
		}

		if (same && !this->warming()) {
			// Nothing new: the buffer can be used again at once.
			frame->dma = nullptr;
			dma->busy = false;
			this->dropFrame(frame);
			this->mSkipped++;
			emit this->statsChanged();
			this->pump();
			return;
		}

		// Shown from now on; the one shown before is let go once nothing can still be reading it.
		frame->dma = nullptr;
		this->dropFrame(frame);
		if (this->mCurrentDma) {
			this->mCurrentDma->busy = false;
			this->mCurrentDma->freeAtSync = this->mSyncs.load() + 4;
			this->mCurrentDma->freeAtMs = nowMs() + 100;
		}
		this->mCurrentDma = dma;
		this->mImage = QImage();
		this->mUsingDmabuf = true;
		this->publish(QSize(int(dma->width), int(dma->height)));
		this->pump();
		return;
	}

	const auto fmt = frame->format == WL_SHM_FORMAT_ARGB8888 ? QImage::Format_ARGB32_Premultiplied
	                                                         : QImage::Format_RGB32;
	QImage shared(frame->data, int(frame->width), int(frame->height), int(frame->stride), fmt);
	QImage image = shared.copy();
	if (frame->yInvert) image = image.flipped(Qt::Vertical);
	this->dropFrame(frame);

	const bool same = this->sameAsBefore(image.constBits(), image.sizeInBytes(), image.size(), false, int(image.bytesPerLine()), uint32_t(image.height()));
	if (same && !this->warming()) {
		this->mSkipped++;
		emit this->statsChanged();
		this->pump();
		return;
	}

	if (this->mCurrentDma) {
		this->mCurrentDma->busy = false;
		this->mCurrentDma->freeAtSync = this->mSyncs.load() + 4;
		this->mCurrentDma->freeAtMs = nowMs() + 100;
		this->mCurrentDma = nullptr;
	}
	this->mImage = image;
	this->mUsingDmabuf = false;
	this->publish(image.size());
	this->pump();
}

// ---------------------------------------------------------------- texture

QSGTextureProvider* GlassCapture::textureProvider() const {
	auto* w = this->window();
	if (!w || !w->isSceneGraphInitialized()) return nullptr;
	if (!this->mProvider) this->mProvider = new GlassTextureProvider();
	return this->mProvider;
}

QSGNode* GlassCapture::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) {
	if (this->mTextureDirty && this->window()) {
		if (!this->mProvider) this->mProvider = new GlassTextureProvider();

		if (this->mCurrentDma) {
			auto* dma = this->mCurrentDma;
			bool ok = loadGlFunctions();
			if (ok && !dma->texture) {
				auto dpy = eglGetCurrentDisplay();
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
					ok = false;
				}
			}

			if (ok && dma->texture) {
				auto flags = QQuickWindow::CreateTextureOptions();
				if (dma->format == DRM_FORMAT_XRGB8888) flags |= QQuickWindow::TextureIsOpaque;
				auto* texture = QNativeInterface::QSGOpenGLTexture::fromNative(dma->texture, this->window(), QSize(int(dma->width), int(dma->height)), flags);
				this->mProvider->setTexture(texture);
			} else {
				// Cannot be imported: from now on the pixels come through shared memory.
				this->mDmaBroken.store(true);
			}
			this->mTextureDirty = false;
		} else if (!this->mImage.isNull()) {
			auto flags = QQuickWindow::CreateTextureOptions();
			if (!this->mImage.hasAlphaChannel()) flags |= QQuickWindow::TextureIsOpaque;
			auto* texture = this->window()->createTextureFromImage(this->mImage, flags);
			this->mProvider->setTexture(texture);
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
