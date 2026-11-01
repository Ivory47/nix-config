#include "glasscapture.hpp"

#include <algorithm>
#include <cmath>

#include <sys/mman.h>
#include <unistd.h>
#include <wayland-client-protocol.h>

#include <QtCore/QLoggingCategory>
#include <QtCore/QRunnable>
#include <QtGui/qguiapplication.h>
#include <QtQuick/QQuickWindow>
#include <QtWaylandClient/private/qwaylanddisplay_p.h>
#include <QtWaylandClient/private/qwaylandscreen_p.h>
#include <QtWaylandClient/private/qwaylandshm_p.h>
#include <QtWaylandClient/private/qwaylandwindow_p.h>

Q_LOGGING_CATEGORY(logGlass, "glass.capture", QtWarningMsg)

// ---------------------------------------------------------------- manager

GlassScreencopyManager::GlassScreencopyManager(): QWaylandClientExtensionTemplate(3) {
	this->initialize();
}

GlassScreencopyManager* GlassScreencopyManager::instance() {
	static auto* instance = new GlassScreencopyManager();
	return instance;
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

namespace {

class DeleteProviderJob: public QRunnable {
public:
	explicit DeleteProviderJob(GlassTextureProvider* provider): provider(provider) {}
	void run() override { delete this->provider; }

private:
	GlassTextureProvider* provider;
};

QtWaylandClient::QWaylandWindow* waylandWindowOf(QQuickWindow* window) {
	if (!window || !window->handle()) return nullptr;
	return dynamic_cast<QtWaylandClient::QWaylandWindow*>(window->handle());
}

} // namespace

GlassCapture::GlassCapture(QQuickItem* parent): QQuickItem(parent) {
	this->setFlag(QQuickItem::ItemHasContents, true);
	this->mTimer.setSingleShot(true);
	QObject::connect(&this->mTimer, &QTimer::timeout, this, &GlassCapture::pump);
}

GlassCapture::~GlassCapture() {
	if (this->mFrame) {
		this->mFrame->owner = nullptr;
		delete this->mFrame;
		this->mFrame = nullptr;
	}
	this->retireBuffer();
}

void GlassCapture::setActive(bool active) {
	if (active == this->mActive) return;
	this->mActive = active;
	if (!active) this->cancelFrame();
	else {
		this->mOwed = true;
		QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
	}
	emit this->activeChanged();
}

void GlassCapture::setRegion(const QRectF& region) {
	if (region == this->mRegion) return;
	this->mRegion = region;
	// What was in flight was taken for another box.
	if (this->mFrame) this->cancelFrame();
	this->mOwed = true;
	emit this->regionChanged();
	if (this->mActive) QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
}

void GlassCapture::setMinInterval(int ms) {
	if (ms == this->mMinInterval) return;
	this->mMinInterval = ms;
	emit this->minIntervalChanged();
	emit this->statsChanged();
}

void GlassCapture::setHeld(bool held) {
	if (held == this->mHeld) return;
	this->mHeld = held;
	if (held) this->cancelFrame();
	else {
		this->mOwed = true;
		QMetaObject::invokeMethod(this, &GlassCapture::pump, Qt::QueuedConnection);
	}
	emit this->heldChanged();
}

// The compositor fades a layer in when it appears; what is unmixed from those first
// captures is wrong. Capture back to back for a little while and never skip them.
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
	// grabWindow(): 1920x67 for 1440x50 logical).
	return w ? w->devicePixelRatio() : 1.0;
}

QColor GlassCapture::readPixel(const QVariant& image, int x, int y) const {
	auto img = image.value<QImage>();
	if (img.isNull() || x < 0 || y < 0 || x >= img.width() || y >= img.height()) return QColor();
	return img.pixelColor(x, y);
}

QSize GlassCapture::debugRenderSize() const {
	auto* w = this->window();
	if (!w) return QSize();
	return w->grabWindow().size();
}

void GlassCapture::nudge() {
	this->mOwed = true;
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

// A frame of ours reached the compositor: what is behind may have to be seen again.
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
	this->mOwed = true;
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

	// A capture that was asked after presenting is on its way: it brings what was asked.
	if (this->mFrame && !this->mFrame->onDamage) return;

	const bool plain = this->mOwed || this->warming();
	// Watching, with nothing owed: the compositor will tell when something changes.
	if (this->mFrame && this->mFrame->onDamage && !plain) return;

	if (this->mHasStarted) {
		auto left = this->effectiveInterval() - double(this->mSinceStart.nsecsElapsed()) / 1e6;
		if (left > 0.5) {
			this->mTimer.start(int(std::ceil(left)));
			return;
		}
	}

	if (this->mFrame) this->cancelFrame();
	this->start(!plain);
}

void GlassCapture::start(bool onDamage) {
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
	this->mFrame = new GlassFrame(this, onDamage);
	// overlay_cursor = 0: the glass does not refract the cursor, it goes on top.
	this->mFrame->init(manager->capture_output_region(0, output, r.x(), r.y(), r.width(), r.height()));
	wl_display_flush(wlw->display()->wl_display());

	this->mSinceStart.start();
	this->mHasStarted = true;
	if (!this->mBorn.isValid()) this->mBorn.start();
	if (!onDamage) this->mOwed = false;
	this->setStatus(QString());
}

void GlassCapture::cancelFrame() {
	if (!this->mFrame) return;
	const bool copied = this->mBuffer.buffer != nullptr;
	this->mFrame->owner = nullptr;
	delete this->mFrame;
	this->mFrame = nullptr;
	// The compositor may still be writing into the memory of a copy that was asked:
	// do not reuse it.
	if (copied) this->retireBuffer();
}

bool GlassCapture::ensureBuffer(GlassFrame* frame) {
	if (!frame->formatOk) return false;
	auto& b = this->mBuffer;
	if (b.buffer && b.width == int(frame->width) && b.height == int(frame->height)
	    && b.stride == int(frame->stride) && b.format == frame->format)
		return true;

	this->retireBuffer();

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

	b.data = static_cast<uchar*>(data);
	b.length = length;
	b.buffer = buffer;
	b.width = int(frame->width);
	b.height = int(frame->height);
	b.stride = int(frame->stride);
	b.format = frame->format;
	return true;
}

void GlassCapture::retireBuffer() {
	auto old = this->mBuffer;
	this->mBuffer = ShmBuffer();
	if (!old.buffer) return;
	auto release = [old]() {
		wl_buffer_destroy(old.buffer);
		munmap(old.data, old.length);
	};
	if (qApp) QTimer::singleShot(1000, qApp, release);
	else release();
}

void GlassCapture::frameBufferDone(GlassFrame* frame) {
	if (frame != this->mFrame) return;
	if (!this->ensureBuffer(frame)) {
		this->frameFailed(frame);
		return;
	}
	if (frame->onDamage) frame->copy_with_damage(this->mBuffer.buffer);
	else frame->copy(this->mBuffer.buffer);

	if (auto* wlw = waylandWindowOf(this->window())) wl_display_flush(wlw->display()->wl_display());
}

void GlassCapture::frameFailed(GlassFrame* frame) {
	if (frame != this->mFrame) return;
	frame->owner = nullptr;
	delete this->mFrame;
	this->mFrame = nullptr;
	this->retireBuffer();
	this->mFailed++;
	this->mOwed = true;
	emit this->statsChanged();
	// Try again soon, but not in a hot loop.
	this->mTimer.start(100);
}

void GlassCapture::frameReady(GlassFrame* frame) {
	if (frame != this->mFrame) return;

	const auto fmt = frame->format == WL_SHM_FORMAT_ARGB8888 ? QImage::Format_ARGB32_Premultiplied
	                                                         : QImage::Format_RGB32;
	QImage shared(this->mBuffer.data, this->mBuffer.width, this->mBuffer.height, this->mBuffer.stride, fmt);
	QImage image = shared.copy();
	if (frame->yInvert) image = image.flipped(Qt::Vertical);

	frame->owner = nullptr;
	delete this->mFrame;
	this->mFrame = nullptr;

	this->mReceived++;

	// The same as the previous one (or almost: rounding gives the odd stray level): nothing new
	// is behind. Without this, painting the glass changes the capture, which changes the glass,
	// and so on without end. One byte in thirteen is looked at, which is enough to know whether
	// something moved.
	std::vector<uchar> sample;
	const auto bytes = image.sizeInBytes();
	sample.reserve(size_t(bytes / 13) + 1);
	const uchar* bits = image.constBits();
	for (qsizetype i = 0; i < bytes; i += 13) sample.push_back(bits[i]);

	bool same = !this->mImage.isNull() && sample.size() == this->mSample.size()
	         && this->mRegion == this->mSampleRegion && image.size() == this->mImage.size();
	if (same) {
		for (size_t i = 0; i < sample.size(); i++) {
			if (std::abs(int(sample[i]) - int(this->mSample[i])) > 3) {
				same = false;
				break;
			}
		}
	}

	if (same && !this->warming()) {
		this->mSkipped++;
		emit this->statsChanged();
		this->pump();
		return;
	}

	this->mImage = image;
	this->mSample = std::move(sample);
	this->mSampleRegion = this->mRegion;
	this->mTextureDirty = true;
	this->mSerial++;
	this->update();
	emit this->serialChanged();
	emit this->statsChanged();
	emit this->captured(this->mSerial);
	this->pump();
}

QSGTextureProvider* GlassCapture::textureProvider() const {
	auto* w = this->window();
	if (!w || !w->isSceneGraphInitialized()) return nullptr;
	if (!this->mProvider) this->mProvider = new GlassTextureProvider();
	return this->mProvider;
}

QSGNode* GlassCapture::updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) {
	if (this->mTextureDirty && !this->mImage.isNull() && this->window()) {
		if (!this->mProvider) this->mProvider = new GlassTextureProvider();
		auto flags = QQuickWindow::CreateTextureOptions();
		if (!this->mImage.hasAlphaChannel()) flags |= QQuickWindow::TextureIsOpaque;
		auto* texture = this->window()->createTextureFromImage(this->mImage, flags);
		this->mProvider->setTexture(texture);
		this->mTextureDirty = false;
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
