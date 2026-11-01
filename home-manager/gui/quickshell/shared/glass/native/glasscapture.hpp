#pragma once

// Native part of the live glass pipeline.
//
// GlassCapture reproduces Pleamar's capture side for Quickshell:
//   - zwlr_screencopy_manager_v1.capture_output_region() for only the glass region,
//   - copy_with_damage: the compositor answers with the next frame it draws ("watch"),
//   - a minimum interval between two captures (default: one refresh period of the monitor),
//   - the sampled-bytes skip, so repainting the glass cannot feed itself,
//   - the warm-up (first captures are never skipped; the compositor fades layers in).
//
// Two ways to receive the pixels:
//   - dmabuf (preferred): we allocate linear buffers with GBM, the compositor renders into them
//     on the GPU, and Qt samples them as textures (EGLImage) without a copy. This is what makes
//     monitor-rate captures possible.
//   - wl_shm (fallback): the compositor reads the pixels back to the CPU, which in Hyprland 0.56
//     takes around 80 ms per capture, so about 12 per second.
// Several captures are in flight at once (`depth`).
//
// The captured pixels are handed to QML as a texture provider, so the unmixing, the validation
// and all blur / glass shading run on the GPU in ShaderEffects.

#include <atomic>
#include <memory>
#include <vector>

#include <QtCore/QElapsedTimer>
#include <QtCore/QHash>
#include <QtCore/QList>
#include <QtCore/QRectF>
#include <QtCore/QTimer>
#include <QtGui/QColor>
#include <QtGui/QImage>
#include <QtQml/qqmlregistration.h>
#include <QtQuick/QQuickItem>
#include <QtQuick/QSGTextureProvider>
// wl_buffer_interface, which the generated dmabuf header uses without including it
#include <wayland-client-protocol.h>

#include <QtWaylandClient/QWaylandClientExtension>
#include <qwayland-linux-dmabuf-v1.h>
#include <qwayland-wlr-screencopy-unstable-v1.h>

class GlassCapture;
struct wl_buffer;
struct gbm_bo;

class GlassScreencopyManager
    : public QWaylandClientExtensionTemplate<GlassScreencopyManager>
    , public QtWayland::zwlr_screencopy_manager_v1 {
public:
	static GlassScreencopyManager* instance();

private:
	GlassScreencopyManager();
};

// Which modifiers the compositor accepts for which format.
class GlassDmabufManager
    : public QWaylandClientExtensionTemplate<GlassDmabufManager>
    , public QtWayland::zwp_linux_dmabuf_v1 {
public:
	static GlassDmabufManager* instance();
	bool acceptsLinear(uint32_t format) const;

protected:
	void zwp_linux_dmabuf_v1_modifier(uint32_t format, uint32_t modifierHi, uint32_t modifierLo) override;

private:
	GlassDmabufManager();
	QHash<uint32_t, QList<uint64_t>> mModifiers;
};

// A buffer the compositor renders into: allocated by us, shared as a dmabuf.
struct GlassDmaBuffer {
	gbm_bo* bo = nullptr;
	int fd = -1;
	wl_buffer* buffer = nullptr;
	uint32_t format = 0;
	uint32_t width = 0;
	uint32_t height = 0;
	uint32_t stride = 0;
	uint32_t offset = 0;
	uint64_t modifier = 0;
	// For looking at it from the CPU (a few bytes, to know whether anything changed).
	const uchar* map = nullptr;
	size_t mapLength = 0;
	// For Qt (created on the render thread when first needed).
	void* eglImage = nullptr;
	unsigned int texture = 0;
	// Taken by a capture / not to be reused before this many scene synchronisations.
	bool busy = false;
	int freeAtSync = 0;
	qint64 freeAtMs = 0;
};

// One capture request. Events after the owner cancelled it are ignored.
class GlassFrame: public QtWayland::zwlr_screencopy_frame_v1 {
public:
	GlassFrame(GlassCapture* owner, bool onDamage): owner(owner), onDamage(onDamage) {}
	~GlassFrame() override;

	GlassCapture* owner;
	bool onDamage;
	uint32_t format = 0;
	uint32_t width = 0;
	uint32_t height = 0;
	uint32_t stride = 0;
	bool formatOk = false;
	bool yInvert = false;
	bool copyAsked = false;
	// The compositor offered a dmabuf of this format (DRM fourcc) and size.
	bool dmaOffered = false;
	uint32_t dmaFormat = 0;
	uint32_t dmaWidth = 0;
	uint32_t dmaHeight = 0;
	QElapsedTimer started;

	// What the compositor copies into: shared memory or a dmabuf.
	uchar* data = nullptr;
	size_t length = 0;
	wl_buffer* buffer = nullptr;
	GlassDmaBuffer* dma = nullptr;

protected:
	void zwlr_screencopy_frame_v1_buffer(uint32_t format, uint32_t width, uint32_t height, uint32_t stride) override;
	void zwlr_screencopy_frame_v1_flags(uint32_t flags) override;
	void zwlr_screencopy_frame_v1_linux_dmabuf(uint32_t format, uint32_t width, uint32_t height) override;
	void zwlr_screencopy_frame_v1_buffer_done() override;
	void zwlr_screencopy_frame_v1_ready(uint32_t tvSecHi, uint32_t tvSecLo, uint32_t tvNsec) override;
	void zwlr_screencopy_frame_v1_failed() override;
};

class GlassTextureProvider: public QSGTextureProvider {
	Q_OBJECT
public:
	QSGTexture* texture() const override { return this->mTexture.get(); }
	void setTexture(QSGTexture* texture) {
		this->mTexture.reset(texture);
		emit this->textureChanged();
	}

private:
	std::unique_ptr<QSGTexture> mTexture;
};

class GlassCapture: public QQuickItem {
	Q_OBJECT
	QML_ELEMENT
	// Capture on / off. Off cancels whatever is in flight.
	Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
	// Region to capture, in logical pixels of the output (origin: the output's top left).
	Q_PROPERTY(QRectF region READ region WRITE setRegion NOTIFY regionChanged)
	// Minimum time between two requests, ms. 0 = one refresh period of the window's screen.
	Q_PROPERTY(int minInterval READ minInterval WRITE setMinInterval NOTIFY minIntervalChanged)
	// How many captures may be on their way at once.
	Q_PROPERTY(int depth READ depth WRITE setDepth NOTIFY depthChanged)
	// Use dmabuf if possible (else always shared memory).
	Q_PROPERTY(bool allowDmabuf READ allowDmabuf WRITE setAllowDmabuf NOTIFY allowDmabufChanged)
	// Held: no new captures (a glass that is not visible does not need any).
	Q_PROPERTY(bool held READ held WRITE setHeld NOTIFY heldChanged)
	// Increases each time a capture with something new was published.
	Q_PROPERTY(int serial READ serial NOTIFY serialChanged)
	Q_PROPERTY(bool warming READ warming NOTIFY serialChanged)
	Q_PROPERTY(int received READ received NOTIFY statsChanged)
	Q_PROPERTY(int skipped READ skipped NOTIFY statsChanged)
	Q_PROPERTY(int failed READ failed NOTIFY statsChanged)
	Q_PROPERTY(bool usingDmabuf READ usingDmabuf NOTIFY statsChanged)
	// The effective minimum interval in ms, and the pixel size of the last capture.
	Q_PROPERTY(qreal effectiveInterval READ effectiveInterval NOTIFY statsChanged)
	// How long the last capture took from the request to the pixels (ms), of which until the
	// compositor told which buffer it wants, and the time between the last two captures arriving.
	Q_PROPERTY(qreal latency READ latency NOTIFY statsChanged)
	Q_PROPERTY(qreal setupLatency READ setupLatency NOTIFY statsChanged)
	Q_PROPERTY(qreal cycle READ cycle NOTIFY statsChanged)
	Q_PROPERTY(QSize captureSize READ captureSize NOTIFY serialChanged)
	// Real pixels per logical pixel of the window (fractional scale included).
	Q_PROPERTY(qreal pixelRatio READ pixelRatio NOTIFY pixelRatioChanged)
	// What is wrong, if anything (no protocol, no output, ...).
	Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
	explicit GlassCapture(QQuickItem* parent = nullptr);
	~GlassCapture() override;

	bool active() const { return this->mActive; }
	void setActive(bool active);
	QRectF region() const { return this->mRegion; }
	void setRegion(const QRectF& region);
	int minInterval() const { return this->mMinInterval; }
	void setMinInterval(int ms);
	int depth() const { return this->mDepth; }
	void setDepth(int depth);
	bool allowDmabuf() const { return this->mAllowDmabuf; }
	void setAllowDmabuf(bool allow);
	bool held() const { return this->mHeld; }
	void setHeld(bool held);
	int serial() const { return this->mSerial; }
	bool warming() const;
	int received() const { return this->mReceived; }
	int skipped() const { return this->mSkipped; }
	int failed() const { return this->mFailed; }
	bool usingDmabuf() const { return this->mUsingDmabuf; }
	qreal effectiveInterval() const;
	qreal latency() const { return this->mLatency; }
	qreal setupLatency() const { return this->mSetup; }
	qreal cycle() const { return this->mCycle; }
	QSize captureSize() const { return this->mCaptureSize; }
	qreal pixelRatio() const;
	QString status() const { return this->mStatus; }

	// Reads one pixel of a QQuickItemGrabResult.image (for debugging).
	Q_INVOKABLE QColor readPixel(const QVariant& image, int x, int y) const;
	// Ask for a capture as soon as the interval allows (a nudge).
	Q_INVOKABLE void nudge();
	// How many times the window synchronised the scene so far (see swapped()).
	Q_INVOKABLE int syncCount() const { return this->mSyncs.load(); }

	bool isTextureProvider() const override { return true; }
	QSGTextureProvider* textureProvider() const override;

	// Called by GlassFrame.
	void frameBufferDone(GlassFrame* frame);
	void frameReady(GlassFrame* frame);
	void frameFailed(GlassFrame* frame);

signals:
	void activeChanged();
	void regionChanged();
	void minIntervalChanged();
	void depthChanged();
	void allowDmabufChanged();
	void heldChanged();
	void serialChanged();
	void statsChanged();
	void pixelRatioChanged();
	void statusChanged();
	// A capture with new content is ready as the texture of this item.
	void captured(int serial);
	// A frame reached the compositor. syncSerial is the number of scene synchronisations that
	// had happened when that frame was synchronised: a frame whose syncSerial is greater than
	// syncCount() read at some earlier time was synchronised after that time.
	void swapped(int syncSerial);

protected:
	QSGNode* updatePaintNode(QSGNode* oldNode, UpdatePaintNodeData*) override;
	void itemChange(ItemChange change, const ItemChangeData& data) override;
	void releaseResources() override;

private slots:
	void pump();

private:
	bool dmabufUsable() const;
	bool ensureShmBuffer(GlassFrame* frame);
	bool ensureDmaBuffer(GlassFrame* frame);
	GlassDmaBuffer* acquireDma(uint32_t format, uint32_t width, uint32_t height);
	void destroyDmaPool();
	void dropFrame(GlassFrame* frame);
	void cancelFrames();
	void start();
	void setStatus(const QString& status);
	void bindWindow(QQuickWindow* window);
	void onFrameSwapped(int syncSerial);
	void checkRatio();
	bool sameAsBefore(const uchar* bits, qsizetype bytes, QSize size, bool linear, int stride, uint32_t height);
	void publish(QSize size);

	bool mActive = false;
	bool mHeld = false;
	bool mAllowDmabuf = true;
	bool mUsingDmabuf = false;
	QRectF mRegion;
	int mMinInterval = 0;
	int mDepth = 3;

	QList<GlassFrame*> mFrames;
	QTimer mTimer;
	QElapsedTimer mSinceStart;
	QElapsedTimer mBorn;
	bool mHasStarted = false;

	// What is shown: the newest published capture, as an image (shm) or a dmabuf.
	QImage mImage;
	GlassDmaBuffer* mCurrentDma = nullptr;
	QSize mCaptureSize;
	std::vector<GlassDmaBuffer*> mDmaPool;
	std::vector<uchar> mSample;
	std::vector<uchar> mNewSample;
	QRectF mSampleRegion;
	bool mTextureDirty = false;
	mutable GlassTextureProvider* mProvider = nullptr;

	qreal mRatio = 0;
	qreal mLatency = 0;
	qreal mCycle = 0;
	qreal mSetup = 0;
	QElapsedTimer mLastReady;
	int mSerial = 0;
	int mReceived = 0;
	int mSkipped = 0;
	int mFailed = 0;
	QString mStatus;
	QMetaObject::Connection mSwapConnection;
	QMetaObject::Connection mSyncConnection;
	std::atomic<int> mSyncs {0};
	std::atomic<bool> mDmaBroken {false};
};
