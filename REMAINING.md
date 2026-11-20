# Remaining UI/UX work (Shaer game on ZARVAN)

## 1. Home screen
- [x] Endless and Race entries on the home (velvet buttons under Continue; they had been removed from the home earlier).
- [ ] Review Endless/Race game screens, lives and the continue-with-ad offer visually.

## 2. Result screen
- [x] Result screen: the card ends under its last line and the buttons follow it (no empty band).

## 3. Feel and feedback
- [x] Haptics on correct/wrong answers and the armed hint (`QuizKit.haptic`, honours the Settings toggle; the game wires it to the device).
- [ ] A soft sound cue if audio is wired.
- [ ] Coin-count animation when coins are earned or spent (hint cost ticks down).
- [ ] Hold 60 fps: the 120 Hz phone ignores `maxFps: 60` and runs 115-120 fps (battery).

## 4. Polish
- [ ] Long four-line poems can touch the bottom-left blossom.
- [ ] Re-measure first-open/back lag of the poet dialog on a device.
- [ ] See the armed-hint gold glow and the author-label guard on a device.

## 5. Longer term
- [ ] Onboarding hint about the 20-coin hint cost.
- [ ] Accessibility: larger poem text option; contrast of cream-on-lapis labels.
- [ ] Persian digits everywhere; RTL check on every screen.
