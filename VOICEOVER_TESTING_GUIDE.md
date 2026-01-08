# VoiceOver Testing Quick Start Guide

**Branch:** `03.3.4.3.1-voiceover-testing-infrastructure`  
**Date:** 2026-01-08

## Setup (5 minutes)

### 1. Configure Xcode Scheme

1. Open zpod project: `cd /Volumes/zHardDrive/code/zpod && open zpod.xcworkspace`
2. **Product menu** → **Scheme** → **Edit Scheme...** (or press **⌘<**)
3. Select **"Run"** in left sidebar
4. Click **"Arguments"** tab
5. Under **"Environment Variables"** click **"+"**
6. Add:
   - **Name:** `ENABLE_ERROR_DEBUG`
   - **Value:** `1`
7. Click **"Close"**

### 2. Build and Run

1. Select **iPhone 16 simulator** (iOS 18+)
2. Press **⌘R** to build and run
3. Wait for app to launch

### 3. Enable VoiceOver

**Keyboard shortcut (fastest):**
- Press **⌘⇧⌥V** (Command-Shift-Option-V)
- You'll hear: "VoiceOver on"

**Alternative - Settings app:**
- Open **Settings** → **Accessibility** → **VoiceOver** → Toggle **ON**

---

## VoiceOver Controls

| Gesture | Action |
|---------|--------|
| **Swipe right** | Next element |
| **Swipe left** | Previous element |
| **Double tap** | Activate element |
| **Three-finger swipe** | Scroll |
| **Two-finger Z gesture** | Pause/resume VoiceOver |
| **⌘⇧⌥V** | Toggle VoiceOver on/off |

---

## Testing Steps

### Test 1: Normal Player (Baseline)

1. Navigate to any podcast → any episode
2. Tap **Play** button (with VoiceOver: swipe to find, double-tap)
3. Wait for mini-player to appear at bottom
4. Double-tap mini-player to expand
5. **Swipe right** through elements and listen:
   - "Drag indicator"
   - "Artwork"
   - "[Episode Title]"
   - "[Podcast Title]"
   - "Progress slider"
   - "Skip backward, button"
   - "Play, button" (or "Pause, button")
   - "Skip forward, button"

✅ **Baseline verified**: Normal player UI is accessible

---

### Test 2: Network Error (Recoverable)

1. In expanded player, **three-finger swipe down** to scroll
2. Find "Network" button in debug controls
3. **Double-tap** to trigger network error
4. **Swipe right from top** and listen:
   - "Drag indicator"
   - **"Playback Error"** ← Should hear this clearly
   - **"Unable to load episode. Check your connection."** ← Full message
   - **"Retry playback, button"** ← Clear label
   - "[Episode Title]"
   - "[Podcast Title]"

#### Verify:
- [ ] ❌ Does NOT say "Error" or "Exclamation mark" (icon is hidden)
- [ ] ✅ Says "Playback Error" as title
- [ ] ✅ Reads full error message
- [ ] ✅ "Retry playback, button" is present and clear
- [ ] ✅ Episode context provides useful info

5. Navigate to "Retry playback, button" and **double-tap**
6. Observe behavior (error may clear or retry may fail)

---

### Test 3: Timeout Error (Recoverable)

1. Find "Timeout" button
2. **Double-tap** to trigger
3. **Swipe right from top** and listen:
   - "Playback Error"
   - "The episode took too long to load."
   - "Retry playback, button"

#### Verify:
- [ ] Error message different from network error
- [ ] Retry button still present (recoverable)
- [ ] Announcements clear and actionable

---

### Test 4: Stream Failed Error (Non-Recoverable)

1. Find "Stream" button
2. **Double-tap** to trigger
3. **Swipe right from top** and listen:
   - "Playback Error"
   - "Unable to stream this episode."
   - **NO retry button** (goes straight to episode context)

#### Verify:
- [ ] ❌ No retry button announced (non-recoverable error)
- [ ] ✅ Error message is clear
- [ ] ✅ User understands playback cannot be retried

---

### Test 5: Missing URL Error (Non-Recoverable)

1. Find "Missing URL" button
2. **Double-tap** to trigger
3. **Swipe right from top** and listen:
   - "Playback Error"
   - "This episode doesn't have audio available."
   - **NO retry button**

#### Verify:
- [ ] No retry button (non-recoverable)
- [ ] Message explains the permanent issue

---

### Test 6: Clear Error

1. Find "Clear Error" button
2. **Double-tap**
3. Normal player UI should return
4. **Swipe through** to verify controls are back

#### Verify:
- [ ] Error cleared successfully
- [ ] Normal controls announced correctly

---

## Expected Results Summary

### ✅ What Should Happen

**Recoverable Errors** (Network, Timeout):
```
"Playback Error"
→ "[Error message explaining the issue]"
→ "Retry playback, button"
→ "[Episode Title]"
→ "[Podcast Title]"
```

**Non-Recoverable Errors** (Stream Failed, Missing URL):
```
"Playback Error"
→ "[Error message explaining the issue]"
→ "[Episode Title]" (no retry button)
→ "[Podcast Title]"
```

### ❌ What Should NOT Happen

- VoiceOver says "Error" or "Exclamation mark" before title
- Retry button present for non-recoverable errors
- Announcements unclear or confusing
- Navigation order illogical

---

## Troubleshooting

### Debug controls don't appear
- ✅ Check Xcode scheme has `ENABLE_ERROR_DEBUG=1`
- ✅ Rebuild app (⌘⇧K then ⌘R)
- ✅ Verify you're in DEBUG build configuration

### VoiceOver not working
- Try **⌘⇧⌥V** multiple times
- Restart simulator
- Check Settings → Accessibility → VoiceOver is ON

### Can't find debug buttons
- Scroll down in expanded player (three-finger swipe down)
- Look for black panel at bottom with colored buttons

---

## After Testing

### Document Results

1. Fill out checklist in `dev-log/03.3.4.3.1-voiceover-testing-infrastructure.md`
2. Note any issues or improvements needed
3. Take screenshots if helpful

### Remove DEBUG infrastructure (Optional)

If you want to remove the debug controls after testing:

1. Delete `#if DEBUG` blocks in:
   - `ExpandedPlayerViewModel.swift` (lines ~111-140)
   - `ExpandedPlayerView.swift` (lines ~186-250)
   - `ExpandedPlayerViewModelTests.swift` (lines ~259-327)
2. Remove `ENABLE_ERROR_DEBUG` from Xcode scheme
3. Commit changes

**Or keep it** for future accessibility testing!

---

## Quick Command Reference

```bash
# From zpod root directory:

# Open Xcode
open zpod.xcworkspace

# Run tests
./scripts/run-xcode-tests.sh -t PlayerFeature

# Check git status
git status
```

---

**Questions?** See full documentation in:
- `dev-log/03.3.4.3.1-voiceover-testing-infrastructure.md`

**Happy Testing! 🎉**
