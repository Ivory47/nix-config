pragma Singleton

import QtQuick

// Pixel alignment helpers.
//
// Unmixing needs the pixels of our surface and the pixels of the compositor's capture to line
// up one to one. At a fractional scale (1.3333...) a logical size only does that when its real
// size is a whole number of pixels, otherwise the compositor resamples the surface by a
// fraction of a pixel and every edge in it becomes a little different from what we kept.
QtObject {
    // The smallest logical size >= `wanted` whose size in real pixels is whole at `ratio`.
    // Looks at the next few sizes only; at a whole scale the size stays as it is.
    function alignedSize(wanted, ratio) {
        const base = Math.ceil(wanted);
        for (let i = 0; i < 12; i++) {
            const px = (base + i) * ratio;
            if (Math.abs(px - Math.round(px)) < 0.005)
                return base + i;
        }
        return base;
    }
}
