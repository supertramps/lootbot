'use strict';

const fs = require('node:fs');
const path = require('node:path');

// The opening was traced on the 2048×683 view of the original peon artwork.
// Keep the bounds in sync with the icon anchor in LevelToast.lua.
const bounds = { x: 46, y: 66, width: 472, height: 498 };
const segments = [
    [[280, 70], [413, 70], [511, 181], [513, 309]],
    [[513, 309], [516, 449], [413, 556], [278, 558]],
    [[278, 558], [143, 560], [50, 456], [50, 327]],
    [[50, 327], [49, 195], [151, 71], [280, 70]],
];
const outline = segments.flatMap(segment => Array.from({ length: 48 }, (_, index) => {
    const t = index / 48;
    const u = 1 - t;
    const weights = [u ** 3, 3 * u ** 2 * t, 3 * u * t ** 2, t ** 3];
    return [0, 1].map(axis => segment.reduce((sum, point, i) => sum + weights[i] * point[axis], 0));
}));

function contains(x, y) {
    let inside = false;
    for (let i = 0, j = outline.length - 1; i < outline.length; j = i++) {
        const [ax, ay] = outline[i];
        const [bx, by] = outline[j];
        if ((ay > y) !== (by > y) && x < ax + (bx - ax) * (y - ay) / (by - ay)) inside = !inside;
    }
    return inside;
}

const size = 128;
const texture = Buffer.alloc(18 + size * size * 4, 255);
texture.fill(0, 0, 18);
texture[2] = 2; // Uncompressed truecolor TGA.
texture.writeUInt16LE(size, 12);
texture.writeUInt16LE(size, 14);
texture[16] = 32;
texture[17] = 40; // Eight alpha bits, top-left origin.
for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
        let coverage = 0;
        for (const dy of [.125, .375, .625, .875]) {
            for (const dx of [.125, .375, .625, .875]) {
                if (contains(bounds.x + (x + dx) * bounds.width / size,
                    bounds.y + (y + dy) * bounds.height / size)) coverage++;
            }
        }
        texture[18 + (y * size + x) * 4 + 3] = Math.round(255 * coverage / 16);
    }
}
fs.writeFileSync(path.join(__dirname, '../addon/LootBot/PingPortraitMask.tga'), texture);
