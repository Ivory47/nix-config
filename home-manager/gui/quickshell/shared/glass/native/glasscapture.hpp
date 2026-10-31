#pragma once

// Native part of the live glass pipeline (see shared/glass/README in default.nix comments).
//
// GlassCapture reproduces Pleamar's capture side for Quickshell:
//   - zwlr_screencopy_manager_v1.capture_output_region() for only the glass region,
//   - plain copy right after the surface presented a frame ("after paint"),
//   - copy_with_damage while idle ("watch"): nothing arrives until something behind changes,
//   - a minimum interval between captures (default: one refresh period of the monitor),
//   - the byte-sample skip, so repainting the glass cannot feed itself,
//   - the warm-up (first captures are never skipped; the compositor fades layers in).
// The captured pixels are handed to QML as a texture provider, so the unmixing, the validation
// and all blur / glass shading run on the GPU in ShaderEffects.

#include <atomic>
#include <memory>
#include <vector>

#include <QtCore/QElapsedTimer>
#include <QtCore/QRectF>
#include <QtCore/QTimer>
#include <QtGui/QColor>
#include <QtGui/QImage>
#include <QtQml/qqmlregistration.h>
#include <QtQuick/QQuickItem>
#include <QtQuick/QSGTextureProvider>
#include <QtWaylandClient/QWaylandClientExtension>
#include <qwayland-wlr-screencopy-unstable-v1.h>

class GlassCapture;
struct wl_buffer;

class GlassScreencopyManager
    : public QWaylandClientExtensionTemplate<GlassScreencopyManager>
    , public QtWayland::zwlr_screencopy_manager_v1 {
public:
	static GlassScreencopyManager* instance();

private:
	GlassScreencopyManager();
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

protected:
	void zwlr_screencopy_frame_v1_buffer(uint32_t format, uint32_t width, uint32_t height, uint32_t stride) override;
	void zwlr_screencopy_frame_v1_flags(uint32_t flags) override;
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
	// Minimum time between captures, ms. 0 = one refresh period of the window's screen.
	Q_PROPERTY(int minInterval READ minInterval WRITE setMinInterval NOTIFY minIntervalChanged)
	// Held: no new captures (a glass that is not visible does not need any).
	Q_PROPERTY(bool held READ held WRITE setHeld NOTIFY heldChanged)
	// Increases each time a capture with something new was published.
	Q_PROPERTY(int serial READ serial NOTIFY serialChanged)
	Q_PROPERTY(bool warming READ warming NOTIFY serialChanged)
	Q_PROPERTY(int received READ received NOTIFY statsChanged)
	Q_PROPERTY(int skipped READ skipped NOTIFY statsChanged)
	Q_PROPERTY(int failed READ failed NOTIFY statsChanged)
	// The effective minimum interval in ms, and the pixel size of the last capture.
	Q_PROPERTY(qreal effectiveInterval READ effectiveInterval NOTIFY statsChanged)
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
	bool held() const { return this->mHeld; }
	void setHeld(bool held);
	int serial() const { return this->mSerial; }
	bool warming() const;
	int received() const { return this->mReceived; }
	int skipped() const { return this->mSkipped; }
	int failed() const { return this->mFailed; }
	qreal effectiveInterval() const;
	QSize captureSize() const { return this->mImage.size(); }
	qreal pixelRatio() const;
	QString status() const { return this->mStatus; }

	// Reads one pixel of a QQuickItemGrabResult.image (for the optional debug readout).
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
	struct ShmBuffer {
		uchar* data = nullptr;
		size_t length = 0;
		wl_buffer* buffer = nullptr;
		int width = 0;
		int height = 0;
		int stride = 0;
		uint32_t format = 0;
	};

	bool ensureBuffer(GlassFrame* frame);
	void retireBuffer();
	void start(bool onDamage);
	void cancelFrame();
	void setStatus(const QString& status);
	void bindWindow(QQuickWindow* window);
	void onFrameSwapped(int syncSerial);

	bool mActive = false;
	bool mHeld = false;
	QRectF mRegion;
	int mMinInterval = 0;

	GlassFrame* mFrame = nullptr;
	ShmBuffer mBuffer;
	QTimer mTimer;
	QElapsedTimer mSinceStart;
	QElapsedTimer mBorn;
	bool mHasStarted = false;
	// A frame was presented since the last non-watching capture was asked for.
	bool mOwed = true;

	QImage mImage;
	std::vector<uchar> mSample;
	QRectF mSampleRegion;
	bool mTextureDirty = false;
	mutable GlassTextureProvider* mProvider = nullptr;

	int mSerial = 0;
	int mReceived = 0;
	int mSkipped = 0;
	int mFailed = 0;
	QString mStatus;
	QMetaObject::Connection mSwapConnection;
	QMetaObject::Connection mSyncConnection;
	std::atomic<int> mSyncs {0};
};
