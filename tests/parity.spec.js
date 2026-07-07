// Behavior parity tests for Two Cubes.
//
// The same suite must pass against the production deploy (twocubes.io, which
// runs the old PHP backend) and against the local static build (no backend).
// Expected values below were probed from production on 2026-07-03.
const { test, expect } = require('@playwright/test');

const GAME = '/web/cards.html';
const IS_PROD = (process.env.BASE_URL || '').includes('twocubes.io');

// Calls the same JS bridge the game uses (Api.call -> WebApi) and resolves
// with the response the game would see.
function apiCall(page, method, data) {
    return page.evaluate(([method, data]) => new Promise((resolve) => {
        window.Api.call(method, data, resolve);
    }), [method, data]);
}

async function bootGame(page) {
    await page.goto(GAME);
    // The loading overlay is removed from the DOM once the game has fully
    // booted (locale applied, user loaded, Dart engine started).
    await expect(page.locator('.loading-overlay')).toHaveCount(0);
    await expect(page.locator('#menu-box')).toBeVisible();
}

test.describe('boot', () => {
    test('game boots to the main menu', async ({ page }) => {
        await bootGame(page);

        await expect(page).toHaveTitle('Two Cubes – the web puzzle game.');
        await expect(page.locator('#new-game')).toHaveText('New game');
        await expect(page.locator('#menu-box .instructions'))
            .toHaveText('Place blocks and connect the cubes!');
        await expect(page.locator('.share-offer'))
            .toHaveText('Tell friends about the game!');
        // Fresh profile: nothing to continue yet.
        await expect(page.locator('#continue')).toBeHidden();
    });

    test('runs as the "no" platform with a generated local user', async ({ page }) => {
        await bootGame(page);

        const state = await page.evaluate(() => ({
            platform: window.Api.platform,
            initialized: window.Features.initialized,
            user: window.Features.user,
            storedUserId: window.localStorage.getItem('userId'),
        }));

        expect(state.platform).toBe('no');
        expect(state.initialized).toBe(true);
        expect(state.storedUserId).toBeTruthy();
        // At menu time only the attempt budget is populated; the full user
        // object is fetched lazily via getUser (covered by the api contract
        // tests below).
        expect(state.user.allAttempts).toBe(125);
    });
});

test.describe('api contract', () => {
    // Production still ships three chapters; chapter 4 ("Head Over Heels",
    // the gravity-vector chapter, 2026-07-06) diverges until the next deploy.
    test('chapters: four chapters, first one unlocked', async ({ page }) => {
        await bootGame(page);

        const r = await apiCall(page, 'chapters', {});
        expect(r.chapters).toHaveLength(4);
        expect(r.chapters.map(c => c.name)).toEqual([
            'Adventures of Po', 'Loopy Loop', 'Deutsche Welle', 'Head Over Heels',
        ]);
        expect(r.chapters.map(c => c.unlock_stars)).toEqual([0, 30, 60, 0]);
        expect(r.chapters.map(c => c.levels)).toEqual([12, 12, 12, 6]);
        expect(r.chapters[0].unlocked).toBe(true);
        // The gravity chapter is open from the start.
        expect(r.chapters[3].unlocked).toBe(true);
    });

    test('getUser matches the production response shape', async ({ page }) => {
        await bootGame(page);

        const user = await apiCall(page, 'getUser', {});
        expect(user.platformId).toBe('no');
        expect(user.isNew).toBe(true);
        expect(user.dayAttempts).toBe(125);
        expect(user.allAttempts).toBe(125);
    });

    // Mutating calls are not fired at production; expected values are pinned
    // from a one-off production probe (2026-07-03, see design doc).
    test('finishLevel / keepAlive / addAttempts contracts', async ({ page }) => {
        test.skip(IS_PROD, 'not mutating production state; pinned from probe');
        await bootGame(page);

        const finish = await apiCall(page, 'finishLevel', {
            chapter: 1, level: 1, result: 3,
            numStatic: 2, numDynamic: 1, attempts: 2, timeSpent: 30,
        });
        expect(finish).toEqual({ result: true });

        const alive = await apiCall(page, 'keepAlive', {});
        expect(alive).toEqual({ result: true });

        const user = await apiCall(page, 'addAttempts', { attemptsUsed: 3 });
        expect(user.dayAttempts).toBe(122);
        expect(user.allAttempts).toBe(122);
        expect(user.dayAttemptsUsed).toBe(3);
    });
});

test.describe('gameplay flow', () => {
    test('New game shows the chapter list', async ({ page }) => {
        await bootGame(page);

        await page.locator('#new-game').click();
        await expect(page.locator('#chapter-selection')).toBeVisible();
        await expect(page.locator('#chapter-selection .chapter-headline'))
            .toHaveText('Choose chapter');

        const chapters = page.locator('#chapter-es .chapter');
        await expect(chapters).toHaveCount(4);
        await expect(page.locator('#chapter-es .chapter-title').first())
            .toHaveText('Adventures of Po');
        // Chapter 1 is playable on a fresh profile.
        await expect(chapters.first()).not.toHaveClass(/chapter-locked/);
    });

    test('starting chapter 1 launches a level; Continue appears after reload', async ({ page }) => {
        // Production has a bootstrap race: cards.dart.js is injected as a
        // non-blocking script from <head>, so with a warm cache Dart main()
        // can run before <body> is parsed and crash on the missing #graphics
        // canvas, leaving the loading overlay up forever. The local build
        // fixes this by loading the Dart bootstrap at the end of <body>, so
        // the reload flow is only verifiable locally.
        test.skip(IS_PROD, 'production reload is unreliable (bootstrap race, see design doc)');
        await bootGame(page);

        await page.locator('#new-game').click();
        await expect(page.locator('#chapter-selection')).toBeVisible();
        await page.locator('#chapter-es .chapter').first().click();

        // In-game UI appears...
        await expect(page.locator('#chapter-selection')).toBeHidden();
        await expect(page.locator('.game-box .buttons')).toBeVisible();
        // ...and the game records the level as last played.
        await expect.poll(() => page.evaluate(() =>
            window.localStorage.getItem('last')
        )).toBe(JSON.stringify({ chapter: 1, level: 1 }));

        await page.reload();
        await expect(page.locator('.loading-overlay')).toHaveCount(0);
        await expect(page.locator('#continue')).toBeVisible();
        await expect(page.locator('#continue')).toHaveText('Continue');
    });
});
